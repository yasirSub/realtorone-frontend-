import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_routes.dart';
import 'routes/route_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: const RealtorOneApp(),
    ),
  );
}

class RealtorOneApp extends StatelessWidget {
  const RealtorOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'RealtorOne',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea),
          surface: const Color(0xFFF8FAFC),
          surfaceContainer: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: _inputTheme(Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea),
          surface: const Color(0xFF0F172A),
          surfaceContainer: const Color(0xFF1E293B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        inputDecorationTheme: _inputTheme(Brightness.dark),
      ),
      initialRoute: AppRoutes.initial,
      routes: RouteConfig.getRoutes(),
    );
  }

  InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.white30 : const Color(0xFFCBD5E1),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
