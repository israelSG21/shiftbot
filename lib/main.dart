import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantallas/login_pantalla.dart';

void main() async {
  // Asegura que los enlaces de Flutter estén listos antes de inicializar servicios
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa la conexión con tu base de datos en Supabase
  await Supabase.initialize(
    url: 'https://hntmtdidwalqvaltkdqv.supabase.co',
    anonKey: 'sb_publishable_Lc236vcqh2uiiqFmXj3rFQ_DN0iChe6',
  );

  runApp(const MiAppBiblioteca());
}

class MiAppBiblioteca extends StatelessWidget {
  const MiAppBiblioteca({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Biblioteca FIME',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const LoginPantalla(),
    );
  }
}