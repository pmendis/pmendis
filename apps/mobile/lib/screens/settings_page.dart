import 'package:flutter/material.dart';

import '../services/backend.dart';
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
            const _Section('Map data'),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Map data source'),
              subtitle: Text(settings.backend.label),
              onTap: () => showBackendDialog(context, settings),
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

/// Lets the user choose between the public services and their own server.
Future<void> showBackendDialog(BuildContext context, AppSettings settings) =>
    showDialog<void>(
      context: context,
      builder: (_) => _BackendDialog(settings: settings),
    );

class _BackendDialog extends StatefulWidget {
  const _BackendDialog({required this.settings});

  final AppSettings settings;

  @override
  State<_BackendDialog> createState() => _BackendDialogState();
}

class _BackendDialogState extends State<_BackendDialog> {
  late BackendMode _mode = widget.settings.backend.mode;
  late final _url = TextEditingController(
    text: widget.settings.ownServerUrl ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _save() {
    if (_mode == BackendMode.publicServices) {
      widget.settings.usePublicServices();
    } else {
      final url = normalizeServerUrl(_url.text);
      if (url == null) {
        setState(
          () => _error = 'Enter an address like http://192.168.1.20:8080',
        );
        return;
      }
      widget.settings.useOwnServer(url);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Map data source'),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SingleChildScrollView(
        child: RadioGroup<BackendMode>(
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const RadioListTile(
                value: BackendMode.publicServices,
                title: Text('Public OpenStreetMap services'),
                subtitle: Text(
                  'Works without any setup. Free, volunteer-run; '
                  'for personal use.',
                ),
              ),
              const RadioListTile(
                value: BackendMode.ownServer,
                title: Text('My own server'),
                subtitle: Text(
                  'A Lanka Maps server you run (see the project README).',
                ),
              ),
              if (_mode == BackendMode.ownServer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: TextField(
                    controller: _url,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    onSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: 'Server address',
                      hintText: 'http://192.168.1.20:8080',
                      border: const OutlineInputBorder(),
                      errorText: _error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
