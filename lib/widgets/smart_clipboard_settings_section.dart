import 'package:flutter/material.dart';

import '../services/smart_clipboard_service.dart';

class SmartClipboardSettingsSection extends StatefulWidget {
  const SmartClipboardSettingsSection({super.key});

  @override
  State<SmartClipboardSettingsSection> createState() =>
      _SmartClipboardSettingsSectionState();
}

class _SmartClipboardSettingsSectionState
    extends State<SmartClipboardSettingsSection> {
  final _service = SmartClipboardService.instance;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled;
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _setEnabled(bool value) async {
    if (value && _service.isSupported) {
      final granted = await _service.requestOverlayPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Allow Display over other apps first.'),
            ),
          );
        }
        return;
      }
    }
    await _service.setEnabled(value);
    if (mounted) {
      setState(() => _enabled = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.content_paste_search_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Floating Quick Input',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Switch(
                  value: _enabled,
                  onChanged: _loading || !_service.isSupported
                      ? null
                      : _setEnabled,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _service.isSupported
                  ? 'Keep a draggable Maliyati button above other apps. Copy any text, then tap it to open Input by code. Long-press the bubble to hide it.'
                  : 'This Android-only action is unavailable on this platform.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_service.isSupported) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                        await _setEnabled(true);
                      },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Show floating button'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
