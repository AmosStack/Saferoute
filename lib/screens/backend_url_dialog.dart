import 'package:flutter/material.dart';

import '../services/backend_service.dart';

Future<void> showBackendUrlDialog(BuildContext context) async {
  final currentBaseUrl = await BackendService.getStoredBaseUrl();
  final controller = TextEditingController(text: currentBaseUrl ?? '');
  String? errorText;

  if (!context.mounted) {
    controller.dispose();
    return;
  }

  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Backend URL'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set the API server URL for this device. Leave it blank to use the built-in defaults.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'API base URL',
                    hintText: 'http://192.168.1.50:3000',
                    errorText: errorText,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'On a physical Android phone, use your computer\'s LAN IP after USB disconnects.',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.tertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  controller.clear();
                  setState(() {
                    errorText = null;
                  });
                },
                child: const Text('Clear'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    final uri = Uri.tryParse(value);
                    if (uri == null || !uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
                      setState(() {
                        errorText = 'Enter a valid http or https URL.';
                      });
                      return;
                    }
                  }

                  Navigator.pop(dialogContext, value);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  controller.dispose();

  if (result == null) {
    return;
  }

  await BackendService.setStoredBaseUrl(result.isEmpty ? null : result);

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.isEmpty
            ? 'Backend URL cleared. The app will use its default connection path.'
            : 'Backend URL saved.',
      ),
    ),
  );
}