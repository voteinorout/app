import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vioo_app/shared/services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const String _supportEmail = 'support@voteinorout.com';
  static const String _supportSubject = 'Comment or Feedback from App';

  Future<void> _launchSupportEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: <String, String>{'subject': _supportSubject},
    );

    try {
      final bool launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        _showErrorSnackBar(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showErrorSnackBar(context);
      }
    }
  }

  void _showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open email client.')),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    Navigator.of(context).pop();
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  Drawer _buildDrawer(BuildContext context) {
    final AuthService authService = AuthService();
    final String email = authService.currentUser?.email ?? 'User';
    final String? photoUrl = authService.getUserPhotoUrl();
    final String displayInitial = (() {
      final String? displayName = authService.currentUser?.displayName;
      final String source =
          (displayName != null && displayName.trim().isNotEmpty)
          ? displayName
          : email;
      final String trimmed = source.trim();
      if (trimmed.isEmpty) {
        return '?';
      }
      return trimmed.substring(0, 1).toUpperCase();
    })();

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                children: <Widget>[
                  Center(
                    child: Column(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          backgroundImage:
                              photoUrl != null && photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  displayInitial,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.mail_outline,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              email,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ListTile(
                    leading: const Icon(Icons.headset_mic_outlined),
                    title: const Text('Support'),
                    subtitle: const Text('Report a problem'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _launchSupportEmail(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms and Conditions'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/terms');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Log out'),
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String cta,
    VoidCallback? onPressed,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color iconColor = theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.12),
                  radius: 26,
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: onPressed, child: Text(cta)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/logo-vioo-navy.svg',
          height: 28,
          semanticsLabel: 'Vote In Or Out',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Viral Script Generator',
                style: theme.textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Campaign-ready scripts that keep viewers watching and taking action.',
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              _featureCard(
                context,
                icon: Icons.bolt,
                title: 'Viral Script Generator',
                description:
                    'Generate scroll-stopping scripts with timed beats and share-ready visuals.',
                cta: 'Create a script',
                onPressed: () => Navigator.pushNamed(context, '/config'),
              ),
              _featureCard(
                context,
                icon: Icons.shield_outlined,
                title: 'Fallacy Fighter',
                description:
                    'Upload a clip to flag fallacies and draft instant responses.',
                cta: 'Coming soon',
                onPressed: null,
              ),
              _featureCard(
                context,
                icon: Icons.group_work_outlined,
                title: 'Rebuttal + Action',
                description:
                    'Turn arguments into shareable responses with a clear action step.',
                cta: 'Coming soon',
                onPressed: null,
              ),
              _featureCard(
                context,
                icon: Icons.mic_outlined,
                title: 'Transcription (Beta)',
                description:
                    'Test on-device speech-to-text using the microphone or local clips.',
                cta: 'Coming soon',
                onPressed: null,
                //cta: 'Try transcription',
                //onPressed: () => Navigator.pushNamed(context, '/transcription'),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: Text(
                  'version 1.3.0',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    letterSpacing: 0.4,
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
