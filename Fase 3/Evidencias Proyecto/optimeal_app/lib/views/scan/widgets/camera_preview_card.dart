import 'package:flutter/material.dart';

class CameraPreviewCard extends StatelessWidget {
  final VoidCallback onOpenCameraPressed;
  const CameraPreviewCard({super.key, required this.onOpenCameraPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                  color: cs.surfaceContainerHighest,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.image_outlined, size: 48),
                    SizedBox(height: 8),
                    Text('Preview de la imagen (placeholder)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Abrir cámara'),
              onPressed: onOpenCameraPressed,
            ),
          ],
        ),
      ),
    );
  }
}
