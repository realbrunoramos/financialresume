# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google ML Kit (CRÍTICO - resolve o erro principal)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }

# Google ML Kit Text Recognition (ESPECÍFICO para o erro)
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# Dependências principais do seu pubspec.yaml
-keep class androidx.camera.** { *; }
-keep class com.tekartik.sqflite.** { *; }
-keep class com.example.path_provider.** { *; }
-keep class com.example.image_picker.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }
-keep class com.techly.pdf.** { *; }
-keep class com.example.open_file.** { *; }
-keep class io.github.ponnamkarthik.photoview.** { *; }
-keep class io.flutter.plugins.share.** { *; }
-keep class com.example.image.** { *; }
-keep class com.example.uuid.** { *; }
-keep class com.google.ai.generativeai.** { *; }
-keep class com.example.shared_preferences_android.** { *; }
-keep class com.example.mailer.** { *; }
-keep class io.github.x_wei.flutter_google_fonts.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.example.timezone.** { *; }
-keep class com.example.package_info_plus.** { *; }
-keep class com.example.flutter_svg.** { *; }
-keep class com.caverock.androidsvg.** { *; }

# Para evitar warnings
-dontwarn com.google.**
-dontwarn androidx.**
-dontwarn org.sqlite.**
-dontwarn javax.imageio.**
-dontwarn org.pdfclown.**
-dontwarn com.caverock.**
-dontwarn net.nfet.**
-dontwarn com.baseflow.**