import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lexia_app/firebase_options.dart';
import 'package:lexia_app/providers/auth_provider.dart' as app_auth;
import 'package:lexia_app/providers/theme_provider.dart';
import 'package:lexia_app/screens/splash_screen.dart';
import 'package:lexia_app/screens/auth/login_screen.dart';
import 'package:lexia_app/screens/home/home_screen.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('🔥 Starting Firebase initialization...');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('✓ Firebase core initialized successfully');

    if (kDebugMode) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Lexia',
      debugShowCheckedModeBanner: false,
      
      // ✅ FIXED: Proper theme configuration without TextTheme conflicts
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        // ✅ Use fontFamily instead of textTheme to avoid interpolation errors
        fontFamily: GoogleFonts.poppins().fontFamily,
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: GoogleFonts.poppins().fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          primary: Colors.deepPurple.shade300,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        // ✅ Use fontFamily instead of textTheme
        fontFamily: GoogleFonts.poppins().fontFamily,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: TextStyle(
            fontFamily: GoogleFonts.poppins().fontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
      initialRoute: '/',
    );
  }
}
