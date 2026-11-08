import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../data/messages/message_media.dart';
import '../../ui/components/td_image.dart';

class MediaView extends StatelessWidget {
  const MediaView({super.key, required this.media, required this.maxWidth});

  final MessageMedia media;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return switch (media) {
      PhotoMedia(:final image) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PhotoViewer(image: image)),
        ),
        child: _Sized(image: image, maxWidth: maxWidth, child: TdImage(image)),
      ),
      StickerMedia(:final image, :final emoji, :final isStatic) =>
        isStatic || image.fileId != null
            ? SizedBox.square(
                dimension: 160,
                child: TdImage(image, fit: BoxFit.contain),
              )
            : Text(emoji, style: const TextStyle(fontSize: 64)),
      VideoMedia(:final cover, :final duration, :final isRound) => _Sized(
        image: cover,
        maxWidth: isRound ? 200 : maxWidth,
        round: isRound,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TdImage(cover),
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                size: 48,
                color: Colors.white70,
              ),
            ),
            if (duration > 0)
              Positioned(
                left: 6,
                bottom: 6,
                child: _Chip(text: formatDuration(duration)),
              ),
          ],
        ),
      ),
      DocumentMedia(:final name, :final size) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? context.l10n.previewDocument : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(formatSize(size), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      VoiceMedia(:final duration) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 20),
          const SizedBox(width: 6),
          Text(formatDuration(duration)),
        ],
      ),
    };
  }
}

class _Sized extends StatelessWidget {
  const _Sized({
    required this.image,
    required this.maxWidth,
    required this.child,
    this.round = false,
  });

  final MediaImage image;
  final double maxWidth;
  final Widget child;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final aspect = round ? 1.0 : image.aspect.clamp(0.5, 2.0);
    final width = maxWidth.clamp(120.0, 360.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(round ? width : 12),
      child: SizedBox(width: width, height: width / aspect, child: child),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontSize: 11),
    ),
  );
}

class PhotoViewer extends StatelessWidget {
  const PhotoViewer({super.key, required this.image});

  final MediaImage image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(child: TdImage(image, fit: BoxFit.contain)),
      ),
    );
  }
}

String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}
