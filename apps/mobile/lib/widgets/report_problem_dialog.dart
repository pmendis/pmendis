import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/place.dart';
import '../services/osm_notes_service.dart';

/// Asks what's wrong at [location] and posts it as an OpenStreetMap Note.
/// Returns the note's web page, or null if cancelled.
Future<Uri?> showReportProblemDialog(
  BuildContext context, {
  required OsmNotesService notes,
  required LatLng location,
  String? placeName,
}) => showDialog<Uri>(
  context: context,
  builder: (_) => _ReportProblemDialog(
    notes: notes,
    location: location,
    placeName: placeName,
  ),
);

class _ReportProblemDialog extends StatefulWidget {
  const _ReportProblemDialog({
    required this.notes,
    required this.location,
    this.placeName,
  });

  final OsmNotesService notes;
  final LatLng location;
  final String? placeName;

  @override
  State<_ReportProblemDialog> createState() => _ReportProblemDialogState();
}

class _ReportProblemDialogState extends State<_ReportProblemDialog> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _error;

  static const _examples = [
    'Missing road',
    'Road is closed',
    'Wrong name',
    'Missing place',
    'Place has closed',
  ];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.length < 5) {
      setState(() => _error = 'Please describe the problem in a few words.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final about = widget.placeName == null
          ? ''
          : 'About "${widget.placeName}": ';
      final url = await widget.notes.createNote(widget.location, '$about$text');
      if (mounted) Navigator.of(context).pop(url);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Could not send. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Report a map problem'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Near ${widget.placeName ?? formatCoordinates(widget.location)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _examples)
                  ActionChip(
                    label: Text(e),
                    onPressed: () {
                      _text.text = _text.text.isEmpty
                          ? '$e: '
                          : '${_text.text} $e';
                      _text.selection = TextSelection.collapsed(
                        offset: _text.text.length,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 6,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'What is missing or wrong here?',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            Text(
              'Reports are public OpenStreetMap Notes. Volunteer mappers review '
              'them and fix the map, and the fix reaches this app after the next '
              'data refresh. Don\'t include personal information.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
