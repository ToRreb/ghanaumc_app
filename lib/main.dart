import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/welcome_screen.dart'; // Import the welcome_screen screen
import 'screens/group_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GUMC App',
      theme: ThemeData(primarySwatch: Colors.deepPurple,),
      home: WelcomeScreen(), // Set WelcomeScreen as the first screen
    );
  }
}




