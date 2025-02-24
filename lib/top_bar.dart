import 'package:flutter/material.dart';
import 'user_data.dart'; // 🔥 Importa la variable global de usuario

class TopBar extends StatefulWidget {
  @override
  _TopBarState createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  @override
  void initState() {
    super.initState();
    UserData.onUserUpdated = () {
      if (mounted) setState(() {}); // 🔥 Se actualiza automáticamente
    };
    UserData.loadUserData(); // 🔥 Carga inicial
  }

  /// 🔥 Cerrar sesión y actualizar la UI
  void _logout() async {
    await UserData.logout(); // 🔥 Llamar a la función global de logout
    if (mounted) setState(() {}); // 🔥 Refrescar UI si el widget sigue montado
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🚪 Has cerrado sesión.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6), // 🔥 Fondo semitransparente
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5, spreadRadius: 1)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🔹 Configuración y Notificaciones (Izquierda)
          Row(
            children: [
              IconButton(icon: Icon(Icons.settings, color: Colors.white), onPressed: () {}),
              IconButton(icon: Icon(Icons.notifications, color: Colors.white), onPressed: () {}),
            ],
          ),

          // 🔹 Ícono de perfil con el nombre abajo (Centrado)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              UserData.profileImage != null
                  ? CircleAvatar(radius: 20, backgroundImage: AssetImage(UserData.profileImage!))
                  : CircleAvatar(
                radius: 20, backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.black, size: 24),
              ),
              SizedBox(height: 5),
              Text(
                UserData.username,
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),

          // 🔹 Monedas y Botón de Login/Logout (Derecha)
          Row(
            children: [
              Icon(Icons.attach_money, color: Colors.white, size: 20),
              Text(
                "15",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(width: 15),

              // 🔹 Botón de Login / Logout
              IconButton(
                icon: Icon(
                  UserData.isLoggedIn ? Icons.logout : Icons.login,
                  color: UserData.isLoggedIn ? Colors.redAccent : Colors.greenAccent,
                ),
                onPressed: () {
                  if (UserData.isLoggedIn) {
                    _logout(); // 🔥 Llamar a la función de cerrar sesión
                  } else {
                    Navigator.of(context).pushNamed('/login'); // 🔥 Navegar sin animación
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
