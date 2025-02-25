import 'dart:convert';
import 'dart:math';
import 'package:guess_number/winner_screen.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

import 'main.dart';

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
// 🔥 VARIABLES NUEVAS (deben estar en la clase `_GameScreenState`)
  bool _advantagesBlocked = false; // Indica si las ventajas del jugador están bloqueadas
  int _blockedTurnsRemaining = 0; // Cantidad de turnos bloqueados
  bool _opponentAdvantagesBlocked = false; // Indica si el oponente está bloqueado
  int _remainingAdvantages = 2; // 🔥 Cada jugador empieza con 2 intentos de ventajas




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

    final args = ModalRoute.of(context)!.settings.arguments as Map;
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
                  builder: (context) => WinnerScreen(
                    winnerUsername: data["winner"] ?? "Jugador Desconocido",
                    guessedNumber: data["guessedNumber"] ?? "Numero Desconocido",
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

              // 🔥 Reducir contador de turnos bloqueados si aún está activo
              if (_advantagesBlocked && _blockedTurnsRemaining > 0) {
                _blockedTurnsRemaining--;

                // 🔥 Si el contador llega a 0, desbloquear ventajas
                if (_blockedTurnsRemaining == 0) {
                  _advantagesBlocked = false;
                }
              }
            });
          }

          _listenForAdvantageBlock(message); // 🔥 Escuchar si el oponente bloqueó ventajas

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
    if (!mounted) return; // 🔥 Verifica si el widget aún está en el árbol

    setState(() {
      floatingEmojis.add(emojiMessage);
    });

    Future.delayed(Duration(seconds: 3), () {
      if (mounted) { // 🔥 Verifica antes de llamar a setState
        setState(() {
          floatingEmojis.remove(emojiMessage);
        });
      }
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

            if (mounted) {
              setState(() {
                isWaiting = false;
                opponentUsername = opponent;
              });
            }

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
  Future<bool> _handleExit() async {
    if (hasExited) return false; // 🔥 Evita ejecutar la salida más de una vez
    hasExited = true; // 🔥 Marcar que el usuario ha salido

    try {
      // 🔥 Si es el creador, intenta eliminar la sala antes de salir
      await http.delete(Uri.parse('http://109.123.248.19:4000/api/rooms/$roomId'));

      // 🔥 Notificar a los demás jugadores que abandonaste
      _channel?.sink.add(jsonEncode({
        "type": "player_left",
        "username": username
      }));

      // 🔥 Cerrar WebSocket y limpiar referencias
      _channel?.sink.close();
      _channel = null;

      _emojiChannel?.sink.close();
      _emojiChannel = null;

      if (mounted) {
        // 🔥 Verificar si ya se está mostrando un snackbar para evitar spam
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Has salido de la sala.")),
        );

        // 🔥 Limpiar la navegación y volver a la pantalla principal
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
              (route) => false,
        );
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
        if (mounted) {
          setState(() {
            myNumber = data['my_number']?.toString() ?? "Desconocido";
            maxDigits = myNumber.length;
          });
        }
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
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 60),
                SizedBox(height: 10),
                Text(
                  "¿Seguro que quieres abandonar?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 10),
                Text(
                  "Si sales, la sala será eliminada y tu oponente será expulsado.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 🔥 Botón Cancelar
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        backgroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text("Cancelar", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),

                    // 🔥 Botón Confirmar Salida
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop(true);
                        await _handleExit(); // 🔥 Salida asegurada directamente a `MainScreen`
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


  void _revealOpponentNumber() async {
    try {
      final response = await http.get(
        Uri.parse('http://109.123.248.19:4000/reveal-number/$roomId/$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String revealedDigit = data['digit']?.toString() ?? "❓"; // 🔥 Obtener el dígito revelado

        // 🔥 Mostrar el dígito en un SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🔍 Un dígito del número de tu oponente es: $revealedDigit"),
            duration: Duration(seconds: 4),
          ),
        );
        await _fetchAdvantagesLeft(); // 🔥 Actualizar la cantidad de ventajas restantes
      } else {
        throw Exception("Error al obtener el número del oponente.");
      }
    } catch (e) {
      print("❌ Error en la solicitud de revelar número: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ No se pudo revelar el número."),
        ),
      );
    }
  }


  Future<void> _getHintCorrectPosition() async {
    TextEditingController _numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.black87,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔥 Botón de Cerrar arriba a la derecha
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.white54, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // 🔥 Ícono superior
                Icon(Icons.search, color: Colors.blueAccent, size: 50),
                SizedBox(height: 10),

                // 🔥 Título atractivo
                Text(
                  "Busca un número",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),

                // 🔥 Input de número
                TextField(
                  controller: _numberController,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 22),
                  decoration: InputDecoration(
                    hintText: "Ingresa un dígito (0-9)",
                    hintStyle: TextStyle(color: Colors.white54),
                    counterText: "",
                    filled: true,
                    fillColor: Colors.grey[900],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 15),

                // 🔥 Botón de buscar
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () {
                    String digit = _numberController.text.trim();
                    if (digit.isEmpty || !RegExp(r'^[0-9]$').hasMatch(digit)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("❌ Ingresa un dígito válido (0-9)")),
                      );
                      return;
                    }
                    Navigator.pop(context); // Cierra el diálogo antes de llamar a la API
                    _getHintForDigit(digit);
                  },
                  child: Text(
                    "Buscar",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 🔥 **Función para obtener la pista llamando a la API**
  void _getHintForDigit(String digit) async {
    try {
      final response = await http.get(
        Uri.parse('http://109.123.248.19:4000/hint-correct-position/$roomId/$username?digit=$digit'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String message;
        Color bgColor;
        await _fetchAdvantagesLeft(); // 🔥 Actualizar la cantidad de ventajas restantes
        if (data["found"] == true) {
          message = "📍 El número ${data["digit"]} está en la posición ${data["position"] + 1}.";
          bgColor = Colors.green.withOpacity(0.8); // ✅ Verde claro transparente
        } else {
          message = "❌ El número $digit NO está en el número secreto del oponente.";
          bgColor = Colors.red.withOpacity(0.8); // ✅ Rojo claro transparente
        }

        // 🔥 Mostrar el resultado en un **diálogo moderno**
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: bgColor,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data["found"] == true ? Icons.check_circle : Icons.cancel,
                      color: Colors.white,
                      size: 50,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Resultado",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                    SizedBox(height: 15),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cerrar", style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No se pudo obtener la pista.")),
        );
      }
    } catch (e) {
      print("❌ Error al obtener pista: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al conectar con el servidor.")),
      );
    }
  }


  void _useRepeatTurn() async {
    try {
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/repeat-turn'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "username": username,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          await _fetchAdvantagesLeft(); // 🔥 Actualizar la cantidad de ventajas restantes
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🔄 ¡Puedes hacer otro intento sin cambiar el turno!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ No puedes repetir turno ahora.")),
          );
        }
      } else {
        throw Exception("Error al solicitar repetir turno.");
      }
    } catch (e) {
      print("❌ Error en repetir turno: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ No se pudo procesar la ventaja.")),
      );
    }
  }


  /// 🔥 FUNCIÓN PARA BLOQUEAR LAS VENTAJAS DEL OPONENTE
  void _blockOpponentAdvantages() async {
    try {
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/block-advantages'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "username": username,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          await _fetchAdvantagesLeft(); // 🔥 Actualizar la cantidad de ventajas restantes
          setState(() {
            _opponentAdvantagesBlocked = true; // ✅ Bloquear ventajas del oponente
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🚫 ¡Has bloqueado las ventajas de tu oponente por 2 turnos!")),
          );

          // 🔥 Enviar notificación por WebSocket
          _channel?.sink.add(jsonEncode({
            "type": "advantages_blocked",
            "username": username, // ✅ Asegura que tenga un username
            "blockedBy": username,
            "roomId": roomId,
          }));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ No puedes bloquear ventajas ahora.")),
          );
        }
      } else {
        throw Exception("Error al bloquear ventajas.");
      }
    } catch (e) {
      print("❌ Error al bloquear ventajas: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ No se pudo bloquear las ventajas.")),
      );
    }
  }

  Future<void> _showAdvantagesBottomSheet(BuildContext context) async {
    await _fetchAdvantagesLeft(); // 🔥 Obtener ventajas restantes antes de mostrar el Bottom Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🔥 Control total del tamaño
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Color(0xFF1E1E1E), // 🔥 Un color gris oscuro en vez de negro puro
      builder: (context) {
        return Container(
          height: 500, // 🔥 Altura fija para que no crezca ni se expanda
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔥 Título
              Text(
                "Ventajas Disponibles ($_remainingAdvantages)", // 🔥 Mostrar intentos restantes
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(height: 10),

              // 🔥 Aviso de bloqueo de ventajas
              if (_advantagesBlocked)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "🚫 Tus ventajas están bloqueadas por $_blockedTurnsRemaining turnos.",
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),

              Expanded(
                child: ListView(
                  children: [
                    // 🔥 1️⃣ PISTA EXTRA
                    _advantageOption(
                      context,
                      Icons.lightbulb_outline,
                      "Pista extra",
                      "Te da una pista sobre la posición correcta",
                      _advantagesBlocked ? null : () {
                        Navigator.pop(context);
                        _getHintCorrectPosition();
                      },
                    ),

                    // 🔥 2️⃣ REVELAR UN NÚMERO
                    _advantageOption(
                      context,
                      Icons.visibility,
                      "Revelar un número",
                      "Muestra un número correcto aleatorio",
                      _advantagesBlocked ? null : () {
                        Navigator.pop(context);
                        _revealOpponentNumber();
                      },
                    ),

                    // 🔥 3️⃣ REPETIR INTENTO
                    _advantageOption(
                      context,
                      Icons.undo,
                      "Repetir intento",
                      "Te permite volver a intentar sin penalización",
                      _advantagesBlocked ? null : () {
                        Navigator.pop(context);
                        _useRepeatTurn();
                      },
                    ),

                    // 🔥 4️⃣ BLOQUEAR VENTAJAS DEL OPONENTE
                    _advantageOption(
                      context,
                      Icons.block,
                      "Bloquear ventajas del oponente",
                      "Evita que el oponente use ventajas por 2 turnos",
                      _advantagesBlocked ? null : () {
                        Navigator.pop(context);
                        _blockOpponentAdvantages();
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10), // 🔥 Espacio extra para que el botón no quede pegado

              // 🔥 Botón de cierre estilizado
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Cerrar",
                  style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


// 🔥 Función mejorada para representar las opciones con Cards
  Widget _advantageOption(BuildContext context, IconData icon, String title, String description, VoidCallback? onTap) {
    return Card(
      color: Colors.grey[900], // 🔥 Fondo gris oscuro para resaltar la opción
      margin: EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.amberAccent),
        title: Text(title, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(description, style: TextStyle(fontSize: 14, color: Colors.white70)),
        onTap: onTap, // 🔥 Se cerrará automáticamente al pulsar
      ),
    );
  }

  Future<void> _fetchAdvantagesLeft() async {
    try {
      final response = await http.get(
        Uri.parse('http://109.123.248.19:4000/advantages-left/$roomId/$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _remainingAdvantages = 2 - (data["advantages_used"] as int? ?? 0);

          });
        }
      } else {
        print("❌ Error al obtener ventajas restantes: ${response.body}");
      }
    } catch (e) {
      print("❌ Error en la solicitud de ventajas restantes: $e");
    }
  }



  /// 🔥 ESCUCHAR SI EL OPONENTE BLOQUEA TUS VENTAJAS
  void _listenForAdvantageBlock(String message) {
    try {
      final data = jsonDecode(message);

      if (data["type"] == "advantages_blocked" && data["blockedBy"] != username) {
        setState(() {
          _advantagesBlocked = true;
          _blockedTurnsRemaining = 2; // 🔥 Bloqueo inicial de 2 turnos
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚫 ¡Tu oponente ha bloqueado tus ventajas por 2 turnos!")),
        );
      }
    } catch (e) {
      print("❌ Error al procesar bloqueo de ventajas: $e");
    }
  }

  /// 🔥 REDUCIR EL BLOQUEO EN CADA TURNO
  void _reduceAdvantageBlock() {
    if (_advantagesBlocked && _blockedTurnsRemaining > 0) {
      setState(() {
        _blockedTurnsRemaining--;

        if (_blockedTurnsRemaining == 0) {
          _advantagesBlocked = false; // 🔥 Desbloquea cuando llega a 0 turnos
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("✅ ¡Tus ventajas han sido desbloqueadas!")),
          );
        }
      });
    }
  }




  @override
  Widget build(BuildContext context) {
    bool isMyTurn = turnUsername == username;

    return WillPopScope(
      onWillPop: () async {
        if (_exitRequested) {
          bool confirmExit = await _showExitConfirmationDialog();
          if (confirmExit) {
            await _handleExit(); // 🔥 Cerrar correctamente la sala
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/', // 🔥 Volver directamente a MainScreen
                    (route) => false,
              );
            }
          }
          return false; // 🔥 Evita que la app se cierre directamente
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

          return false; // 🔥 No salir todavía
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
                    isMyTurn ? "Tu turno" : "Oponente",
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
                // 🔥 Fila debajo del AppBar para mostrar el número secreto con icono de ventajas
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white12, // 🔥 Borde sutil
                        width: 1,
                      ),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start, // 🔥 Alineado a la izquierda
                    children: [
                      // 🔥 Icono de ventajas interactivo
                      GestureDetector(
                        onTap: _advantagesBlocked || _remainingAdvantages == 0
                            ? null // 🔥 Si está bloqueado, no permite tocar
                            : () => _showAdvantagesBottomSheet(context), // 🔥 Mostrar BottomSheet solo si no está bloqueado
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              Icons.star,
                              color: (_advantagesBlocked || _remainingAdvantages == 0)
                                  ? Colors.grey  // 🔥 Si está bloqueado o no quedan ventajas → Gris
                                  : Colors.amberAccent, // 🔥 Si hay ventajas disponibles → Amarillo
                              size: 24,
                            ),
                            if (_advantagesBlocked) // 🔥 Agregar un pequeño "bloqueo" visual encima
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Icon(
                                  Icons.block, // Ícono de bloqueo
                                  color: Colors.redAccent, // 🔥 Rojo para indicar que está bloqueado
                                  size: 12, // Tamaño más pequeño
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(width: 10), // Espaciado entre icono y texto

                      // 🔥 Textos dentro de un Expanded para que se ajusten bien
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center, // Centrar los textos
                          children: [
                            Text(
                              "Tu número secreto: ",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              myNumber,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
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