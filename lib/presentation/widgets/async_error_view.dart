import 'package:flutter/material.dart';

import '../theme/nen_theme.dart';

class AsyncErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  final String title;

  const AsyncErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.title = 'Could not load this section',
  });

  @override
  Widget build(BuildContext context) {
    final colors = NenTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
