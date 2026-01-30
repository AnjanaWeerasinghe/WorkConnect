import 'package:work_connect/auth.dart';
import 'package:work_connect/pages/home_page.dart';
import 'package:work_connect/pages/login_register_page.dart';
import 'package:flutter/material.dart';

class WidgetTree extends StatelessWidget {
  const WidgetTree({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Auth',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: AuthService().currentUser == null ? '/login' : '/home',
      routes: {
        '/login': (context) => const LoginRegisterPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}