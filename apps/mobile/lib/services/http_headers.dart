import 'package:flutter/foundation.dart' show kIsWeb;

import '../config.dart';

/// Identifies the app to the services it calls. Browsers send their own
/// User-Agent and refuse to override it, so on the web this is empty.
Map<String, String> get apiHeaders =>
    kIsWeb ? const {} : const {'User-Agent': appUserAgent};
