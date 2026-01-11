import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'game_history_screen.dart';
import 'auth_service.dart';
import 'tournament_schedule_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("🚀 Starting Firebase initialization...");

  try {
    // FIRST TRY: Simple initialization (uses GoogleService-Info.plist on iOS)
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully with default settings!");

    // Verify the app was created
    final defaultApp = Firebase.app();
    print("📱 Default Firebase App Name: ${defaultApp.name}");
    print("📱 Firebase Project ID: ${defaultApp.options.projectId}");

  } catch (e, stack) {
    print("❌ Default Firebase initialization FAILED!");
    print("❌ Error: $e");

    // SECOND TRY: Explicit initialization with DEFAULT app name
    try {
      print("🔄 Trying explicit initialization with default app name...");

      await Firebase.initializeApp(
        name: '[DEFAULT]',  // Explicitly name it DEFAULT
        options: const FirebaseOptions(
          apiKey: "AIzaSyDPcfPB4VI-UBs8abe90Czj8izGPwfqjfM",
          appId: "1:828065306729:ios:dd04c4a19c6de92495aaf8",
          messagingSenderId: "828065306729",
          projectId: "spades-customer-service",
          storageBucket: "spades-customer-service.firebasestorage.app",
          iosBundleId: "com.spades.spades-customer-service",
        ),
      );
      print("✅ Firebase initialized with explicit options as DEFAULT app!");

    } catch (e2) {
      print("❌ Explicit initialization also failed: $e2");
      print("⚠️ App will continue but Firebase features may not work");
    }
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        title: 'SPADES Poker Manager',
        theme: ThemeData(
          primaryColor: Color(0xFFDC2626),
          scaffoldBackgroundColor: Color(0xFF111827),
          colorScheme: ColorScheme.dark(
            primary: Color(0xFFDC2626),
            secondary: Colors.white,
            background: Color(0xFF111827),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF1F2937),
            elevation: 0,
          ),
        ),
        home: LoginScreen(),  // REMOVED const
        routes: {
          '/welcome': (context) => WelcomeScreen(),  // REMOVED const
          '/history': (context) => GameHistoryScreen(),  // REMOVED const
          '/schedule': (context) => TournamentScheduleScreen(),  // REMOVED const
        },
      ),
    );
  }
}