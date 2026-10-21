import 'package:flutter/material.dart';

import '../storage/app_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            const _Section('Navigation'),
            SwitchListTile(
              title: const Text('Voice guidance'),
              subtitle: const Text('Speak turn instructions while navigating'),
              value: settings.voiceGuidance,
              onChanged: (v) => settings.voiceGuidance = v,
            ),
            SwitchListTile(
              title: const Text('Simulate navigation'),
              subtitle: const Text(
                'Drive the route automatically instead of following GPS. '
                'For trying the app out.',
              ),
              value: settings.simulateNavigation,
              onChanged: (v) => settings.simulateNavigation = v,
            ),
            const _Section('Route options'),
            SwitchListTile(
              title: const Text('Avoid tolls'),
              subtitle: const Text('e.g. expressways'),
              value: settings.avoidTolls,
              onChanged: (v) => settings.avoidTolls = v,
            ),
            SwitchListTile(
              title: const Text('Avoid highways'),
              value: settings.avoidHighways,
              onChanged: (v) => settings.avoidHighways = v,
            ),
            SwitchListTile(
              title: const Text('Avoid ferries'),
              value: settings.avoidFerries,
              onChanged: (v) => settings.avoidFerries = v,
            ),
            const _Section('Appearance'),
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (v) => settings.themeMode = v!,
              child: const Column(
                children: [
                  RadioListTile(
                    value: ThemeMode.system,
                    title: Text('Use device setting'),
                  ),
                  RadioListTile(value: ThemeMode.light, title: Text('Light')),
                  RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
