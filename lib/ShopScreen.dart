import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'top_bar.dart';
import 'user_data.dart'; // 🔥 Para acceder a las monedas del usuario

class ShopScreen extends StatefulWidget {
  @override
  _ShopScreenState createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final String apiUrl = "http://109.123.248.19:4000"; // 🔥 URL de tu API

  final List<Map<String, dynamic>> advantages = [
    {
      "name": "Pista Extra",
      "column": "advantage_hint_extra", // 🔥 Coincide con la BD
      "icon": Icons.lightbulb_outline,
      "price": 150,
      "description": "Te da una pista sobre la posición correcta."
    },
    {
      "name": "Revelar un Número",
      "column": "advantage_reveal_number", // 🔥 Coincide con la BD
      "icon": Icons.visibility,
      "price": 75,
      "description": "Muestra un número correcto aleatorio."
    },
    {
      "name": "Repetir Intento",
      "column": "advantage_repeat_attempt", // 🔥 Coincide con la BD
      "icon": Icons.undo,
      "price": 100,
      "description": "Te permite volver a intentar sin penalización."
    },
    {
      "name": "Bloquear Oponente",
      "column": "advantage_block_opponent", // 🔥 Coincide con la BD
      "icon": Icons.block,
      "price": 150,
      "description": "Evita que el oponente use ventajas por 2 turnos."
    },
  ];

  /// 🔥 Muestra un **diálogo de confirmación** antes de comprar
  void _showPurchaseDialog(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          backgroundColor: Colors.black87,
          // 🔥 Fondo oscuro elegante
          title: Row(
            children: [
              Icon(advantages[index]["icon"], color: Colors.amber, size: 30),
              SizedBox(width: 10),
              Text(
                advantages[index]["name"],
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                advantages[index]["description"],
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                "Precio: ${advantages[index]['price']} 🪙",
                style: TextStyle(color: Colors.greenAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                  "Cancelar", style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent),
              onPressed: () {
                Navigator.pop(context);
                _purchaseAdvantage(index);
              },
              child: Text("Comprar", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  /// 🔥 **Compra una ventaja y actualiza la base de datos**
  /// 🔥 **Compra una ventaja y actualiza la base de datos**
  Future<void> _purchaseAdvantage(int index) async {
    int price = advantages[index]["price"];
    String advantageName = advantages[index]["name"];
    String advantageColumn = advantages[index]["column"]; // 🔥 Ahora se envía el nombre de la columna correcta

    if (UserData.coins >= price) {
      bool success = await _buyAdvantageOnServer(
          advantageColumn, price); // 🔥 Se pasa advantageColumn

      if (success) {
        setState(() {
          UserData.coins -= price; // 🔥 Descuenta monedas localmente
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("✅ Compraste $advantageName por $price monedas.")),
        );
      } else {
        _showErrorDialog("Hubo un error al procesar la compra.");
      }
    } else {
      _showInsufficientFundsDialog();
    }
  }

  /// 🔥 **Llama a la API para actualizar la base de datos**
  Future<bool> _buyAdvantageOnServer(String advantageColumn, int price) async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl/buy-advantage"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": UserData.username,
          "advantage": advantageColumn,
          // 🔥 Ahora envía el nombre correcto de la columna
          "price": price,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("❌ Error en la compra: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Error en la solicitud: $e");
      return false;
    }
  }


  /// 🔥 **Muestra un error si no hay monedas suficientes**
  void _showInsufficientFundsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          title: Text(
              "Monedas insuficientes", style: TextStyle(color: Colors.white)),
          content: Text(
            "No tienes suficientes monedas para comprar esta ventaja.",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  /// 🔥 **Muestra un error en caso de fallar la compra**
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          title: Text("Error", style: TextStyle(color: Colors.white)),
          content: Text(
            message,
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                MainScreen(),
            transitionDuration: Duration.zero, // 🔥 Sin animación
            reverseTransitionDuration: Duration
                .zero, // 🔥 Sin animación al volver
          ),
        );
        return false; // 🔥 Bloquea la navegación normal del botón "Atrás"
      },
      child: Scaffold(
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
                  image: AssetImage("assets/background_shop.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.6), BlendMode.darken),
                ),
              ),
            ),

            // 🔥 Contenido principal
            Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
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
                            onTap: () => _showPurchaseDialog(index),
                            borderRadius: BorderRadius.circular(15),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(advantages[index]['icon'], size: 50,
                                    color: Colors.amber),
                                SizedBox(height: 10),
                                Text(
                                  advantages[index]['name'],
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 5),
                                Text(
                                  "${advantages[index]['price']} 🪙",
                                  style: TextStyle(color: Colors.greenAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}