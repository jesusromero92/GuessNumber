import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WinnerScreen extends StatelessWidget {
  final String winnerUsername;
  final String guessedNumber; // ✅ Nuevo: número adivinado

  WinnerScreen({required this.winnerUsername, required this.guessedNumber});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🎉 Animación de victoria
            Lottie.asset(
              'assets/trophy.json', // Asegúrate de tener este archivo en 'assets'
              width: 250,
              height: 250,
              fit: BoxFit.cover,
            ),
            SizedBox(height: 20),

            // 🏆 Mensaje de victoria
            Text(
              "¡${winnerUsername} ha ganado!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),

            // 🔢 Número adivinado
            Text(
              "Número Adivinado: $guessedNumber",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.greenAccent,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),

            // 🔥 Botón para volver al inicio
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                "Volver al Inicio",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
