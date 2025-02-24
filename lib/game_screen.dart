import 'dart:convert';
import 'dart:math';
import 'package:guess_number/winner_screen.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

class GameScreenGame extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreenGame> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  List<Map<String, String>> attempts = [];
  String username = "";
  String roomId = "";
  bool isWaiting = true;
  final ScrollController _scrollController = ScrollController();
  String myNumber = "Cargando...";
  String turnUsername = "";
  bool isTurnDefined = false;
  bool _gameEnded = false;
  bool hasExited = false; // ✅ Nueva variable para detectar si el usuario salió
  WebSocketChannel? _emojiChannel; // ✅ Nuevo WebSocket para escuchar emojis
  // ✅ Nueva lista para animar los emojis flotantes en la pantalla
  List<String> floatingEmojis = [];
  bool _exitRequested = false; // 🔥 Rastrea si el usuario ya presionó "Volver" una vez
  int maxDigits = 4; // 🔥 Por defecto es 4, pero se actualizará según la sala
  String opponentUsername = ""; // Guarda el nombre fijo del oponente



  @override
  void dispose() {
    _channel?.sink.close();
    _emojiChannel?.sink.close();
    WidgetsBinding.instance.removeObserver(this); // 🔥 Remover el observer
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🔥 Suscribir el observer
    // ✅ Conectar WebSocket de emojis una sola vez
    _emojiChannel = IOWebSocketChannel.connect('ws://109.123.248.19:4001/ws/emojis');

    // ✅ Escuchar los emojis del oponente
    _emojiChannel!.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data["type"] == "reaction") {
          _showFloatingEmoji(data["emoji"]);
        }
      } catch (e) {
        print("❌ Error en WebSocket de emojis: $e");
      }
    });
  }

  void _registerUser() {
    if (_emojiChannel != null) {
      _emojiChannel!.sink.add(jsonEncode({
        "type": "register",
        "username": username,
        "roomId": roomId,
      }));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIfRoomExists(); // 🔥 Comprobar si la sala aún existe al volver al primer plano
    }
  }

  Future<void> _checkIfRoomExists() async {
    try {
      final response = await http.get(Uri.parse('http://109.123.248.19:4000/room-exists/$roomId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!data['exists']) {
          _handleExitOnRoomDeleted(); // 🔥 Si la sala no existe, expulsar al jugador
        }
      } else {
        print("❌ Error al comprobar existencia de la sala: ${response.body}");
      }
    } catch (e) {
      print("❌ Error en la solicitud de verificación de la sala: $e");
    }
  }

  void _handleExitOnRoomDeleted() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ La sala ha sido eliminada. Volviendo a la pantalla principal...")),
      );

      Future.delayed(Duration(seconds: 2), () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      });
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute
        .of(context)!
        .settings
        .arguments as Map;
    username = args['username'];
    roomId = args['roomId'];

    if (_channel == null) { // ✅ Evita crear múltiples conexiones
      _channel = IOWebSocketChannel.connect(
          'ws://109.123.248.19:4000/ws/rooms/$roomId');
      _fetchMyNumber();

      _channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message);

          if (data["type"] == "attempt") {
            setState(() {
              attempts.add({
                "username": data["username"] ?? "Desconocido",
                "guess": data["guess"]?.toString() ?? "???",
                "matchingDigits": data["matchingDigits"]?.toString() ?? "0",
                "correctPositions": data["correctPositions"]?.toString() ?? "0",
                "phase": data["phase"]?.toString() ?? "1",
              });
            });
            _scrollToBottom();
          } else if (data["type"] == "game_won") {
            _gameEnded = true;
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WinnerScreen(
                        winnerUsername: data["winner"] ?? "Jugador Desconocido",
                        guessedNumber: data["guessedNumber"] ??
                            "Numero Desconocido",
                      ),
                ),
              );
            }
          }
          if (data["type"] == "player_left" && !hasExited) {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/',
                arguments: {"snackbarMessage": "El oponente ha abandonado la sala."},
              );
            }
          }

          else if (data["type"] == "turn") {
            setState(() {
              turnUsername = data["turn"] ?? data["turnUsername"] ?? "";
              isTurnDefined = true;
            });
          }
        } catch (e) {
          print("❌ Error al decodificar mensaje: $e");
        }
      });

      _checkPlayersInRoom();
      // ✅ Registrar al usuario en WebSocket de emojis
      _registerUser();
    }
  }

  /// 🔥 Muestra el modal inferior con más emojis variados
  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 10),
              Text("Elige un emoji",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 15),

              // 🔥 Emojis organizados en filas
              Wrap(
                spacing: 15,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _emojiButton("😀"), _emojiButton("😂"), _emojiButton("🔥"),
                  _emojiButton("💩"), _emojiButton("🤡"), _emojiButton("🤔"),
                  _emojiButton("🙃"), _emojiButton("🥳"), _emojiButton("😭"),
                  _emojiButton("🤪"), _emojiButton("🤯"), _emojiButton("😡"),
                  _emojiButton("👍"), _emojiButton("👎"), _emojiButton("✌️"),
                  _emojiButton("👏"), _emojiButton("🎉"), _emojiButton("🏆"),
                  _emojiButton("🎯"), _emojiButton("🕶️"), _emojiButton("🏳️‍🌈"),
                ],
              ),

              SizedBox(height: 15),
            ],
          ),
        );
      },
    );
  }

  /// 🔥 Botón de selección de emoji
  Widget _emojiButton(String emoji) {
    return GestureDetector(
      onTap: () {
        _sendReaction(emoji);
        Navigator.pop(context);
      },
      child: Text(emoji, style: TextStyle(fontSize: 30)),
    );
  }


  /// 🔥 Enviar reacción por WebSocket
  void _sendReaction(String emojiMessage) {
    if (_emojiChannel == null) {
      print("❌ Error: WebSocket de emojis no está conectado.");
      return;
    }

    _emojiChannel!.sink.add(jsonEncode({
      "type": "reaction",
      "emoji": emojiMessage,
      "username": username,
      "roomId": roomId,
    }));

    _showFloatingEmoji(emojiMessage);
  }

  /// 🔥 Muestra un emoticono flotante en el centro con texto más pequeño y saltos de línea
  void _showFloatingEmoji(String emojiMessage) {
    setState(() {
      floatingEmojis.add(emojiMessage);
    });

    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        floatingEmojis.remove(emojiMessage);
      });
    });
  }

  /// 🔥 Construye la animación de los emoticonos con texto pequeño y salto de línea
  Widget _buildFloatingEmoji(String emojiMessage) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0),
        duration: Duration(seconds: 3),
        builder: (context, opacity, child) {
          return Opacity(
            opacity: opacity,
            child: Text(
              emojiMessage,
              textAlign: TextAlign.center, // ✅ Centra el texto y el emoji
              style: TextStyle(fontSize: 80, fontWeight: FontWeight.bold), // ✅ Texto más pequeño
            ),
          );
        },
      ),
    );
  }




        void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _checkPlayersInRoom() async {
    while (isWaiting) {
      try {
        print("🔍 Chequeando jugadores en la sala...");

        final response = await http.get(
            Uri.parse('http://109.123.248.19:4000/players-in-room/$roomId'));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print("📊 Respuesta de la API: $data");

          if (data['count'] >= 2 && data['players'] != null) {
            print("👥 Hay 2 jugadores en la sala, obteniendo el oponente...");

            // ✅ Buscar el oponente (que no sea el usuario actual)
            String opponent = data['players'].firstWhere(
                  (player) => player != username,
              orElse: () => "Oponente desconocido",
            );

            print("🎮 Oponente encontrado: $opponent");

            // 🔥 Esperar 2 segundos antes de actualizar `isWaiting`
            //await Future.delayed(Duration(seconds: 2));

            setState(() {
              isWaiting = false;
              opponentUsername = opponent; // Guarda el nombre del oponente
            });

            return; // Salimos del bucle
          } else {
            print("⌛ Aún no hay 2 jugadores en la sala.");
          }
        } else {
          print("❌ Error al obtener jugadores: ${response.body}");
        }
      } catch (e) {
        print("❌ Error en la solicitud de jugadores: $e");
      }

      await Future.delayed(Duration(seconds: 2));
    }
  }



  void _sendGuess() {
    String guess = _controller.text;

    // ✅ Verifica que el número tenga la cantidad correcta de dígitos únicos
    if (guess.length != maxDigits || guess.split('').toSet().length != maxDigits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Debe contener $maxDigits dígitos únicos.")),
      );
      return; // 🔥 No envía el intento si es inválido
    }

    _channel!.sink.add(jsonEncode({
      'username': username,
      'guess': guess,
      'type': 'attempt'
    }));

    _controller.clear();
  }


