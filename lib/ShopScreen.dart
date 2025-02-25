import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'top_bar.dart';
import 'user_data.dart';

class ShopScreen extends StatefulWidget {
  @override
  _ShopScreenState createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final String apiUrl = "http://109.123.248.19:4000";
  RewardedAd? _rewardedAd; // 🔥 Variable para el anuncio recompensado

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

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) async {
        final response = await http.post(
          Uri.parse("$apiUrl/watch-ad"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"username": UserData.username}),
        );

        if (response.statusCode == 200) {
          setState(() {
            UserData.coins += 50;
          });
          _showSnackbar("🎉 ¡Has ganado 50 monedas! 🪙");
        } else {
          _showSnackbar("⚠️ No se pudo obtener la recompensa.");
        }

        _rewardedAd!.dispose();
        _loadRewardedAd();
      },
    );
  }

  void _showPurchaseDialog(BuildContext context, Map<String, dynamic> advantage) {
    showDialog(
      context: context,
      barrierDismissible: false, // Evita cerrar tocando fuera del diálogo
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.black87, // Color oscuro moderno
          title: Row(
            children: [
              Icon(advantage["icon"], size: 40, color: Colors.amberAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  advantage["name"],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                advantage["description"],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${advantage["price"]}",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
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
              child: Text(
                "Cancelar",
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: UserData.coins >= advantage["price"]
                    ? Colors.blueAccent
                    : Colors.grey, // Desactiva si no tiene monedas
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: UserData.coins >= advantage["price"]
                  ? () async {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo

                final response = await http.post(
                  Uri.parse("$apiUrl/buy-advantage"),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "username": UserData.username,
                    "advantage": advantage["column"],
                    "price": advantage["price"],
                  }),
                );

                if (response.statusCode == 200) {
                  setState(() {
                    UserData.coins = (UserData.coins - advantage["price"]).toInt();
                  });

                  _showSnackbar("✅ Has comprado ${advantage["name"]}.");
                } else {
                  _showSnackbar("❌ Error al comprar la ventaja.");
                }
              }
                  : null, // Bloquea si no tiene suficientes monedas
              child: Text(
                "Comprar",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _buyAdvantage(Map<String, dynamic> advantage) async {
    Navigator.pop(context); // Cierra el diálogo de compra

    if (UserData.coins < advantage["price"]) {
      _showSnackbar("❌ No tienes suficientes monedas.");
      return;
    }

    final response = await http.post(
      Uri.parse("$apiUrl/buy-advantage"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": UserData.username,
        "advantage": advantage["column"],
        "price": advantage["price"]
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        UserData.coins = (UserData.coins - advantage["price"]).toInt();
      });
      _showSnackbar("✅ Has comprado ${advantage["name"]}.");
    } else {
      _showSnackbar("❌ Error al comprar la ventaja.");
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: InkWell(
                            onTap: () => _showPurchaseDialog(context, advantages[index]),
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
                      },
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
