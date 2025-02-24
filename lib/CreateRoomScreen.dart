import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'main.dart';
import 'top_bar.dart'; // 🔥 Importar el TopBar

class CreateRoomScreen extends StatefulWidget {
  final String username; // ✅ Add this field to store the username

  const CreateRoomScreen({Key? key, required this.username}) : super(key: key); // ✅ Named parameter

  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _digitsController = TextEditingController();
  bool _isJoining = false;
  String _username = "Guest_XXXXXXX"; // Nombre por defecto

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  /// 🔥 Cargar el nombre de usuario guardado
  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString("lastUsername");

    if (savedUsername == null) {
      savedUsername = await _generateGuestUsername(); // Generar un nuevo Guest
    }

    setState(() {
      _username = savedUsername!;
    });
  }

  /// 🔥 Genera un nombre aleatorio Guest_XXXXXX si no hay usuario guardado
  Future<String> _generateGuestUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String newGuest = "Guest_${Random().nextInt(900000) + 100000}";
    await prefs.setString("lastUsername", newGuest);
    return newGuest;
  }

  /// 🔥 Crear Sala
  void _createRoom() async {
    if (_roomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Debes ingresar un ID de sala.")),
      );
      return;
    }

    int? digits = int.tryParse(_digitsController.text);
    if (digits == null || digits < 4 || digits > 7) {
      digits = 4; // 🔥 Valor por defecto si no es válido
    }

    String roomId = _roomController.text.trim();

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
            "username": _username, // 🔥 Se usa el usuario cargado
            "digits": digits,
          }),
        ),
        Future.delayed(Duration(seconds: 15), () =>
        throw TimeoutException(
            "⏳ Tiempo de espera agotado")),
      ]);

      if (response is http.Response && response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        int roomDigits = responseData["digits"] ?? digits;

        print("✅ Sala creada con éxito. Configurada para $roomDigits dígitos.");

        Navigator.pushNamed(
          context,
          '/game',
          arguments: {
            'username': _username,
            'roomId': roomId,
            'digits': roomDigits
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              "❌ No se pudo crear la sala. Intenta con otro ID.")),
        );
      }
    } catch (e) {
      print("❌ Error en la creación de la sala: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "❌ Ocurrió un error al crear la sala o la solicitud tardó demasiado.")),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MainScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // 🔥 Evita que la UI cambie al abrir el teclado
        body: Stack(
          children: [
            // 🔥 Fondo de pantalla
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

            // 🔥 TopBar pegado arriba
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TopBar(),
            ),

            // 🔥 Scroll para dispositivos pequeños
            SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Container(
                height: MediaQuery
                    .of(context)
                    .size
                    .height, // 🔥 Ocupa toda la pantalla
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isHorizontal = constraints.maxWidth >
                        600; // 🔥 Detecta orientación

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.white,
                            size: isHorizontal ? 60 : 80),
                        SizedBox(height: isHorizontal ? 10 : 15),
                        Text(
                          "Crear Sala",
                          style: TextStyle(
                            fontSize: isHorizontal ? 24 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isHorizontal ? 15 : 20),

                        // 🔥 Campo de ID de Sala
                        TextField(
                          controller: _roomController,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            hintText: "ID de Sala",
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(
                                Icons.meeting_room, color: Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 15),

                        // 🔥 Campo de Cantidad de Dígitos
                        TextField(
                          controller: _digitsController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.2),
                            hintText: "Cantidad de dígitos (4-7)",
                            hintStyle: TextStyle(color: Colors.white70),
                            prefixIcon: Icon(Icons.pin, color: Colors.white),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        SizedBox(height: 15),

                        if (isHorizontal)
                        // 🔥 En horizontal, los botones están en fila
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 🔥 Botón Volver
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                          secondaryAnimation) => MainScreen(),
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                    ),
                                  );
                                },
                                child: Text("Volver", style: TextStyle(
                                    color: Colors.redAccent, fontSize: 18)),
                              ),

                              SizedBox(width: 20), // Espacio entre los botones

                              // 🔥 Botón Crear Sala
                              ElevatedButton(
                                onPressed: _isJoining ? null : _createRoom,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: _isJoining
                                      ? Colors.grey
                                      : Colors.orangeAccent,
                                ),
                                child: _isJoining
                                    ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.black, strokeWidth: 3),
                                )
                                    : Text("Crear Sala", style: TextStyle(
                                    fontSize: 18, color: Colors.black)),
                              ),
                            ],
                          )
                        else
                        // 🔥 En vertical, los botones están en columna
                          Column(
                            children: [
                              // 🔥 Botón Crear Sala
                              ElevatedButton(
                                onPressed: _isJoining ? null : _createRoom,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  backgroundColor: _isJoining
                                      ? Colors.grey
                                      : Colors.orangeAccent,
                                ),
                                child: _isJoining
                                    ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.black, strokeWidth: 3),
                                )
                                    : Text("Crear Sala", style: TextStyle(
                                    fontSize: 18, color: Colors.black)),
                              ),
                              SizedBox(height: 10), // Espacio entre los botones

                              // 🔥 Botón Volver
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation,
                                          secondaryAnimation) => MainScreen(),
                                      transitionDuration: Duration.zero,
                                      reverseTransitionDuration: Duration.zero,
                                    ),
                                  );
                                },
                                child: Text("Volver", style: TextStyle(
                                    color: Colors.redAccent, fontSize: 18)),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}