import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CreateRoomScreen extends StatefulWidget {
  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _digitsController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _loadLastSession();
  }

  Future<void> _loadLastSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString("lastUsername") ?? "";
      _roomController.text = prefs.getString("lastRoomId") ?? "";
    });
  }

  Future<void> _saveLastSession(String username, String roomId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", username);
    await prefs.setString("lastRoomId", roomId);
  }

  void _createRoom() async {
    if (_nameController.text.isEmpty || _roomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Ingresá un nombre y un ID de sala antes de crearla.")),
      );
      return;
    }

    int? digits = int.tryParse(_digitsController.text);
    if (digits == null || digits < 4 || digits > 7) {
      digits = 4; // 🔥 Valor por defecto si no es válido
    }

    String roomId = _roomController.text.trim();
    String username = _nameController.text.trim();

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
            "username": username,
            "digits": digits,
          }),
        ),
        Future.delayed(Duration(seconds: 5), () => throw TimeoutException("⏳ Tiempo de espera agotado")),
      ]);

      if (response is http.Response && response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        int roomDigits = responseData["digits"] ?? digits;

        print("✅ Sala creada con éxito. Configurada para $roomDigits dígitos.");

        await _saveLastSession(username, roomId);
        Navigator.pushNamed(
          context,
          '/game',
          arguments: {'username': username, 'roomId': roomId, 'digits': roomDigits},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ No se pudo crear la sala. Intenta con otro ID.")),
        );
      }
    } catch (e) {
      print("❌ Error en la creación de la sala: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Ocurrió un error al crear la sala o la solicitud tardó demasiado.")),
      );
    } finally {
      setState(() {
        _isJoining = false; // 🔥 Se reactiva el botón después de 5 segundos o si hubo error
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
                  Icon(Icons.add_circle_outline, color: Colors.white, size: 100),
                  SizedBox(height: 20),
                  Text(
                    "Crear Sala",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 30),
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
                  SizedBox(height: 15),
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
                  ElevatedButton(
                    onPressed: _isJoining ? null : _createRoom,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: _isJoining ? Colors.grey : Colors.orangeAccent,
                    ),
                    child: _isJoining
                        ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                    )
                        : Text("Crear Sala", style: TextStyle(fontSize: 18, color: Colors.black)),
                  ),

                  SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Volver", style: TextStyle(color: Colors.redAccent, fontSize: 18)),
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
