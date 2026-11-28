// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// TODO: chuyển sang package:web + dart:js_interop (dart:html đã bị đánh dấu lỗi thời)
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Chọn ảnh từ máy tính / thiết bị trên Web và nén tối ưu (kích thước tối đa 800px, JPEG 82%)
Future<String?> pickAndProcessImage() async {
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement();
  uploadInput.accept = 'image/*';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);

      reader.onLoadEnd.listen((e) {
        final rawDataUrl = reader.result;
        if (rawDataUrl is! String) {
          completer.complete(null);
          return;
        }

        // Tối ưu hóa kích thước ảnh bằng Canvas để lưu nhanh và nhẹ nhàng
        final img = html.ImageElement();
        img.src = rawDataUrl;

        img.onLoad.listen((_) {
          try {
            int width = img.width ?? 800;
            int height = img.height ?? 600;
            const maxDim = 800;

            if (width > maxDim || height > maxDim) {
              if (width > height) {
                height = (height * maxDim / width).round();
                width = maxDim;
              } else {
                width = (width * maxDim / height).round();
                height = maxDim;
              }
            }

            final canvas = html.CanvasElement(width: width, height: height);
            final ctx = canvas.context2D;
            ctx.drawImageScaled(img, 0, 0, width, height);

            final compressed = canvas.toDataUrl('image/jpeg', 0.82);
            completer.complete(compressed);
          } catch (_) {
            // Fallback trả về data url gốc nếu canvas gặp lỗi
            completer.complete(rawDataUrl);
          }
        });

        img.onError.listen((_) {
          completer.complete(rawDataUrl);
        });
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}

