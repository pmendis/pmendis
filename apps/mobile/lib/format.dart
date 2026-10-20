String formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

String formatDistance(double km) {
  if (km < 1) return '${(km * 1000 / 10).round() * 10} m';
  if (km < 10) return '${km.toStringAsFixed(1)} km';
  return '${km.round()} km';
}
