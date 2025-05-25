import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChapChapApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ChapChapApp extends StatefulWidget {
  const ChapChapApp({Key? key}) : super(key: key);

  @override
  State<ChapChapApp> createState() => _ChapChapAppState();
}

class _ChapChapAppState extends State<ChapChapApp> {
  bool? _isAdmin;

  void _onLogin(bool isAdmin) {
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'CHAP-CHAP',
      theme: ThemeData(
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: const Color(0xFF1565C0),
          onPrimary: Colors.white,
          secondary: const Color(0xFFFF9800),
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.white,
          background: const Color(0xFFF4F6FB),
          onBackground: Colors.black87,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        textTheme: GoogleFonts.montserratTextTheme(),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}
