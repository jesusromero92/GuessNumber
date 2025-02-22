import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:guess_number/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _snackbarShown = false;
  String? _snackbarMessage;
  bool _isJoining = false; // 🔥 Nuevo estado para deshabilitar el botón

  @override
  void initState() {
    super.initState();
    _loadLastSession(); // 🔥 Cargar última sesión guardada
  }

  // 🔥 Cargar los datos guardados en SharedPreferences
  Future<void> _loadLastSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString("lastUsername") ?? "";
      _roomController.text = prefs.getString("lastRoomId") ?? "";
    });
  }

  // 🔥 Guardar el último usuario e ID de sala antes de navegar
  Future<void> _saveLastSession(String username, String roomId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", username);
    await prefs.setString("lastRoomId", roomId);
  }

// 🔥 Método para crear una sala con timeout de 5 segundos
  Future<void> createRoom(String roomId, String username) async {
    setState(() {
      _isJoining = true; // 🔥 Bloquea el botón y cambia a gris
    });

    await Future.delayed(Duration(milliseconds: 50)); // 🔥 Permite que la UI se actualice antes de continuar

    try {
      final response = await Future.any([
        http.post(
          Uri.parse('http://109.123.248.19:4000/create-room'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"roomId": roomId, "username": username}),
        ),
        Future.delayed(Duration(seconds: 5), () => throw TimeoutException("Tiempo de espera agotado")),
      ]);

      if (response is http.Response) {
        if (response.statusCode == 200) {
          print("Sala creada y usuario registrado.");
        } else {
          print("Error al crear la sala: ${response.body}");
        }
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ La solicitud tardó demasiado. Intenta nuevamente.")),
      );
    } finally {
      setState(() {
        _isJoining = false; // 🔥 Reactiva el botón después de la respuesta o timeout
      });
    }
  }




  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;

    if (args != null && args.containsKey("snackbarMessage") && !_snackbarShown) {
      _snackbarShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(args["snackbarMessage"])),
          );
        }
      });

      // 🔥 Limpiar argumentos después de mostrar el mensaje
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          ModalRoute.of(context)?.setState(() {});
        }
      });
    }
  }

  // 🔥 Método para obtener la lista de salas disponibles desde la API
  Future<void> _showAvailableRooms() async {
    try {
      final response = await http.get(Uri.parse('http://109.123.248.19:4000/list-rooms'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rooms = data['rooms'];

        if (rooms.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("🚫 No hay salas disponibles en este momento.")),
          );
          return;
        }

        // 🔥 Mostrar diálogo con la lista de salas
        _showRoomsDialog(rooms);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al obtener salas.")),
        );
      }
    } catch (e) {
      print("❌ Error al cargar salas: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ No se pudieron obtener las salas.")),
      );
    }
  }

// 🔥 Método para mostrar el diálogo con las salas disponibles
  void _showRoomsDialog(List<dynamic> rooms) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Salas Disponibles"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: rooms.map((room) {
              return ListTile(
                title: Text("Sala: ${room['id'] ?? 'Desconocida'}"), // ✅ Ahora muestra correctamente la ID
                subtitle: Text("Jugadores: ${room['players'] ?? 0}/2"), // ✅ Muestra correctamente los jugadores
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Cierra el diálogo
                    _joinRoom(room['id']); // 🔥 Unirse a la sala seleccionada
                  },
                  child: Text("Unirse"),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }


  // 🔥 Método para unirse a una sala
  Future<void> _joinRoom(String roomId) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Ingresá un nombre antes de unirte a una sala.")),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/join-room'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "username": _nameController.text,
        }),
      );

      if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ La sala está llena, intenta otra.")),
        );
      } else if (response.statusCode == 200) {
        await _saveLastSession(_nameController.text, roomId);
        Navigator.pushNamed(
          context,
          '/game',
          arguments: {'username': _nameController.text, 'roomId': roomId},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al unirse a la sala.")),
        );
      }
    } catch (e) {
      print("❌ Error al unirse a la sala: $e");
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔥 Fondo
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.png"),
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
                  Icon(Icons.videogame_asset_rounded, color: Colors.white, size: 100),
                  SizedBox(height: 20),
                  Text(
                    "¡Adivina el Número!",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 30),

                  // 🔥 Input Nombre de Usuario
                  // 🔥 Input Nombre de Usuario con validación
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
                    onChanged: (value) {
                      if (value.contains("?") || value.contains("¿")) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❌ No se permiten los caracteres '?' o '¿'.")),
                        );

                        // 🔥 Elimina automáticamente los caracteres inválidos
                        setState(() {
                          _nameController.text = value.replaceAll(RegExp(r'[?¿]'), '');
                          _nameController.selection = TextSelection.fromPosition(
                            TextPosition(offset: _nameController.text.length),
                          );
                        });
                      }
                    },
                  ),


                  SizedBox(height: 15),

                  // 🔥 Input ID de Sala
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

                  // 🔥 Botón de Unirse a la Sala
                  // 🔥 Botón de Unirse a la Sala con verificación de capacidad
                  ElevatedButton(
                    onPressed: _isJoining || _nameController.text.contains("?") || _nameController.text.contains("¿")
                        ? null
                        : () async {
                      setState(() {
                        _isJoining = true; // 🔥 Cambia de color inmediatamente
                      });

                      await Future.delayed(Duration(milliseconds: 50)); // 🔥 Espera para permitir el cambio de color antes del spinner

                      if (_nameController.text.isNotEmpty && _roomController.text.isNotEmpty) {
                        try {
                          final response = await Future.any([
                            http.post(
                              Uri.parse('http://109.123.248.19:4000/join-room'),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "roomId": _roomController.text,
                                "username": _nameController.text
                              }),
                            ),
                            Future.delayed(Duration(seconds: 5), () => throw TimeoutException("Tiempo de espera agotado")),
                          ]);

                          if (response.statusCode == 403) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("❌ La sala está llena, intenta otra.")),
                            );
                          } else if (response.statusCode == 200) {
                            await _saveLastSession(_nameController.text, _roomController.text);
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
                              SnackBar(content: Text("❌ Error al unirse a la sala.")),
                            );
                          }
                        } catch (e) {
                          print("❌ Error: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("❌ La solicitud tardó demasiado. Intenta nuevamente.")),
                          );
                        } finally {
                          setState(() {
                            _isJoining = false; // 🔥 Reactiva el botón tras la respuesta o timeout
                          });
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("❌ Por favor, ingresa todos los datos.")),
                        );

                        setState(() {
                          _isJoining = false; // 🔥 Reactiva el botón si faltan datos
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: _isJoining ? Colors.grey : Colors.blueAccent, // 🔥 Cambia de color inmediatamente
                    ),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 50), // 🔥 Espera para mostrar el spinner después del cambio de color
                      child: _isJoining
                          ? CircularProgressIndicator(color: Colors.white) // 🔥 Ahora aparece después del cambio de color
                          : Text("Unirse a la Sala", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  // 🔥 Botón para listar salas disponibles
                  ElevatedButton(
                    onPressed: _isJoining ? null : _showAvailableRooms,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.greenAccent, // 🔥 Color diferente para diferenciarlo
                    ),
                    child: Text("Listar Salas", style: TextStyle(fontSize: 18, color: Colors.black)),
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
