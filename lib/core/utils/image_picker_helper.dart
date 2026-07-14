import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// 从相册选择一张图片，返回字节（Web / 桌面均可用）
  static Future<Uint8List?> pickImageBytes() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}
