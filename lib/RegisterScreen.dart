import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'LoginScreen.dart';
import 'main.dart';
import 'user_data.dart'; // 🔥 Importamos UserData para sincronizar con TopBar

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _savedUsername = "Cargando..."; // 🔥 Ahora usa UserData

  @override
  void initState() {
    super.initState();
    _loadSavedUsername(); // ✅ Cargar usuario guardado
  }

  Future<void> _loadSavedUsername() async {
    await UserData.loadUserData(); // 🔥 Cargar desde UserData
    if (mounted) {
      setState(() {
        _savedUsername = UserData.username; // ✅ Ahora siempre coincide con la TopBar
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 🔥 Permite que el contenido se mueva al abrir el teclado
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
          child: SafeArea(
            child: Column(
              children: [
                Expanded( // 🔥 Evita el hueco negro
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person_add, size: 50, color: Colors.blue.shade900),
                          ),
                          SizedBox(height: 20),

                          //Text(
                           // "Usuario guardado: $_savedUsername",
                            //style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          //),
                          //SizedBox(height: 20),

                          Text(
                            "Crea tu cuenta",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 20),

                          _crearCampoTexto("Nombre de usuario", Icons.person, false, _usernameController),
                          SizedBox(height: 10),
                          _crearCampoTexto("Correo electrónico (Opcional)", Icons.email, false, _emailController),
                          SizedBox(height: 10),
                          _crearCampoTexto("Contraseña", Icons.lock, true, _passwordController),
                          SizedBox(height: 10),
                          _crearCampoTexto("Confirmar contraseña", Icons.lock_outline, true, _confirmPasswordController),
                          SizedBox(height: 20),

                          _botonRegistrar(),

                          SizedBox(height: 20),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              "¿Ya tienes una cuenta? Iniciar sesión",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _crearCampoTexto(String textoAyuda, IconData icono, bool ocultarTexto, TextEditingController controlador) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: TextField(
        controller: controlador,
        obscureText: ocultarTexto && !_isPasswordVisible,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.3),
          prefixIcon: Icon(icono, color: Colors.white),
          hintText: textoAyuda,
          hintStyle: TextStyle(color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          suffixIcon: ocultarTexto
              ? IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _botonRegistrar() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _registerUser,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.blue.shade900, backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
      ),
      child: _isLoading
          ? CircularProgressIndicator(color: Colors.blue.shade900)
          : Text("REGISTRAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }


  Future<void> _loginUser(String username, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password.isNotEmpty ? password : null,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print("✅ Login automático exitoso para $username");

        await UserData.setUsername(username);
        await UserData.setCoins(data["coins"] ?? 0); // 🔥 Guardar monedas obtenidas al loguearse

        // 🔥 Notificar a la UI
        UserData.onUserUpdated?.call();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Bienvenido $username!")));

        // ✅ Redirigir al usuario a la pantalla principal sin pasar por LoginScreen
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainScreen()));

      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ ${data["error"]}")));
      }
    } catch (e) {
      print("❌ Error al iniciar sesión: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error de conexión, intenta nuevamente.")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _registerUser() async {
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ El username es obligatorio.")));
      return;
    }
    if (password.isNotEmpty && password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Las contraseñas no coinciden.")));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 🔥 Obtener usuario almacenado en SharedPreferences
      String storedUser = UserData.username;

      // 🔥 Si el usuario es "Guest", conservar sus monedas, si no, darle 0
      int initialCoins = storedUser.contains("Guest") ? UserData.coins : 0;

      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "oldUsername": storedUser, // 🔥 Enviar el usuario actual
          "newUsername": username,
          "email": email.isNotEmpty ? email : null,
          "password": password.isNotEmpty ? password : null,
          "coins": initialCoins, // 🔥 Mantener monedas si era Guest, sino 0
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print("✅ Registro exitoso: ${data['message']}");

        // ✅ Llamamos a la función de login automático
        await _loginUser(username, password);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ ${data['error']}")));
      }
    } catch (e) {
      print("❌ Error al registrar usuario: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error de conexión, intenta nuevamente.")));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }



}
