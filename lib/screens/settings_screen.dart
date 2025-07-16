import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'about_app_screen.dart';
import 'cache_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.cached),
            title: Text(AppLocalizations.of(context)!.cacheSettings),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CacheSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(AppLocalizations.of(context)!.aboutApp),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AboutAppScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
