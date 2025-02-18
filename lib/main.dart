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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black, // 🔥 Fondo negro moderno
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black, // 🔥 AppBar negro
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white), // Íconos blancos
        ),
      ),
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
  String myNumber = "Cargando..."; // 🔥 Tu número secreto
  String turnUsername = ""; // 🔥 Nuevo: Guarda el usuario del turno actual
  bool isTurnDefined = false; // 🔥 Para evitar mostrar el turno antes de tiempo


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
    _fetchMyNumber(); // 🔥 Obtener mi número secreto

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
          setState(() {
            attempts.add({
              "username": "Sistema",
              "guess": data["message"]
            });
          });
          _scrollToBottom();

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("¡Juego terminado!"),
              content: Text(data["message"]),
              actions: [
                TextButton(
                  onPressed: () async {
                    await http.delete(Uri.parse('http://109.123.248.19:4000/api/rooms/$roomId'));
                    _channel?.sink.close();
                    _channel = null;
                    setState(() {
                      attempts.clear();
                      isWaiting = true;
                    });

                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text("Aceptar"),
                ),
              ],
            ),
          );
        } else if (data["type"] == "turn") {
          // 🔥 Asegurar que el servidor envía el campo correcto (puede ser "turn" en lugar de "turnUsername")
          setState(() {
            turnUsername = data["turn"] ?? data["turnUsername"] ?? "";
            isTurnDefined = true; // 🔥 Para evitar mostrar el turno antes de tiempo
          });
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

    return Scaffold(
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
                    color: isMyTurn ? Colors.blue : Colors.red, // 🔥 Azul si es tu turno, rojo si no
                  ),
                ),
              ),
          ],
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  myNumber,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
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
                int matchingDigits = int.parse(attempt["matchingDigits"] ?? "0");
                int correctPositions = int.parse(attempt["correctPositions"] ?? "0");

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
                              Text("📍 Posiciones correctas: $correctPositions",
                                  style: TextStyle(color: Colors.orangeAccent)),
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
              crossAxisAlignment: CrossAxisAlignment.center, // 🔥 Asegura alineación vertical con el input
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
                      fillColor: isMyTurn ? Colors.grey[900] : Colors.grey[800],
                      hintText: isMyTurn ? "Introduce un número..." : "Esperando turno...",
                      hintStyle: TextStyle(color: isMyTurn ? Colors.white70 : Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 20), // 🔥 Centra texto en input
                    ),
                    onSubmitted: isMyTurn ? (_) => _sendGuess() : null,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  margin: EdgeInsets.only(bottom: 20), // 🔥 Agrega margen inferior al icono
                  child: IconButton(
                    icon: Icon(Icons.send, color: isMyTurn ? Colors.blue : Colors.grey),
                    onPressed: isMyTurn ? _sendGuess : null,
                    iconSize: 28, // 🔥 Ajuste del tamaño del icono
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}