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
            const _Section('Map server'),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: const Text('Server address'),
              subtitle: Text(settings.serverUrl),
              onTap: () => showServerDialog(context, settings),
            ),
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

/// Lets the user point the app at their own Lanka Maps server.
Future<void> showServerDialog(BuildContext context, AppSettings settings) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ServerDialog(settings: settings),
    );

class _ServerDialog extends StatefulWidget {
  const _ServerDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  late final _text = TextEditingController(text: widget.settings.serverUrl);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final url = normalizeServerUrl(_text.text);
    if (url == null) {
      setState(() => _error = 'Enter an address like http://192.168.1.20:8080');
      return;
    }
    widget.settings.serverUrl = url;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Map server'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The address of your Lanka Maps server (the gateway started '
            'with docker compose), as seen from this phone.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              hintText: 'http://192.168.1.20:8080',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        if (widget.settings.hasCustomServer)
          TextButton(
            onPressed: () {
              widget.settings.serverUrl = null;
              Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
