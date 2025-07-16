import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.aboutApp),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16.0),
            Text(
              localizations.appDescription,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24.0),
            Text(
              localizations.disclaimerTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8.0),
            Text(
              localizations.disclaimerContent,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24.0),
            Text(
              localizations.githubLinkTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8.0),
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://github.com/your-username/URdanchi');
                final messenger = ScaffoldMessenger.of(context);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text('无法打开链接: $url')),
                  );
                }
              },
              child: Text('https://github.com/your-username/URdanchi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
