import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import './image_viewer_screen.dart';
import '../theme/colors.dart';
import '../theme/app_tokens.dart';

class ReceiptListScreen extends StatelessWidget {
  final List<String> receiptPaths;

  const ReceiptListScreen({super.key, required this.receiptPaths});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: Text(l.faturaTransacao),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
        foregroundColor: isDark ? AppColors.darkText : AppColors.dark,
        elevation: 0,
      ),
      body: receiptPaths.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: isDark ? AppColors.darkSubtext : AppColors.grey300,
                  ),
                  const SizedBox(height: AppTokens.sp16),
                  Text(
                    l.noInvoiceAttached,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.grey500,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppTokens.sp16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppTokens.sp12,
                mainAxisSpacing: AppTokens.sp12,
                childAspectRatio: 1,
              ),
              itemCount: receiptPaths.length,
              itemBuilder: (context, index) {
                final path = receiptPaths[index];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    slideRoute(ImageViewerScreen(imagePath: path)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTokens.radius12),
                    child: Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.grey100,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: isDark
                              ? AppColors.darkSubtext
                              : AppColors.grey400,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
