import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Confirmation card for HIGH-risk actions (spec §14). Never auto-executes.
class ConfirmationCard extends StatelessWidget {
  const ConfirmationCard({
    super.key,
    required this.body,
    required this.onConfirm,
    required this.onCancel,
  });

  final String body;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: NaraTheme.warning.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_rounded, color: NaraTheme.warning, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Konfirmasi diperlukan',
                  style: TextStyle(
                    color: NaraTheme.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: const TextStyle(height: 1.4)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: onCancel, child: const Text('Batal')),
                const SizedBox(width: 10),
                FilledButton(onPressed: onConfirm, child: const Text('Lanjutkan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
