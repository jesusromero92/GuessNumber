import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class UserData {
  static String username = "Guest_XXXXXXX";
  static bool isLoggedIn = false;
  static String? profileImage;
  static int coins = 0; // 🔥 Nueva variable para monedas
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
    coins = prefs.getInt("coins") ?? 0; // 🔥 Cargar las monedas

    onUserUpdated?.call(); // 🔥 Notificar a la UI que los datos han cambiado
  }

  /// 🔥 Cerrar sesión y resetear a Guest
  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLogged", false);
    await prefs.remove("profileImage");
    await prefs.remove("coins"); // 🔥 Eliminar las monedas al cerrar sesión

    username = await _generateGuestUsername();
    isLoggedIn = false;
    profileImage = null;
    coins = 0; // 🔥 Resetear las monedas

    onUserUpdated?.call(); // 🔥 Notificar cambios
  }

  /// 🔥 Guardar nombre de usuario tras iniciar sesión
  static Future<void> setUsername(String newUsername) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", newUsername);
    await prefs.setBool("isLogged", true);
    username = newUsername;
    isLoggedIn = true;

    onUserUpdated?.call(); // 🔥 Notificar cambios
  }

  /// 🔥 Guardar monedas en SharedPreferences
  static Future<void> setCoins(int newCoins) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt("coins", newCoins);
    coins = newCoins;

    onUserUpdated?.call(); // 🔥 Notificar cambios a la UI
  }

  /// 🔥 Obtener monedas desde la API y actualizar localmente
  static Future<void> fetchCoinsFromAPI() async {
    try {
      final response = await http.get(Uri.parse('http://109.123.248.19:4000/get-coins/$username'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await setCoins(data['coins'] ?? 0); // 🔥 Actualizar localmente
      } else {
        print("❌ Error al obtener monedas: ${response.body}");
      }
    } catch (e) {
      print("❌ Error de conexión al obtener monedas: $e");
    }
  }

  /// 🔥 Generar un nombre aleatorio Guest_XXXXXXX
  static Future<String> _generateGuestUsername() async {
    String newGuest = "Guest_${Random().nextInt(900000) + 100000}";
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", newGuest);
    return newGuest;
  }
}
