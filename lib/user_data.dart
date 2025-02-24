import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class UserData {
  static String username = "Guest_XXXXXXX";
  static bool isLoggedIn = false;
  static String? profileImage;
  static Function()? onUserUpdated; // 🔥 Callback para notificar cambios a la UI

  /// 🔥 Inicializar los datos cuando la app se carga
  static Future<void> init() async {
    await loadUserData();
  }

  /// 🔥 Cargar datos del usuario desde SharedPreferences
  static Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool("isLogged") ?? false;
    username = prefs.getString("lastUsername") ?? await _generateGuestUsername();
    profileImage = prefs.getString("profileImage");

    onUserUpdated?.call(); // 🔥 Notificar a TopBar u otras pantallas
  }

  /// 🔥 Cerrar sesión y resetear a Guest
  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLogged", false);
    await prefs.remove("profileImage");

    username = await _generateGuestUsername();
    isLoggedIn = false;
    profileImage = null;

    onUserUpdated?.call(); // 🔥 Notificar cambios
  }

  /// 🔥 Guardar nombre de usuario tras iniciar sesión
  static Future<void> setUsername(String newUsername) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", newUsername);
    await prefs.setBool("isLogged", true); // 🔥 Ahora sí guarda isLoggedIn correctamente
    username = newUsername;
    isLoggedIn = true;

    onUserUpdated?.call(); // 🔥 Notificar cambios
  }

  /// 🔥 Generar un nombre aleatorio Guest_XXXXXXX
  static Future<String> _generateGuestUsername() async {
    String newGuest = "Guest_${Random().nextInt(900000) + 100000}";
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", newGuest);
    return newGuest;
  }
}
