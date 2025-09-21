import 'package:flutter/material.dart';

/// HomeScreen for Vote In Or Out
///
/// Displays three feature cards and an AppBar with a centered title.
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  static const Color _darkBlue = Color(0xFF1E2A44);

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _darkBlue,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onPressed,
              child: const Text('Create a script'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBlue,
      appBar: AppBar(
        backgroundColor: _darkBlue,
        centerTitle: true,
        title: const Text(
          'VOTE IN OR OUT',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _featureCard(
              icon: Icons.anchor,
              title: '3-Second Hooks',
              description: "Generate scripts with hooks every 3 seconds to keep 'em engaged",
              onPressed: () => Navigator.pushNamed(context, '/config'),
            ),
            _featureCard(
              icon: Icons.sentiment_satisfied,
              title: 'Fallacy Fighter',
              description: 'Identify and respond to common fallacies gracefully',
              onPressed: () {},
            ),
            _featureCard(
              icon: Icons.handshake,
              title: 'Rebuttal + Action',
              description: 'Quick rebuttals with a suggested next action',
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            // Expand to push content to top if needed
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }
}
