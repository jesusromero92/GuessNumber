import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => MainScreen(),
        '/game': (context) => NumberGuessGame(),
      },
    );
  }
}

class MainScreen extends StatelessWidget {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Ingresar a una Sala")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Nombre de Usuario",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _roomController,
              decoration: InputDecoration(
                labelText: "ID de la Sala",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty &&
                    _roomController.text.isNotEmpty) {
                  await createRoom(_roomController.text, _nameController.text);

                  Navigator.pushNamed(
                    context,
                    '/game',
                    arguments: {
                      'username': _nameController.text,
                      'roomId': _roomController.text,
                    },
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Por favor, ingresa todos los datos")),
                  );
                }
              },
              child: Text("Crear Sala"),
            ),
          ],
        ),
      ),
    );
  }
}

// Método para crear una sala
Future<void> createRoom(String roomId, String username) async {
  final response = await http.post(
    Uri.parse('http://109.123.248.19:4000/create-room'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"roomId": roomId, "username": username}),
  );

  if (response.statusCode == 200) {
    print("Sala creada y usuario registrado.");
  } else {
    print("Error al crear la sala: ${response.body}");
  }
}

class NumberGuessGame extends StatefulWidget {
  @override
  _NumberGuessGameState createState() => _NumberGuessGameState();
}

class _NumberGuessGameState extends State<NumberGuessGame> {
  final TextEditingController _controller = TextEditingController();
  WebSocketChannel? _channel;
  List<Map<String, String>> attempts = [];
  String username = "";
  String roomId = "";
  bool isWaiting = true;
  final ScrollController _scrollController = ScrollController();


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute
        .of(context)!
        .settings
        .arguments as Map;
    username = args['username'];
    roomId = args['roomId'];

    _channel =
        IOWebSocketChannel.connect('ws://109.123.248.19:4000/ws/rooms/$roomId');

    _channel!.stream.listen((message) {
      try {
        final data = jsonDecode(message);

        if (data["type"] == "attempt") {
          setState(() {
            attempts.add({ // 🔥 Se agrega el intento al final de la lista
              "username": data["username"] ?? "Desconocido",
              "guess": data["guess"]?.toString() ?? "???",
              "correctPositions": data["correctPositions"]?.toString() ?? "0", // 🔥 Se añade la cantidad de posiciones correctas
            });
          });
          _scrollToBottom(); // 🔥 Asegurar que el chat siempre haga scroll hacia abajo
        } else if (data["type"] == "game_won") {
          // 🔥 Añadir mensaje de ganador al chat
          setState(() {
            attempts.add({
              "username": "Sistema",
              "guess": data["message"]
            });
          });
          _scrollToBottom(); // 🔥 Desplazar automáticamente el chat

          // 🔥 Mostrar alerta emergente y volver al menú
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("¡Juego terminado!"),
              content: Text(data["message"]),
              actions: [
                TextButton(
                  onPressed: () async {
                    // 🔥 Eliminar la sala en el cliente antes de salir
                    await http.delete(Uri.parse(
                        'http://109.123.248.19:4000/api/rooms/$roomId'));

                    Navigator.pop(context);
                    Navigator.pop(context); // Vuelve al menú principal
                  },
                  child: Text("Aceptar"),
                ),
              ],
            ),
          );
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

  // Método para verificar la cantidad de jugadores en la sala
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
    if (_controller.text.length == 4) {
      _channel!.sink.add(jsonEncode({
        'username': username,
        'guess': _controller.text,
        'type': 'attempt'
      }));
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sala: $roomId")),
      body: Column(
        children: [
          Text("Jugador: $username", style: TextStyle(fontSize: 18)),
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
              child: Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: attempts.length,
                    itemBuilder: (context, index) {
                      final attempt = attempts[index];
                      bool isMyAttempt = attempt["username"] == username;

                      return Align(
                        alignment: isMyAttempt
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 10, horizontal: 14),
                          margin: EdgeInsets.symmetric(
                              vertical: 5, horizontal: 10),
                          decoration: BoxDecoration(
                            color:
                            isMyAttempt ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isMyAttempt
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMyAttempt ? "Tú" : attempt["username"]!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isMyAttempt
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                attempt["guess"]!,
                                style: TextStyle(
                                  color: isMyAttempt
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              // 🔥 Mostrar posiciones correctas en la misma viñeta
                              Text(
                                "Posiciones correctas: ${attempt['correctPositions'] ??
                                    0}",
                                style: TextStyle(
                                  color: isMyAttempt
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: "Ingresa un número de 4 cifras",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendGuess,
                  child: Text("Enviar"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}