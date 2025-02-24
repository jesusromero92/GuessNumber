import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:http/http.dart' as http;
import 'package:guess_number/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'banner_ad_widget.dart';
import 'top_bar.dart'; // 🔥 Importar el TopBar
import 'CreateRoomScreen.dart';
import 'LoginScreen.dart';
import 'RegisterScreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize(); // 🔥 Inicializar Google Mobile Ads
  // 🔥 Bloquear la orientación a vertical
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(MyApp());
  });
}
void _hideStatusBar() {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.bottom], // Mantiene visible la barra de navegación
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // 🔥 Solo modo vertical
  ]);

}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black, // 🔥 Fondo negro moderno
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => MainScreen(),
        '/game': (context) => GameScreenGame(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/create-room') {
          final args = settings.arguments as Map<String, dynamic>?;
          final username = args?['username'] ?? "Guest_XXXXXXX"; // Fallback username

          return MaterialPageRoute(
            builder: (context) => CreateRoomScreen(username: username),
          );
        }
        return null; // Let the framework handle unknown routes
      },
    );
  }
}




class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _digitsController = TextEditingController();
  bool _snackbarShown = false;
  String? _snackbarMessage;
  bool _isJoining = false; // 🔥 Nuevo estado para deshabilitar el botón
  String _username = "Guest_XXXXXXX"; // Valor por defecto
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadLastSession(); // 🔥 Cargar última sesión guardada
    _loadUsername(); // Cargar el nombre al iniciar
  }


  // 🔥 Cargar los datos guardados en SharedPreferences
  Future<void> _loadLastSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString("lastUsername") ?? "";
      _roomController.text = prefs.getString("lastRoomId") ?? "";
    });
  }

  // 🔥 Guardar el último usuario e ID de sala antes de navegar
  Future<void> _saveLastSession(String username, String roomId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", username);
    await prefs.setString("lastRoomId", roomId);
  }

// 🔥 Modificar `createRoom` para incluir los dígitos en la solicitud
  Future<void> createRoom(String roomId, String username, int digits) async {
    setState(() {
      _isJoining = true;
    });

    await Future.delayed(Duration(milliseconds: 50));

    try {
      final response = await Future.any([
        http.post(
          Uri.parse('http://109.123.248.19:4000/create-room'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(
              {"roomId": roomId, "username": username, "digits": digits}),
        ),
        Future.delayed(Duration(seconds: 5), () =>
        throw TimeoutException(
            "Tiempo de espera agotado")),
      ]);

      if (response is http.Response) {
        if (response.statusCode == 200) {
          print("Sala creada con éxito.");
        } else {
          print("Error al crear la sala: ${response.body}");
        }
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            "❌ La solicitud tardó demasiado. Intenta nuevamente.")),
      );
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute
        .of(context)
        ?.settings
        .arguments as Map?;

    if (args != null && args.containsKey("snackbarMessage") &&
        !_snackbarShown) {
      _snackbarShown = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(args["snackbarMessage"])),
          );
        }
      });

      // 🔥 Limpiar argumentos después de mostrar el mensaje
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          ModalRoute.of(context)?.setState(() {});
        }
      });
    }
  }

  // 🔥 Método para obtener la lista de salas disponibles desde la API
  Future<void> _showAvailableRooms(BuildContext context) async {
    try {
      final response = await http.get(
          Uri.parse('http://109.123.248.19:4000/list-rooms'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rooms = data['rooms'];

        // 🔥 Mostrar el modal inferior con las salas disponibles
        _showRoomsBottomSheet(rooms);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al obtener salas.")),
        );
      }
    } catch (e) {
      print("❌ Error al cargar salas: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ No se pudieron obtener las salas.")),
      );
    }
  }


