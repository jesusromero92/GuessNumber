import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_data.dart';

class TopBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => Size.fromHeight(60);

  @override
  _TopBarState createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  @override
  void initState() {
    super.initState();
    _loadUser();

    // 🔥 Escuchar cambios en los datos del usuario (ej. monedas)
    UserData.onUserUpdated = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  Future<void> _loadUser() async {
    await UserData.loadUserData();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _logout() async {
    await UserData.logout();
    if (mounted) {
      setState(() {});
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
        height: 60,
        padding: EdgeInsets.symmetric(horizontal: 12),
        color: Colors.black.withOpacity(0.6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 🔹 Avatar del usuario y nombre (IZQUIERDA DEL TODO)
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: UserData.isLoggedIn && UserData.profileImage != null
                      ? AssetImage(UserData.profileImage!)
                      : null,
                  child: (UserData.isLoggedIn && UserData.profileImage != null)
                      ? null
                      : Icon(Icons.person, color: Colors.black, size: 22),
                ),
                SizedBox(width: 8),

                // 🔥 Nombre del usuario
                Text(
                  UserData.username.isNotEmpty ? UserData.username : "Invitado",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            // 🔹 Monedas (CENTRO)
            Row(
              children: [
                Icon(Icons.stars, color: Colors.amberAccent, size: 22),
                SizedBox(width: 4),
                Text(
                  "${UserData.coins}",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),

            // 🔹 Configuración y Login/Logout (DERECHA DEL TODO)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.settings, color: Colors.white),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(
                    UserData.isLoggedIn ? Icons.logout : Icons.login,
                    color: UserData.isLoggedIn ? Colors.redAccent : Colors.greenAccent,
                  ),
                  onPressed: () {
                    if (UserData.isLoggedIn) {
                      _logout();
                    } else {
                      Navigator.of(context).pushNamed('/login').then((_) {
                        _loadUser();
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
