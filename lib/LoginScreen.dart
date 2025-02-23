import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'main.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // 🔥 Función para iniciar sesión con API
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

        // 🔥 Redirigir al juego o a otra pantalla
        // 🔥 Redirigir a MainScreen después del login
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
      body: Container(
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
                  "Welcome Back",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                _buildTextField("Username", Icons.person, _usernameController, false),
                SizedBox(height: 10),
                _buildTextField("Password", Icons.lock, _passwordController, true),
                SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text("Forgot Password?", style: TextStyle(color: Colors.white70)),
                ),
                SizedBox(height: 20),
                _buildLoginButton(),
                SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: Text(
                    "Don't have an account? Sign Up",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
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