// ✅ Método para manejar salida voluntaria
  // ✅ Método para manejar salida voluntaria y volver correctamente a MainScreen
  Future<bool> _handleExit() async {
    hasExited = true; // 🔥 Marcar que este jugador salió voluntariamente

    try {
      await http.delete(Uri.parse('http://109.123.248.19:4000/api/rooms/$roomId'));

      _channel?.sink.add(jsonEncode({
        "type": "player_left",
        "username": username
      }));

      _channel?.sink.close();
      _channel = null;

      // 🔥 Verificar si la pantalla está montada antes de navegar
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false, arguments: {
          "snackbarMessage": "Has salido de la sala."
        });
      }
    } catch (e) {
      print("❌ Error al salir de la sala: $e");
    }

    return Future.value(true);
  }



  // 🔥 Nueva función para obtener tu número secreto
  Future<void> _fetchMyNumber() async {
    try {
      final response = await http.get(
          Uri.parse('http://109.123.248.19:4000/my-number/$roomId/$username'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          myNumber = data['my_number']?.toString() ?? "Desconocido";
          maxDigits = myNumber.length; // 🔥 Ajustar maxDigits al tamaño del número secreto
        });
      } else {
        print("❌ Error al obtener mi número: ${response.body}");
      }
    } catch (e) {
      print("❌ Error en la solicitud de mi número: $e");
    }
  }


  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // 🔥 Bordes redondeados
          ),
          backgroundColor: Colors.black, // 🔥 Fondo oscuro moderno
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔥 Ícono de advertencia grande
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 60),
                SizedBox(height: 10),

                // 🔥 Título llamativo
                Text(
                  "¿Seguro que quieres abandonar?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),

                // 🔥 Mensaje informativo
                Text(
                  "Si sales, la sala será eliminada y tu oponente será expulsado.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 20),

                // 🔥 Botones modernos con diseño personalizado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 🔥 Botón de cancelar
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        backgroundColor: Colors.grey[800], // 🔥 Color oscuro
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        "Cancelar",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),

                    // 🔥 Botón de confirmar salida
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        backgroundColor: Colors.redAccent, // 🔥 Color llamativo
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop(true);
                        await _handleExit();
                      },
                      child: Text(
                        "Sí, salir",
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;
  }


  @override
  Widget build(BuildContext context) {
    bool isMyTurn = turnUsername == username;

    return WillPopScope(
      onWillPop: () async {
        if (_exitRequested) {
          return await _showExitConfirmationDialog();
        } else {
          _exitRequested = true; // 🔥 Marcar que el usuario presionó "Atrás" una vez
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🔔 Presiona de nuevo para salir."),
              duration: Duration(seconds: 2),
            ),
          );

          // 🔥 Resetear el estado después de 2 segundos
          Future.delayed(Duration(seconds: 2), () {
            _exitRequested = false;
          });

          return Future.value(false); // 🔥 No salir todavía
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: isWaiting
              ? Text("Buscando oponente...") // Mientras espera un oponente
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // Alinea los elementos
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Text(
                      opponentUsername.isNotEmpty ? opponentUsername[0].toUpperCase() : "?",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    opponentUsername, // ✅ Nombre FIJO del oponente
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (isTurnDefined)
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: Text(
                    isMyTurn ? "Tu turno" : "Turno del oponente",
                    key: ValueKey(isMyTurn),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isMyTurn ? Colors.blue : Colors.red,
                    ),
                  ),
                ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              await _showExitConfirmationDialog();
            },
          ),
        ),

        body: Stack(
          children: [
            Column(
              children: [
                // 🔥 Fila debajo del AppBar para mostrar el número secreto
                Container(
                  color: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Tu número secreto: ",
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      Text(
                        myNumber,
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: isWaiting
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text("Esperando al otro jugador..."),
                    ],
                  )
                      : SingleChildScrollView(
                    reverse: true,
                    child: Column(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: attempts.length,
                          itemBuilder: (context, index) {
                            final attempt = attempts[index];
                            bool isMyAttempt = attempt["username"] == username;
                            int phase = int.parse(attempt["phase"] ?? "1");
                            int matchingDigits = int.parse(
                                attempt["matchingDigits"] ?? "0");
                            int correctPositions = int.parse(
                                attempt["correctPositions"] ?? "0");

                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 5),
                              child: Column(
                                crossAxisAlignment: isMyAttempt
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMyAttempt ? "Tú" : attempt["username"]!,
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isMyAttempt ? Colors.blue : Colors
                                          .grey[800],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.all(10),
                                    constraints: BoxConstraints(maxWidth: 250),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          attempt["guess"]!,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (phase == 1)
                                          Text(
                                              "✔ Dígitos correctos: $matchingDigits",
                                              style: TextStyle(
                                                  color: Colors.white70)),
                                        if (phase == 2)
                                          Text(
                                              "📍 Posiciones correctas: $correctPositions",
                                              style: TextStyle(
                                                  color: Colors.orangeAccent)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ Input fijo en la parte inferior
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      top: BorderSide(color: Colors.white12, width: 1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Asegura que los iconos se alineen
                    children: [
                      // 🔥 Botón para abrir los emojis con margen superior
                      Padding(
                        padding: EdgeInsets.only(bottom: 20), // Sube el icono
                        child: IconButton(
                          icon: Icon(Icons.emoji_emotions_outlined,
                              color: Colors.yellowAccent, size: 28),
                          onPressed: _showEmojiPicker,
                        ),
                      ),
                      SizedBox(width: 8),

                      // ✅ Input de texto
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          maxLength: maxDigits, // 🔥 Ahora es dinámico según la sala
                          enabled: isMyTurn,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[900],
                            hintText: isMyTurn
                                ? "Introduce un número..."
                                : "Esperando turno...",
                            hintStyle: TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            counterText: "${_controller.text.length}/$maxDigits", // 🔥 Actualiza el contador dinámicamente
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          ),
                          onSubmitted: isMyTurn ? (_) => _sendGuess() : null,
                        ),
                      ),
                      SizedBox(width: 8),

                      // ✅ Botón de enviar intento con margen superior
                      Padding(
                        padding: EdgeInsets.only(bottom: 20), // Sube el icono
                        child: IconButton(
                          icon: Icon(Icons.send,
                              color: isMyTurn ? Colors.blue : Colors.grey,
                              size: 28),
                          onPressed: isMyTurn ? _sendGuess : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 🔥 Emojis flotantes que NO afectan el input
            for (var emoji in floatingEmojis) _buildFloatingEmoji(emoji),
          ],
        ),
      ),
    );
  }
}