import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_data.dart';

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => Size.fromHeight(60); // 🔥 Tamaño fijo sin desbordes

  @override
  _TopBarState createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  @override
  void initState() {
    super.initState();
    _loadUser(); // 🔥 Cargar el usuario al iniciar

    // 🔥 Escuchar cambios en los datos del usuario (ej. monedas)
    UserData.onUserUpdated = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  Future<void> _loadUser() async {
    await UserData.loadUserData(); // 🔥 Carga el usuario actual
    if (mounted) {
      setState(() {}); // 🔥 Refresca la UI
    }
  }

  Future<void> _logout() async {
    await UserData.logout(); // 🔥 Cierra sesión y vuelve a Guest
    if (mounted) {
      setState(() {}); // 🔥 Refresca la UI
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("🚪 Has cerrado sesión. Ahora eres ${UserData.username}.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Container(
        height: 60, // 🔥 Fija la altura
        padding: EdgeInsets.symmetric(horizontal: 8),
        color: Colors.black.withOpacity(0.6),
        child: IntrinsicHeight(
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserData.isLoggedIn && UserData.profileImage != null
                      ? CircleAvatar(radius: 20, backgroundImage: AssetImage(UserData.profileImage!))
                      : CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.black, size: 24),
                  ),
                  SizedBox(height: 0),

                  // 🔥 Nombre ajustado con `FittedBox`
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      UserData.username.isNotEmpty ? UserData.username : "",
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // 🔹 Monedas y Botón de Login/Logout (Derecha)
              Row(
                children: [
                  if (UserData.username.isNotEmpty) ...[
                    Icon(Icons.stars, color: Colors.amberAccent, size: 20), // 🔥 Ícono cambiado
                    SizedBox(width: 4),
                    Text(
                      "${UserData.coins}",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(width: 15),
                  ],

                  // 🔹 Botón de Login / Logout
                  IconButton(
                    icon: Icon(
                      UserData.isLoggedIn ? Icons.logout : Icons.login,
                      color: UserData.isLoggedIn ? Colors.redAccent : Colors.greenAccent,
                    ),
                    onPressed: () {
                      if (UserData.isLoggedIn) {
                        _logout(); // 🔥 Cierra sesión y vuelve a Guest
                      } else {
                        Navigator.of(context).pushNamed('/login').then((_) {
                          _loadUser(); // 🔥 Recargar datos cuando el usuario inicie sesión
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
