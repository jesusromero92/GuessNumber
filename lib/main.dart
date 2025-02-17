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
                if (_nameController.text.isNotEmpty && _roomController.text.isNotEmpty) {
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


// Método para crear una sala y guardar el usuario en la base de datos
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
  List<String> attempts = [];
  String username = "";
  String roomId = "";
  bool isWaiting = true; // Estado para esperar al segundo jugador
  bool gameOver = false; // ✅ Se agrega esta variable
  String winnerMessage = ""; // ✅ Se agrega esta variable

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute
        .of(context)!
        .settings
        .arguments as Map;
    username = args['username'];
    roomId = args['roomId'];
    _channel = IOWebSocketChannel.connect('ws://109.123.248.19:4000/ws/rooms/$roomId');

    _channel!.stream.listen((message) {
      try {
        final data = jsonDecode(message);

        if (data["type"] == "attempt") {
          setState(() {
            attempts.add(data["message"]);
          });
        } else if (data["type"] == "players_count") {
          print("👥 Jugadores en la sala: ${data["count"]}");
        }
      } catch (e) {
        print("❌ Error al decodificar mensaje: $e");
      }
    });




    // Verificar si hay otro jugador
    _checkPlayersInRoom();
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

      // Espera 2 segundos antes de volver a verificar
      await Future.delayed(Duration(seconds: 2));
    }
  }

  void _sendGuess() {
    if (_controller.text.length == 4) {
      _channel!.sink.add(
          jsonEncode({'username': username, 'guess': _controller.text}));
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // ✅ Evita el error de expansión infinita
          children: [
            Text("Jugador: $username"),

            if (isWaiting)
              Column(
                mainAxisSize: MainAxisSize.min,
                // ✅ Esto evita problemas dentro de otro Column
                children: [
                  SizedBox(height: 20),
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Esperando al otro jugador..."),
                ],
              )
            else
              Expanded( // ✅ Esto permite que la lista de intentos no cause problemas
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                          labelText: "Ingresa un número de 4 cifras"),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _sendGuess,
                      child: Text("Enviar"),
                    ),
                    SizedBox(height: 20),
                    Text("Intentos del oponente:"),
                    Expanded( // ✅ Agregar Expanded para la lista
                      child: ListView.builder(
                        itemCount: attempts.length,
                        itemBuilder: (context, index) =>
                            ListTile(
                              title: Text(attempts[index]),
                            ),
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