import 'dart:convert';
import 'package:flutter/material.dart';

class VenueImageView extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? errorWidget;

  const VenueImageView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = errorWidget ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFCBD5E1),
          alignment: Alignment.center,
          child: const Icon(Icons.sports_tennis, color: Colors.white, size: 36),
        );

    final trimmed = imageUrl.trim();
    if (trimmed.isEmpty) {
      return fallback;
    }

    // Xử lý ảnh dạng Data URL / Base64 tải trực tiếp từ máy tính
    if (trimmed.startsWith('data:image') || (!trimmed.startsWith('http') && trimmed.length > 100)) {
      try {
        final commaIdx = trimmed.indexOf(',');
        final base64Str = commaIdx != -1 ? trimmed.substring(commaIdx + 1) : trimmed;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => fallback,
        );
      } catch (_) {
        return fallback;
      }
    }

    // Xử lý ảnh dạng URL mạng
    return Image.network(
      trimmed,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
    );
  }
}
