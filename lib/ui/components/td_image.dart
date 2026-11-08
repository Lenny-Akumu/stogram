import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/files/files_repository.dart';
import '../../data/messages/message_media.dart';

/// Shows a TDLib file as an image, downloading it on first build.
class TdImage extends ConsumerStatefulWidget {
  const TdImage(this.image, {super.key, this.fit = BoxFit.cover});

  final MediaImage image;
  final BoxFit fit;

  @override
  ConsumerState<TdImage> createState() => _TdImageState();
}

class _TdImageState extends ConsumerState<TdImage> {
  StreamSubscription<TdFile>? _sub;
  TdFile? _file;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(TdImage old) {
    super.didUpdateWidget(old);
    if (old.image.fileId != widget.image.fileId) {
      unawaited(_sub?.cancel());
      _bind();
    }
  }

  void _bind() {
    final id = widget.image.fileId;
    if (id == null) return;
    final files = ref.read(filesRepositoryProvider);
    files.seed(widget.image.file);
    _file = files.get(id);
    _sub = files.watch(id).listen((f) {
      if (mounted) setState(() => _file = f);
    });
    if (!(_file?.ready ?? false)) unawaited(files.download(id));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file != null && file.ready) {
      return Image.file(
        File(file.path),
        fit: widget.fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _placeholder(widget.image.mini),
      );
    }
    return _placeholder(widget.image.mini);
  }

  Widget _placeholder(Uint8List? mini) => mini == null
      ? ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest)
      : Image.memory(mini, fit: widget.fit, gaplessPlayback: true);
}
