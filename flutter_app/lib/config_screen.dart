import 'package:flutter/material.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({Key? key}) : super(key: key);

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _ctaController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _lengthController = TextEditingController(text: '30');

  String _style = 'Educational';

  @override
  void dispose() {
    _ctaController.dispose();
    _topicController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  void _generateScript() {
    if (!_formKey.currentState!.validate()) return;

    final Map<String, dynamic> args = {
      'cta': _ctaController.text.trim().isEmpty ? null : _ctaController.text.trim(),
      'topic': _topicController.text.trim(),
      'length': int.tryParse(_lengthController.text) ?? 30,
      'style': _style,
    };

    Navigator.of(context).pushNamed('/script', arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1E2A44);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _ctaController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Video call-to-action',
                    hintText: 'e.g. Sign up at example.com',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _topicController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Describe the payoff or main topic',
                    hintText: 'What is the main takeaway?',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please describe the payoff or topic.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _lengthController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Length (seconds)',
                    hintText: '30',
                    hintStyle: TextStyle(color: Colors.white70),
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a positive number.';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _style,
                  dropdownColor: bgColor,
                  decoration: const InputDecoration(
                    labelText: 'Style',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Educational', child: Text('Educational')),
                    DropdownMenuItem(value: 'Entertaining', child: Text('Entertaining')),
                  ],
                  onChanged: (v) => setState(() => _style = v ?? 'Educational'),
                ),

                const Spacer(),

                ElevatedButton(
                  onPressed: _generateScript,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text('Generate script'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
