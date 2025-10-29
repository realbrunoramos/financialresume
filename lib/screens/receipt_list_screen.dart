import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import './image_viewer_screen.dart';
import '../theme/colors.dart';

class ReceiptListScreen extends StatelessWidget {
  final List<String> receiptPaths;

  const ReceiptListScreen({required this.receiptPaths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).faturaTransacao),
        backgroundColor: AppColors.white,
      ),
      body: receiptPaths.isEmpty
          ? Center(child: Text(AppLocalizations.of(context).noInvoiceAttached))
          : GridView.builder(
        padding: EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
        ),
        itemCount: receiptPaths.length,
        itemBuilder: (context, index) {
          final path = receiptPaths[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImageViewerScreen(imagePath: path),
                ),
              );
            },
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(child: Icon(Icons.error, color: AppColors.red));
              },
            ),
          );
        },
      ),
    );
  }
}