// 🔥 Método para mostrar el diálogo con las salas disponibles
  void _showRoomsDialog(List<dynamic> rooms) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Salas Disponibles"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: rooms.map((room) {
              return ListTile(
                title: Text("Sala: ${room['id'] ?? 'Desconocida'}"),
                // ✅ Ahora muestra correctamente la ID
                subtitle: Text("Jugadores: ${room['players'] ?? 0}/2"),
                // ✅ Muestra correctamente los jugadores
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Cierra el diálogo
                    _joinRoom(room['id']); // 🔥 Unirse a la sala seleccionada
                  },
                  child: Text("Unirse"),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  // 🔥 Cargar el nombre guardado en SharedPreferences o generar uno aleatorio
  Future<void> _loadUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedUsername = prefs.getString("lastUsername");

    // Si no hay usuario guardado, generar un Guest solo una vez
    if (savedUsername == null) {
      savedUsername = await _generateGuestUsername();
    }

    setState(() {
      _username = savedUsername!;
    });
  }

  /// 🔥 Generar un Guest solo si no existe ya un usuario guardado
  Future<String> _generateGuestUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String newGuest = "Guest_${Random().nextInt(900000) + 100000}";

    await prefs.setString("lastUsername", newGuest);
    return newGuest;
  }

  // 🔥 Genera un nombre aleatorio Guest_XXXXXXX
  String _generateRandomGuestName() {
    int randomNumber = Random().nextInt(9999999);
    return "Guest_$randomNumber";
  }

  // 🔥 Guardar el nombre editado en SharedPreferences
  Future<void> _saveUsername(String newUsername) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastUsername", newUsername);
    setState(() {
      _username = newUsername;
    });
  }

  // 🔥 Mostrar diálogo para editar nombre
  void _editUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Editar Nombre"),
          content: TextField(
            controller: _nameController,
            decoration: InputDecoration(hintText: "Ingresa tu nuevo nombre"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar el diálogo
              },
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                String newUsername = _nameController.text.trim();
                if (newUsername.isNotEmpty) {
                  _saveUsername(newUsername);
                  Navigator.pop(context); // Cerrar el diálogo
                }
              },
              child: Text("Guardar"),
            ),
          ],
        );
      },
    );
  }


  Future<void> _joinRoom(String roomId) async {
    setState(() {
      _isJoining = true;
    });

    try {
      // 🔥 Cargar el nombre de usuario desde SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String username = prefs.getString("lastUsername") ?? "Guest_XXXXXXX";

      // 🔥 Verificar la información de la sala antes de unirse
      final roomInfoResponse = await http.get(
        Uri.parse('http://109.123.248.19:4000/room-info/$roomId'),
      );

      if (roomInfoResponse.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ La sala no existe o no tiene jugadores aún.")),
        );
        setState(() {
          _isJoining = false;
        });
        return;
      }

      final roomData = jsonDecode(roomInfoResponse.body);
      int roomDigits = roomData["digits"]; // ✅ Se obtiene la cantidad de dígitos correcta

      // 🔥 Intentamos unirnos con los datos correctos
      final response = await http.post(
        Uri.parse('http://109.123.248.19:4000/join-room'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "username": username, // ✅ Ahora usa el nombre desde SharedPreferences
          "digits": roomDigits,
        }),
      );

      if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ La sala está llena, intenta otra.")),
        );
      } else if (response.statusCode == 200) {
        await _saveLastSession(username, roomId);
        Navigator.pushNamed(
          context,
          '/game',
          arguments: {
            'username': username,
            'roomId': roomId,
            'digits': roomDigits
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error al unirse a la sala.")),
        );
      }
    } catch (e) {
      print("❌ Error al unirse a la sala: $e");
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }


  void _showRoomsBottomSheet(List<dynamic> rooms) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.black87, // 🔥 Fondo oscuro para el modal
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Salas Disponibles",
                style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              SizedBox(height: 10),
              rooms.isEmpty
                  ? Center(
                child: Text(
                  "🚫 No hay salas disponibles.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        title: Text(
                          "Sala: ${room['id'] ?? 'Desconocida'}",
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          "Jugadores: ${room['players'] ?? 0}/2",
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            Navigator.pop(context); // Cerrar modal
                            _joinRoom(
                                room['id']); // 🔥 Unirse a la sala seleccionada
                          },
                          child: Text("Unirse"),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cerrar",
                    style: TextStyle(color: Colors.redAccent, fontSize: 18)),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isHorizontal = constraints.maxWidth > constraints.maxHeight;
        final bool isSmallScreen = constraints.maxWidth < 1000;

        debugPrint("📱 Ancho: ${constraints.maxWidth}, Alto: ${constraints.maxHeight}");
        debugPrint("🛠️ Horizontal: $isHorizontal, Pequeña: $isSmallScreen");

        final double iconSize = isHorizontal && isSmallScreen ? 50 : 100;
        final double titleFontSize = isHorizontal && isSmallScreen ? 20 : 32;
        final double buttonHeight = isHorizontal && isSmallScreen ? 40 : 60;
        final double buttonFontSize = isHorizontal && isSmallScreen ? 12 : 18;

        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: SafeArea(child: TopBar()),
          ),
          body: Stack(
            children: [
              // 🔥 Fondo de pantalla
              Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/background.png"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.6), BlendMode.darken),
                  ),
                ),
              ),

              // 🔥 Contenido principal con banner abajo
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: isHorizontal
                        ? SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: _buildContent(
                        iconSize, titleFontSize, buttonHeight, buttonFontSize,
                      ),
                    )
                        : _buildContent(iconSize, titleFontSize, buttonHeight, buttonFontSize),
                  ),
                  BannerAdWidget(), // 🔥 Banner de AdMob fijo abajo
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔥 Contenido ajustado (Centrado horizontalmente pero más arriba, SIN fondo en el icono)
  Widget _buildContent(double iconSize, double titleFontSize, double buttonHeight, double buttonFontSize) {
    return Align(
      alignment: Alignment.topCenter, // 🔥 Centrado horizontalmente, pero más arriba
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20), // 🔥 Márgenes laterales
        child: Column(
          mainAxisSize: MainAxisSize.min, // 🔥 Se ajusta al contenido, sin ocupar toda la pantalla
          crossAxisAlignment: CrossAxisAlignment.center, // 🔥 Asegura que todo esté centrado
          children: [
            SizedBox(height: 120), // 🔥 Ajuste para subir todo más arriba

            // 🔥 Icono sin fondo, directamente en color blanco
            Icon(Icons.videogame_asset_rounded, color: Colors.white, size: iconSize),

            SizedBox(height: 10), // 🔥 Espacio reducido para que esté más arriba

            // 🔥 Título
            Text(
              "¡Adivina el Número!",
              textAlign: TextAlign.center, // 🔥 Asegura que el texto esté centrado
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            SizedBox(height: 20), // 🔥 Mantiene espacio para los botones

            // 🔥 Botón Crear Sala
            _buildStyledButton(
              title: "Crear Sala",
              subtitle: "Multijugador",
              baseColor: Colors.purpleAccent,
              darkColor: Colors.deepPurple,
              icon: Icons.meeting_room,
              buttonHeight: buttonHeight,
              fontSize: buttonFontSize,
              onPressed: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        CreateRoomScreen(username: _username),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),

            SizedBox(height: 10), // 🔥 Espaciado entre botones

            // 🔥 Botón Listar Salas
            _buildStyledButton(
              title: "Listar Salas",
              subtitle: "Partidas activas",
              baseColor: Colors.orangeAccent,
              darkColor: Colors.deepOrange,
              icon: Icons.list,
              buttonHeight: buttonHeight,
              fontSize: buttonFontSize,
              onPressed: () => _showAvailableRooms(context),
            ),
          ],
        ),
      ),
    );
  }




  /// 🔥 Widget de botón con tamaño dinámico según la pantalla
  Widget _buildStyledButton({
    required String title,
    required String subtitle,
    required Color baseColor,
    required Color darkColor,
    required IconData icon,
    required VoidCallback onPressed,
    double buttonHeight = 60, // 🔥 Se ajustará si la pantalla es pequeña
    double fontSize = 18, // 🔥 Se ajustará si la pantalla es pequeña
  }) {
    return Container(
      width: 280,
      height: buttonHeight, // 🔥 Altura ajustable
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 5,
        ),
        child: Row(
          children: [
            // 🔥 SECCIÓN IZQUIERDA (Texto y subtítulo)
            Expanded(
              flex: 2,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: fontSize, // 🔥 Tamaño de fuente ajustable
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: fontSize - 4, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),

            // 🔥 SECCIÓN DERECHA (ICONO EN FONDO MÁS OSCURO)
            Expanded(
              flex: 1,
              child: Container(
                height: buttonHeight,
                decoration: BoxDecoration(
                  color: baseColor.withOpacity(0.8),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Center(
                  child: Icon(icon, size: fontSize + 6, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}