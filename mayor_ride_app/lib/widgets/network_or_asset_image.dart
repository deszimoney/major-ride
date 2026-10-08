import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Product photos can be a bundled asset path, a remote URL, or a base64
/// `data:` URI captured by the admin's image picker — this widget renders
/// whichever one it is given, matching how `<img src>` behaved on the site.
class NetworkOrAssetImage extends StatelessWidget {
  const NetworkOrAssetImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _placeholder();

    if (source.startsWith('data:')) {
      final base64Marker = source.indexOf('base64,');
      if (base64Marker == -1) return _placeholder();
      try {
        final bytes = base64Decode(source.substring(base64Marker + 7));
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      } on FormatException {
        return _placeholder();
      }
    }

    if (source.startsWith('http://') || source.startsWith('https://')) {
      // The seed catalog once pointed a few entries at bare "https://unsplash.com".
      if (Uri.tryParse(source)?.pathSegments.isEmpty ?? true) {
        return _placeholder();
      }
      return CachedNetworkImage(
        imageUrl: source,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, _) => _placeholder(loading: true),
        errorWidget: (_, _, _) => _placeholder(),
      );
    }

    final assetPath = source.startsWith('assets/') ? source : 'assets/$source';
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.panelSoft,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.two_wheeler, color: AppColors.mutedText),
    );
  }
}
