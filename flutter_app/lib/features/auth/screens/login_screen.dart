import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:vioo_app/shared/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    final user = await _authService.signInWithApple();
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (user != null) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Color(0xFF031750);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: SvgPicture.asset(
                    'assets/logo-vioo-white.svg',
                    width: 180,
                    semanticsLabel: 'Vote In Or Out Logo',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SignInWithAppleButton(
                onPressed: _isLoading ? null : _handleAppleSignIn,
                text: _isLoading ? 'Signing in…' : 'Sign in with Apple',
                style: SignInWithAppleButtonStyle.white,
                borderRadius: const BorderRadius.all(Radius.circular(24)),
              ),
              const SizedBox(height: 32),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    children: <TextSpan>[
                      const TextSpan(
                        text: 'By creating an account you agree to our ',
                      ),
                      TextSpan(
                        text: 'Terms and Conditions',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Terms and Conditions coming soon.',
                                ),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
