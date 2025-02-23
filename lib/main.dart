import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:guess_number/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'CreateRoomScreen.dart';
import 'LoginScreen.dart';
import 'RegisterScreen.dart';

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
        '/login': (context) => LoginScreen(), // ✅ Agregamos la ruta del login
        '/register': (context) => RegisterScreen(), // ✅ Ruta de registro
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
  final TextEditingController _digitsController = TextEditingController();
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

// 🔥 Modificar `createRoom` para incluir los dígitos en la solicitud
  Future<void> createRoom(String roomId, String username, int digits) async {
    setState(() {
      _isJoining = true;
    });

    await Future.delayed(Duration(milliseconds: 50));

    try {
      final response = await Future.any([
        http.post(
          Uri.parse('http://109.123.248.19:4000/create-room'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(
              {"roomId": roomId, "username": username, "digits": digits}),
        ),
        Future.delayed(Duration(seconds: 5), () => throw TimeoutException(
            "Tiempo de espera agotado")),
      ]);

      if (response is http.Response) {
        if (response.statusCode == 200) {
          print("Sala creada con éxito.");
        } else {
          print("Error al crear la sala: ${response.body}");
        }
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "❌ La solicitud tardó demasiado. Intenta nuevamente.")),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute
        .of(context)
        ?.settings
        .arguments as Map?;

    if (args != null && args.containsKey("snackbarMessage") &&
        !_snackbarShown) {
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
  Future<void> _showAvailableRooms(BuildContext context) async {
    try {
      final response = await http.get(
          Uri.parse('http://109.123.248.19:4000/list-rooms'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rooms = data['rooms'];

        // 🔥 Mostrar el modal inferior con las salas disponibles
        _showRoomsBottomSheet(rooms);
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
                title: Text("Sala: ${room['id'] ?? 'Desconocida'}"),
                // ✅ Ahora muestra correctamente la ID
                subtitle: Text("Jugadores: ${room['players'] ?? 0}/2"),
                // ✅ Muestra correctamente los jugadores
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


  Future<void> _joinRoom(String roomId) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("❌ Ingresá un nombre antes de unirte a una sala.")),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      // 🔥 Obtener la información de la sala para determinar la cantidad de dígitos correcta
      final roomInfoResponse = await http.get(
        Uri.parse('http://109.123.248.19:4000/room-info/$roomId'),
      );

      if (roomInfoResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ La sala no existe o no tiene jugadores aún.")),
        );
        setState(() {
          _isJoining = false;
        });
        return;
      }

      final roomData = jsonDecode(roomInfoResponse.body);
      int roomDigits = roomData["digits"]; // ✅ Ahora obtenemos correctamente los dígitos de la sala

      // 🔥 Intentamos unirnos con los dígitos correctos
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/join-room'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "username": _nameController.text,
          "digits": roomDigits,
          // ✅ Se usa la cantidad de dígitos correcta obtenida de la API
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
          arguments: {
            'username': _nameController.text,
            'roomId': roomId,
            'digits': roomDigits
          },
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

  void _showRoomsBottomSheet(List<dynamic> rooms) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.black87, // 🔥 Fondo oscuro para el modal
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Salas Disponibles",
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 10),
              rooms.isEmpty
                  ? Center(
                child: Text(
                  "🚫 No hay salas disponibles.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          "Sala: ${room['id'] ?? 'Desconocida'}",
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          "Jugadores: ${room['players'] ?? 0}/2",
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Cerrar modal
                            _joinRoom(
                                room['id']); // 🔥 Unirse a la sala seleccionada
                          },
                          child: Text("Unirse"),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cerrar",
                    style: TextStyle(color: Colors.redAccent, fontSize: 18)),
              ),
            ],
          ),
        );
      },
    );
  }


  void _createRoom() async {
    if (_nameController.text.isEmpty || _roomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "❌ Ingresá un nombre y un ID de sala antes de crearla.")),
      );
      return;
    }

    int? digits = int.tryParse(_digitsController.text);
    if (digits == null || digits < 4 || digits > 7) {
      digits = 4; // 🔥 Si es inválido, se asigna el valor por defecto de 4
    }

    String roomId = _roomController.text
        .trim(); // 🔥 Elimina espacios en blanco
    String username = _nameController.text
        .trim(); // 🔥 Elimina espacios en blanco

    setState(() {
      _isJoining = true;
    });

    try {
      // 🔥 PRIMERO VERIFICAMOS SI LA SALA YA EXISTE
      final checkRoomResponse = await http.get(
        Uri.parse('http://109.123.248.19:4000/room-info/$roomId'),
      );

      if (checkRoomResponse.statusCode == 200) {
        // 🚫 La sala ya existe, mostrar mensaje de error y salir
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("❌ La sala '$roomId' ya existe. Usa otro ID.")),
        );
        setState(() {
          _isJoining = false;
        });
        return;
      }

      // 🔥 SI NO EXISTE, PROCEDER A CREARLA
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/create-room'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "username": username,
          "digits": digits,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        int roomDigits = responseData["digits"] ??
            digits; // 🔥 Asegurar que tomamos el valor correcto

        print("✅ Sala creada con éxito. Configurada para $roomDigits dígitos.");

        await _saveLastSession(username, roomId);
        Navigator.pushNamed(
          context,
          '/game',
          arguments: {
            'username': username,
            'roomId': roomId,
            'digits': roomDigits
          },
        );
      } else {
        print("❌ Error al crear la sala: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              "❌ No se pudo crear la sala. Intenta con otro ID.")),
        );
      }
    } catch (e) {
      print("❌ Error en la creación de la sala: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Ocurrió un error al crear la sala.")),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }


// 🔥 Método para crear la sala y meterte en la partida automáticamente
  void _createRoomAndJoin(String roomId, int digits) async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Ingresá un nombre antes de crear la sala.")),
      );
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final response = await Future.any([
        http.post(
          Uri.parse('http://109.123.248.19:4000/create-room'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "roomId": roomId,
            "username": _nameController.text,
            "digits": digits
          }),
        ),
        Future.delayed(Duration(seconds: 5), () => throw TimeoutException(
            "Tiempo de espera agotado")),
      ]);

      if (response is http.Response && response.statusCode == 200) {
        print("✅ Sala creada con éxito. Uniendo a la partida...");

        // 🔥 Guardar la sesión
        await _saveLastSession(_nameController.text, roomId);

        // 🔥 Redirigir al juego
        Navigator.pushNamed(
          context,
          '/game',
          arguments: {'username': _nameController.text, 'roomId': roomId},
        );
      } else {
        print("❌ Error al crear la sala: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No se pudo crear la sala.")),
        );
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "❌ La solicitud tardó demasiado. Intenta nuevamente.")),
      );
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
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/background.png"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
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

                  // 🔥 Botón de Login que redirige a la pantalla de Login
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login'); // ✅ Redirige a LoginScreen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text("Iniciar Sesión", style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/create-room'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                    child: Text("Crear Sala", style: TextStyle(fontSize: 18, color: Colors.black)),
                  ),

                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _showAvailableRooms(context),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
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