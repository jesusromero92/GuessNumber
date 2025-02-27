import 'package:flutter/material.dart';
import 'package:guess_number/user_data.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfLoggedIn(); // 🔥 Verificar si el usuario ya está logueado
  }

  // 🔥 Verificar si el usuario ya está logueado y redirigirlo
  Future<void> _checkIfLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLogged = prefs.getBool("isLogged") ?? false;

    if (isLogged) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    }
  }


  Future<void> loginUser() async {
    final String username = _usernameController.text.trim();
    final String password = _passwordController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ El username es obligatorio.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password.isNotEmpty ? password : null}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ ${data["message"]}")),
        );

        await UserData.setUsername(username);
        await UserData.setCoins(data["coins"] ?? 0); // 🔥 Guardar monedas obtenidas al loguearse

        // 🔥 Verificar si las monedas se actualizaron
        print("✅ Monedas actualizadas: ${UserData.coins}");

        UserData.onUserUpdated?.call(); // 🔥 Notificar a la UI

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ ${data["error"]}")),
        );
      }
    } catch (e) {
      print("❌ Error al iniciar sesión: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error de conexión, intenta nuevamente.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 🔥 Evita que el contenido se mueva al abrir el teclado
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // 🔥 Cierra el teclado al tocar fuera
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade900, Colors.blue.shade500],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Colors.blue.shade900),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Bienvenido de nuevo",
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  _buildTextField("Nombre de usuario", Icons.person, _usernameController, false),
                  SizedBox(height: 10),
                  _buildTextField("Contraseña", Icons.lock, _passwordController, true),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Colors.white70)),
                  ),
                  SizedBox(height: 20),
                  _buildLoginButton(),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: Text(
                      "¿No tienes una cuenta? Regístrate",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  Widget _buildTextField(String hintText, IconData icon, TextEditingController controller, bool obscureText) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white.withOpacity(0.3),
        prefixIcon: Icon(icon, color: Colors.white),
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : loginUser, // 🔥 Desactiva el botón mientras carga
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.blue.shade900,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
      ),
      child: _isLoading
          ? CircularProgressIndicator(color: Colors.blue.shade900) // 🔄 Muestra carga
          : Text("LOGIN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
