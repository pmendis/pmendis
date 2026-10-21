import 'package:flutter/material.dart';

import '../services/external_navigation.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const version = '0.3.0';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget link(String label, String url) => ListTile(
      title: Text(label),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () => openWebPage(Uri.parse(url)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lanka Maps', style: text.headlineSmall),
                Text('Version $version'),
                const SizedBox(height: 12),
                const Text(
                  'Free maps, search and turn-by-turn navigation for Sri Lanka, '
                  'built on open data and open-source software. No ads and no '
                  'tracking: your saved places stay on this device, and your '
                  'location is only used on your phone and to request routes.',
                ),
                const SizedBox(height: 16),
                Text('Map data', style: text.titleMedium),
                const Text(
                  '© OpenStreetMap contributors, available under the Open '
                  'Database License (ODbL). Anyone can improve the map: use '
                  '"Report a problem" in the app, or edit OpenStreetMap directly.',
                ),
              ],
            ),
          ),
          link(
            'OpenStreetMap copyright and license',
            'https://www.openstreetmap.org/copyright',
          ),
          link(
            'Improve the map: start editing OpenStreetMap',
            'https://www.openstreetmap.org/edit',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Public services', style: text.titleMedium),
                const Text(
                  'Unless you set up your own server, the app uses these free, '
                  'volunteer-run services. Please use them considerately.',
                ),
              ],
            ),
          ),
          link('Map tiles: OpenFreeMap', 'https://openfreemap.org'),
          link(
            'Routing: Valhalla by FOSSGIS',
            'https://routing.openstreetmap.de',
          ),
          link('Search: Photon by komoot', 'https://photon.komoot.io'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Software', style: text.titleMedium),
          ),
          link('Protomaps (own-server tiles)', 'https://protomaps.com'),
          link('Valhalla', 'https://github.com/valhalla/valhalla'),
          link('Nominatim (own-server search)', 'https://nominatim.org'),
          link('MapLibre', 'https://maplibre.org'),
          ListTile(
            title: const Text('Open-source licenses'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Lanka Maps',
              applicationVersion: version,
            ),
          ),
        ],
      ),
    );
  }
}
