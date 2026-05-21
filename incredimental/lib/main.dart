import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'engine/game_engine.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    // Provider ile motorumuzu uygulamanın en tepesine sarıyoruz
    ChangeNotifierProvider(
      create: (context) => GameEngine(),
      child: const BenimOyunum(),
    ),
  );
}

class BenimOyunum extends StatelessWidget {
  const BenimOyunum({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Botanical Tycoon',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
      ),
      home: const AnaEkran(), // Arayüzü home_screen.dart dosyasından çekiyor
    );
  }
}