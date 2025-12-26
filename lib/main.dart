import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'game_history_screen.dart';
import 'auth_service.dart';
// Add import at the top
import 'tournament_schedule_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Keep it simple like this
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthService()..initializeData(), // Call initializeData here
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
        home: LoginScreen(),
        routes: {
          '/welcome': (context) => WelcomeScreen(),
          '/history': (context) => GameHistoryScreen(),
          '/schedule': (context) => TournamentScheduleScreen(),
        },
      ),
    );
  }
}