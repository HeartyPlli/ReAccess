import 'package:flutter/material.dart';

import 'landing_sections.dart';

Future<void> showRequestDialog(BuildContext context, String type) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$type account services'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Online request submission is not open yet. Please visit the CISO Office to verify your identity and submit a request.',
                ),
                const SizedBox(height: 20),
                for (final service in accountServices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(service.$1),
                    title: Text(service.$2),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'No public account or login is required. Never share passwords or verification codes in chat.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
