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
  }

  Future<void> _loadUser() async {
    await UserData.loadUserData(); // 🔥 Carga el usuario actual o aleatorio
    if (mounted) {
      setState(() {}); // 🔥 Actualiza la UI cuando el usuario esté disponible
    }
  }

  Future<void> _logout() async {
    await UserData.logout(); // 🔥 Limpia datos del usuario y asigna guest_XXXX
    if (mounted) {
      setState(() {}); // 🔥 Actualiza la UI después del logout
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
        height: 60, // 🔥 Fija la altura para evitar cambios inesperados
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
                    radius: 20, backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: Colors.black, size: 24),
                  ),
                  SizedBox(height: 0),

                  // 🔥 Nombre ajustado con `FittedBox`
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      UserData.username.isNotEmpty ? UserData.username : "Cargando...",
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
                        _logout(); // 🔥 Cierra sesión y asigna guest_XXXX
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
