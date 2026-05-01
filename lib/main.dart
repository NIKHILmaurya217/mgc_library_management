import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // THE NEWLY GENERATED FILE
import 'auth/login.dart'; // Your login page
import 'home.dart'; // Your test home page
import 'core/theme/app_theme.dart'; // Import theme
import 'package:provider/provider.dart';
import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase using the generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Library RFID',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: context.watch<ThemeProvider>().themeMode,
      // The Gatekeeper: Listens to login/logout events
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // If data exists, user is logged in -> Go to Home
          if (snapshot.hasData) {
            return const HomePage();
          }
          // Otherwise -> Go to Login
          return LoginPage();
        },
      ),
    );
  }
}