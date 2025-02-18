import 'dart:convert';
import 'package:adivinar_numeros2/winner_screen.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

class GameScreenGame extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreenGame> {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map;
    username = args['username'];
    roomId = args['roomId'];

    _channel =
        IOWebSocketChannel.connect('ws://109.123.248.19:4000/ws/rooms/$roomId');
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
          String winner = data["winner"] ?? "Jugador Desconocido"; // 🔥 Si es null, usa un valor predeterminado
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => WinnerScreen(
                  winnerUsername: data["winner"] ?? "Jugador Desconocido",
                  guessedNumber: data["guessedNumber"] ?? "Numero Desconocido", // ✅ Nuevo: número adivinado
                ),
              ),
            );
          }
        } else if (data["type"] == "turn") {
          setState(() {
            turnUsername = data["turn"] ?? data["turnUsername"] ?? "";
            isTurnDefined = true;
          });
        } else if (data["type"] == "player_left") {
          if (!_gameEnded) {
            if (!hasExited) { // ✅ Solo el jugador que NO abandonó ve el mensaje
              if (mounted) {
                Navigator.of(context).pushReplacementNamed(
                  '/',
                  arguments: {"snackbarMessage": "El oponente ha abandonado la sala."},
                );
              }
            } else {
              // ✅ Si el jugador abandonó, simplemente vuelve sin Snackbar
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            }
          }
        }
      } catch (e) {
        print("❌ Error al decodificar mensaje: $e");
      }
    });

    _checkPlayersInRoom();
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
      final response = await http.get(
          Uri.parse('http://109.123.248.19:4000/players-in-room/$roomId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['count'] >= 2) {
          setState(() {
            isWaiting = false;
          });
          return;
        }
      }
      await Future.delayed(Duration(seconds: 2));
    }
  }

  void _sendGuess() {
    String guess = _controller.text;

    // ✅ Verifica que el número tenga 4 dígitos únicos
    if (guess.length != 4 || guess.split('').toSet().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ No se pueden repetir cifras en el número.")),
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


  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  // ✅ Función para manejar la salida del usuario
  Future<void> _exitGame() async {
    hasExited = true; // ✅ Marcar que este usuario salió voluntariamente

    try {
      await http.delete(
          Uri.parse('http://109.123.248.19:4000/api/rooms/$roomId'));

      _channel?.sink.add(jsonEncode({
        "type": "player_left",
        "username": username
      }));

      _channel?.sink.close();
      _channel = null;

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      print("❌ Error al salir de la sala: $e");
    }
  }


// ✅ Método para manejar salida voluntaria
  Future<bool> _handleExit() async {
    hasExited = true; // 🔥 Marcar que este jugador salió voluntariamente

    try {
      await http.delete(
          Uri.parse('http://109.123.248.19:4000/api/rooms/$roomId'));

      _channel?.sink.add(jsonEncode({
        "type": "player_left",
        "username": username
      }));

      _channel?.sink.close();
      _channel = null;

      if (mounted) {
        Navigator.pop(context); // 🔥 Regresar a MainScreen SIN Snackbar
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
        });
      } else {
        print("❌ Error al obtener mi número: ${response.body}");
      }
    } catch (e) {
      print("❌ Error en la solicitud de mi número: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMyTurn = turnUsername == username; // 🔥 Verifica si es tu turno

    return WillPopScope( // 🔥 Captura el botón de retroceso del sistema
      onWillPop: _handleExit,
      child: Scaffold(
        backgroundColor: Colors.black, // 🔥 Fondo negro moderno
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Sala: $roomId"),
              if (isTurnDefined) // 🔥 Solo mostrar cuando se defina el turno
                AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: Text(
                    isMyTurn ? "Tu turno" : "Turno del oponente",
                    key: ValueKey(turnUsername), // 🔥 Cambio animado en AppBar
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isMyTurn ? Colors.blue : Colors
                          .red, // 🔥 Azul si es tu turno, rojo si no
                    ),
                  ),
                ),
            ],
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              await _handleExit();
            },
          ),
        ),
        body: Column(
          children: [
            // 🔥 Nueva fila sticky debajo del AppBar para mostrar el número secreto
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
                  : ListView.builder(
                controller: _scrollController,
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
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
                            color: isMyAttempt ? Colors.blue : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.all(10),
                          constraints: BoxConstraints(maxWidth: 250),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                Text("✔ Dígitos correctos: $matchingDigits",
                                    style: TextStyle(color: Colors.white70)),
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
            ),

            // 🔥 Input y botón de envío modernizados
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                // 🔥 Asegura alineación vertical con el input
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      enabled: isMyTurn,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isMyTurn ? Colors.grey[900] : Colors
                            .grey[800],
                        hintText: isMyTurn
                            ? "Introduce un número..."
                            : "Esperando turno...",
                        hintStyle: TextStyle(
                            color: isMyTurn ? Colors.white70 : Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 14,
                            horizontal: 20), // 🔥 Centra texto en input
                      ),
                      onSubmitted: isMyTurn ? (_) => _sendGuess() : null,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    margin: EdgeInsets.only(bottom: 20),
                    // 🔥 Agrega margen inferior al icono
                    child: IconButton(
                      icon: Icon(Icons.send,
                          color: isMyTurn ? Colors.blue : Colors.grey),
                      onPressed: isMyTurn ? _sendGuess : null,
                      iconSize: 28, // 🔥 Ajuste del tamaño del icono
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
