import 'package:flutter/material.dart';

import '../../data/messages/message_media.dart';
import 'td_image.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.id,
    required this.title,
    this.photo,
    this.size = 48,
  });

  final int id;
  final String title;
  final MediaImage? photo;
  final double size;

  static const _palette = [
    Color(0xFF8E8E8E),
    Color(0xFF545A68),
    Color(0xFF262626),
    Color(0xFFFF453A),
  ];

  @override
  Widget build(BuildContext context) {
    final p = photo;
    final letters = title
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w.characters.first.toUpperCase())
        .join();
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: p != null && (p.fileId != null || p.mini != null)
            ? TdImage(p)
            : ColoredBox(
                color: _palette[id.abs() % _palette.length],
                child: Center(
                  child: Text(
                    letters,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.36,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
