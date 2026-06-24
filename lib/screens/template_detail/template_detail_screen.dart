import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';

class TemplateDetailScreen extends StatelessWidget {
  const TemplateDetailScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context) {
    // TODO: fetch Template by templateId via TemplatesController.
    return Scaffold(
      appBar: AppBar(title: const Text('Template Details')),
      body: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, size: 120, color: Colors.grey.shade300),
                    const SizedBox(height: kSpaceMd),
                    Text('Template: $templateId',
                        style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: kSpaceSm),
                    Text('Price: ₹ —',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  context.go('/home/create-order/$templateId'),
              child: const Text('Create'),
            ),
            const SizedBox(height: kSpaceMd),
          ],
        ),
      ),
    );
  }
}
