import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔥 Fondo degradado azul
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade900, Colors.blue.shade500],
              ),
            ),
          ),

          Center(
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

                  Text(
                    "Create your account",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 20),

                  _buildTextField("Username", Icons.person, false, _usernameController),
                  SizedBox(height: 10),
                  _buildTextField("Email address", Icons.email, false, _emailController),
                  SizedBox(height: 10),
                  _buildTextField("Password", Icons.lock, true, _passwordController),
                  SizedBox(height: 10),
                  _buildTextField("Confirm password", Icons.lock_outline, true, _confirmPasswordController),
                  SizedBox(height: 20),

                  _buildRegisterButton(),

                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // 🔥 Volver al Login
                    },
                    child: Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hintText, IconData icon, bool obscureText, TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: TextField(
        controller: controller,
        obscureText: obscureText && !_isPasswordVisible,
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
          suffixIcon: obscureText
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

  Widget _buildRegisterButton() {
    return ElevatedButton(
      onPressed: () {
        if (_usernameController.text.isEmpty ||
            _emailController.text.isEmpty ||
            _passwordController.text.isEmpty ||
            _confirmPasswordController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Todos los campos son obligatorios.")),
          );
          return;
        }

        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("❌ Las contraseñas no coinciden.")),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Cuenta creada con éxito!")),
        );

        Navigator.pop(context); // ✅ Volver a Login después del registro
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.blue.shade900, backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: EdgeInsets.symmetric(horizontal: 100, vertical: 15),
      ),
      child: Text("REGISTER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}
