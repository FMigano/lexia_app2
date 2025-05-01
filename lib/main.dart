import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lexia_app/firebase_options.dart';
import 'package:lexia_app/providers/auth_provider.dart' as app_auth;
import 'package:lexia_app/providers/theme_provider.dart';
import 'package:lexia_app/screens/splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('🔥 Starting Firebase initialization...');

    // First initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    debugPrint('✓ Firebase core initialized successfully');

    // Brief delay to ensure initialization is complete
    await Future.delayed(const Duration(milliseconds: 300));

    // Test Firebase Storage access
    try {
      final storageRef = FirebaseStorage.instance.ref();
      debugPrint('✓ Firebase Storage initialized successfully');
    } catch (storageError) {
      debugPrint('❌ Firebase Storage error: $storageError');
    }

    // Only now access Firestore
    if (kDebugMode) {
      try {
        // Configure Firestore settings
        FirebaseFirestore.instance.settings =
            const Settings(persistenceEnabled: true); // Enable persistence
        FirebaseFirestore.setLoggingEnabled(true);
        debugPrint('✓ Firestore configured successfully');
      } catch (e) {
        debugPrint('❌ Error configuring Firestore: $e');
      }
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
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        primarySwatch: Colors.blue,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.poppins(),
          ),
        ),
        appBarTheme: AppBarTheme(
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
          // You can add these lines for better contrast in dark mode
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
          primary: Colors.deepPurple.shade300, // Lighter shade for better visibility
        ),
        // Make text more readable in dark mode
        textTheme: GoogleFonts.poppinsTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
    );
  }
}
