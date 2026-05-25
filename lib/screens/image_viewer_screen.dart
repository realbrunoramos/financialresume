import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../theme/colors.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imagePath;

  const ImageViewerScreen({super.key, required this.imagePath});

  Future<void> _shareImage() async {
    final file = File(imagePath);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(imagePath)], text: 'Transaction Invoice');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).visualizarFatura),
        // Image viewer always uses a dark AppBar for immersive feel
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareImage,
            tooltip: 'Share',
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: FileImage(File(imagePath)),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        backgroundDecoration: const BoxDecoration(color: AppColors.dark),
      ),
    );
  }
}
