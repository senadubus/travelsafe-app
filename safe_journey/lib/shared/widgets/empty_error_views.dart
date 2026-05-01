import 'package:flutter/material.dart';

const _kPrimary = Color(0xFF6B4FA0);

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.selectedType});
  final String selectedType;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No results for "$selectedType"',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Could not load data',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
                style: FilledButton.styleFrom(backgroundColor: _kPrimary),
              ),
            ],
          ),
        ),
      );
}
