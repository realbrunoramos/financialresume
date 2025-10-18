import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class FileService {
  Future<String> saveImage(File image, {bool binarize = false}) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer();
    final recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    // Get text block coordinates for corner detection
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    double totalAngle = 0;
    int blockCount = 0;

    for (var block in recognizedText.blocks) {
      final rect = block.boundingBox;
      minX = min(minX, rect.left.toDouble());
      minY = min(minY, rect.top.toDouble());
      maxX = max(maxX, rect.right.toDouble());
      maxY = max(maxY, rect.bottom.toDouble());

      // Calculate rotation angle from corner points
      if (block.cornerPoints.isNotEmpty) {
        final p1 = block.cornerPoints[0];
        final p2 = block.cornerPoints[1];
        final deltaY = p2.y - p1.y;
        final deltaX = p2.x - p1.x;
        final angle = atan2(deltaY, deltaX) * 180 / pi;
        totalAngle += angle;
        blockCount++;
      }
    }

    final avgAngle = blockCount > 0 ? totalAngle / blockCount : 0;

    // Load and process image
    final imageBytes = await image.readAsBytes();
    img.Image? processedImage = img.decodeImage(imageBytes);

    if (processedImage != null) {
      // Ensure crop dimensions are valid
      int cropWidth = (maxX - minX).toInt();
      int cropHeight = (maxY - minY).toInt();
      int cropX = minX.toInt();
      int cropY = minY.toInt();

      // Adjust crop dimensions to stay within image bounds
      cropX = cropX.clamp(0, processedImage.width - 1);
      //cropwards: cropY = cropY.clamp(0, processedImage.height - 1);
      cropWidth = cropWidth.clamp(1, processedImage.width - cropX);
      cropHeight = cropHeight.clamp(1, processedImage.height - cropY);

      // Rotate image to correct angle
      if (avgAngle != 0) {
        processedImage = img.copyRotate(processedImage, angle: -avgAngle);
      }

      // Crop to document boundaries
      if (minX != double.infinity && maxX != -double.infinity) {
        try {
          processedImage = img.copyCrop(
            processedImage,
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight,
          );
        } catch (e) {
          // Fallback to original image if cropping fails
          processedImage = img.decodeImage(imageBytes);
        }
      }

      // Apply binarization if requested
      if (binarize) {
        try {
          processedImage = img.grayscale(processedImage!);
          processedImage = img.adjustColor(
            processedImage,
            contrast: 1.5,
            brightness: 0.0,
            gamma: 1.0,
          );
        } catch (e) {
          // Fallback to original image if binarization fails
          processedImage = img.decodeImage(imageBytes);
        }
      }

      // Save processed image
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/receipts');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${imageDir.path}/$fileName';
      final processedFile = File(path);
      await processedFile.writeAsBytes(img.encodeJpg(processedImage!));
      return path;
    }

    // Fallback to original image if processing fails
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/receipts');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '${imageDir.path}/$fileName';
    await image.copy(path);
    return path;
  }

  Future<void> downloadImage(String path) async {
    if (await Permission.storage.request().isGranted) {
      final downloadsDir = await getExternalStorageDirectory();
      final fileName = path.split('/').last;
      final newPath = '${downloadsDir!.path}/$fileName';
      await File(path).copy(newPath);
    }
  }
}