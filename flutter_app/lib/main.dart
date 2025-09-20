import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vioo App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vioo App')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final snack = SnackBar(content: Text('Hello from Vioo!'));
            ScaffoldMessenger.of(context).showSnackBar(snack);
          },
          child: const Text('Tap me'),
        ),
      ),
    );
  }
}
