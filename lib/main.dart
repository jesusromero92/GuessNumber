import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:adivinar_numeros2/game_screen.dart';

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
        '/game': (context) => GameScreenGame(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  bool _snackbarShown = false; // 🔥 Nueva variable de estado para evitar mensajes repetidos
  String? _snackbarMessage; // 🔥 Variable para manejar el mensaje de abandono sin repetirlo


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 🔥 Capturar el mensaje de abandono solo una vez y luego eliminarlo
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && args.containsKey("snackbarMessage") && _snackbarMessage == null) {
      setState(() {
        _snackbarMessage = args["snackbarMessage"];
      });

      // 🔥 Mostrar el mensaje solo una vez
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_snackbarMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_snackbarMessage!)),
          );
          setState(() {
            _snackbarMessage = null; // ✅ Evitar que se muestre más de una vez
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute
          .of(context)
          ?.settings
          .arguments as Map?;
      if (args != null && args.containsKey("message")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(args["message"])),
        );
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // 🔥 Fondo con imagen y opacidad
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.png"),
                // Asegúrate de tener esta imagen en assets
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.6), BlendMode.darken),
              ),
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔥 Icono llamativo
                  Icon(Icons.videogame_asset_rounded, color: Colors.white,
                      size: 100),

                  SizedBox(height: 20),

                  // 🔥 Título principal
                  Text(
                    "¡Adivina el Número!",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 30),

                  // 🔥 Input para Nombre de Usuario
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: "Nombre de usuario",
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.person, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  // 🔥 Input para ID de la Sala
                  TextField(
                    controller: _roomController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      hintText: "ID de Sala",
                      hintStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.meeting_room, color: Colors.white),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  // 🔥 Botón Animado con diseño moderno
                  ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isNotEmpty && _roomController.text.isNotEmpty) {
                        await createRoom(_roomController.text, _nameController.text);

                        // 🔥 Limpiamos cualquier argumento previo antes de navegar al juego
                        Navigator.pushNamed(
                          context,
                          '/game',
                          arguments: {
                            'username': _nameController.text,
                            'roomId': _roomController.text,
                          },
                        ).then((_) {
                          setState(() {
                            _snackbarMessage = null; // ✅ Evitar mensajes al volver a MainScreen
                          });
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Por favor, ingresa todos los datos")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.blueAccent,
                    ),
                    child: Text("Unirse a la Sala",
                        style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
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
