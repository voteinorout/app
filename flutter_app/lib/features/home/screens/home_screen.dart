import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                  'version 1.2.11',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
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
