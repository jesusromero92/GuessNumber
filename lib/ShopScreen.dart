import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:guess_number/user_data.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'main.dart';
import 'top_bar.dart';

class ShopScreen extends StatefulWidget {
  @override
  _ShopScreenState createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final String apiUrl = "http://109.123.248.19:4000";
  RewardedAd? _rewardedAd;
  int _coins = 0; // Variable local para manejar las monedas

  final List<Map<String, dynamic>> advantages = [
    {
      "name": "Pista Extra",
      "column": "advantage_hint_extra",
      "icon": Icons.lightbulb_outline,
      "price": 150,
      "description": "Te da una pista sobre la posición correcta."
    },
    {
      "name": "Revelar un Número",
      "column": "advantage_reveal_number",
      "icon": Icons.visibility,
      "price": 75,
      "description": "Muestra un número correcto aleatorio."
    },
    {
      "name": "Repetir Intento",
      "column": "advantage_repeat_attempt",
      "icon": Icons.undo,
      "price": 100,
      "description": "Te permite volver a intentar sin penalización."
    },
    {
      "name": "Bloquear Oponente",
      "column": "advantage_block_opponent",
      "icon": Icons.block,
      "price": 150,
      "description": "Evita que el oponente use ventajas por 2 turnos."
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
    _loadCoins();

    // 🔥 Configurar el listener para actualizar la TopBar
    UserData.onUserUpdated = () {
      if (mounted) {
        setState(() {}); // Esto actualizará la UI cuando cambien las monedas
      }
    };
  }


  Future<void> _loadCoins() async {
    await UserData.fetchCoinsFromAPI(); // 🔥 Obtener datos actualizados del servidor
    setState(() {
      _coins = UserData.coins; // 🔥 Actualizar UI con el valor correcto
    });
  }


  Future<void> _updateCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int newCoins = (_coins + amount).clamp(0, double.infinity).toInt(); // Evita negativos
    await prefs.setInt('coins', newCoins);

    setState(() {
      _coins = newCoins;
      UserData.coins = newCoins; // 🔥 También actualiza UserData
    });

    if (UserData.onUserUpdated != null) {
      UserData.onUserUpdated!(); // 🔥 Notifica a la TopBar para que se actualice
    }
  }


  void _showConfirmationDialog(BuildContext context, Map<String, dynamic> advantage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.black87,
          title: Row(
            children: [
              Icon(advantage["icon"], size: 40, color: Colors.amberAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Confirmar Compra",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "¿Estás seguro de que quieres comprar '${advantage["name"]}' por ${advantage["price"]} monedas?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${advantage["price"]}",
                    style: TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.monetization_on, color: Colors.yellow, size: 24),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text("Cancelar", style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _coins >= advantage["price"] ? Colors.blueAccent : Colors.grey,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _coins >= advantage["price"]
                  ? () async {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo
                await _buyAdvantage(advantage); // Llama a la función de compra
              }
                  : null,
              child: Text("Comprar", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }


  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: "ca-app-pub-7943636520625441/8745426116",
      request: AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          setState(() {
            _rewardedAd = null;
          });
        },
      ),
    );
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _watchAdForCoins() {
    if (_rewardedAd == null) {
      _showSnackbar("⚠️ No hay anuncios disponibles en este momento.");
      return;
    }

    String username = UserData.username; // 🔥 Obtener el usuario desde UserData

    // 🔥 Si no hay usuario, generar uno automáticamente y guardarlo en SharedPreferences
    if (username.isEmpty) {
      username = "guest_${DateTime.now().millisecondsSinceEpoch}";
      UserData.username = username;

      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('username', username);
      });

      print("🆕 Usuario guest creado: $username");
    }

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        try {
          final response = await http.post(
            Uri.parse("$apiUrl/watch-ad"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"username": username}), // 🔥 Enviar el usuario correcto
          );

          final data = jsonDecode(response.body);

          if (response.statusCode == 200 && data["success"] == true) {
            await UserData.fetchCoinsFromAPI(); // 🔥 Obtener monedas desde la API y actualizar

            setState(() {
              _coins = UserData.coins; // Se sincroniza con `UserData`
            });

            _showSnackbar("🎉 ¡Has ganado 50 monedas! 🪙");
          } else {
            _showSnackbar("⚠️ No se pudo obtener la recompensa: ${data['error']}");
          }
        } catch (e) {
          _showSnackbar("❌ Error al conectar con el servidor.");
          print("❌ Error en la solicitud de recompensa: $e");
        }

        _rewardedAd!.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );
  }





  Future<void> _buyAdvantage(Map<String, dynamic> advantage) async {
    final String username = UserData.username;

    if (username.isEmpty) {
      _showSnackbar("⚠️ Error: Usuario no encontrado.");
      log("Error: No se encontró un usuario en UserData.");
      return;
    }

    log("Usuario actual en TopBar: $username");
    log("Intentando comprar: ${advantage["name"]}, Precio: ${advantage["price"]}");

    if (_coins < advantage["price"]) {
      _showSnackbar("❌ No tienes suficientes monedas.");
      log("Fallo: Monedas insuficientes. Tienes: $_coins, Necesitas: ${advantage["price"]}");
      return;
    }

    final url = Uri.parse("$apiUrl/buy-advantage");
    final headers = {"Content-Type": "application/json"};
    final body = jsonEncode({
      "username": username,
      "advantage": advantage["column"],
      "price": advantage["price"]
    });

    log("Enviando solicitud a $url");
    log("Headers: $headers");
    log("Body: $body");

    try {
      final response = await http.post(url, headers: headers, body: body);

      log("Respuesta recibida: Código ${response.statusCode}");
      log("Cuerpo de la respuesta: ${response.body}");

      if (response.statusCode == 200) {
        await UserData.fetchCoinsFromAPI(); // 🔥 Obtener monedas desde la API y actualizar

        setState(() {
          _coins = UserData.coins; // 🔥 Se actualizan las monedas en la UI
        });

        _showSnackbar("✅ Has comprado ${advantage["name"]}.");
        log("Compra exitosa. Monedas restantes: $_coins");
      } else {
        _showSnackbar("❌ Error al comprar la ventaja.");
        log("Error: Respuesta inesperada del servidor.");
      }
    } catch (e) {
      _showSnackbar("❌ Error al conectar con el servidor.");
      log("Excepción atrapada: $e");
    }
  }




  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _onAdvantageTap(Map<String, dynamic> advantage) {
    _showConfirmationDialog(context, advantage);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => MainScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
        return false;
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: SafeArea(child: TopBar()),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/background_shop.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.6),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 16),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                      ),
                      itemCount: advantages.length,
                        itemBuilder: (context, index) {
                          return Card(
                            color: Colors.black.withOpacity(0.8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: InkWell(
                              onTap: () => _onAdvantageTap(advantages[index]), // 🔥 Ahora llama al diálogo
                              borderRadius: BorderRadius.circular(15),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(advantages[index]['icon'], size: 50, color: Colors.amber),
                                  SizedBox(height: 10),
                                  Text(
                                    advantages[index]['name'],
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "${advantages[index]['price']} 🪙",
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(Icons.play_circle_filled, color: Colors.white, size: 28),
                    label: Text(
                      "Ver Anuncio y Gana 50 🪙",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _watchAdForCoins,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
