import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// One-tap example commands (spec §13 quick commands). Bilingual examples
/// cover the core capabilities without flooding the screen.
class QuickCommands extends StatelessWidget {
  const QuickCommands({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _commands = <(String, IconData)>[
    ('Buka WhatsApp', Icons.chat_rounded),
    ('Cari tutorial Flutter di YouTube', Icons.smart_display_rounded),
    ('Navigasi ke rumah sakit terdekat', Icons.map_rounded),
    ('Siapkan email ke atasan', Icons.alternate_email_rounded),
    ('Buka pengaturan wifi', Icons.wifi_rounded),
    ('Baca isi layar', Icons.visibility_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perintah cepat',
          style: TextStyle(
            color: NaraTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, icon) in _commands)
              ActionChip(
                avatar: Icon(icon, size: 16, color: NaraTheme.accentBlue),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                backgroundColor: NaraTheme.card,
                side: BorderSide(color: NaraTheme.accentPurple.withValues(alpha: 0.3)),
                onPressed: () => onSelected(label),
              ),
          ],
        ),
      ],
    );
  }
}
