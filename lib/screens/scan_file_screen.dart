import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:financialresume/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as imge;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_service.dart';
import '../theme/colors.dart';

class TextBasedDocumentImageProcessor {
  final File _imageFile;
  late imge.Image? originalImage;
  late imge.Image? modifiedImage;
  imge.Image? finalImage;
  List<List<int>>? documentCorners;

  final TextRecognizer _textRecognizer = TextRecognizer();
  RecognizedText? _recognizedText;
  List<TextBlock> textGroup = [];

  final ImageBasedLightDetector _lightDetector = ImageBasedLightDetector();
  Map<String, dynamic> _lightAnalysis = {};

  TextBasedDocumentImageProcessor(this._imageFile);

  Future<void> initialize() async {
    try {
      final imageBytes = _imageFile.readAsBytesSync();
      originalImage = imge.decodeImage(imageBytes);
      if (originalImage == null || originalImage!.width <= 0 || originalImage!.height <= 0) {
        throw Exception('Imagem inválida: Não foi possível decodificar ou dimensões inválidas');
      }

      final lightCondition = await _lightDetector.analyzeImageBrightness(originalImage!);
      _lightAnalysis = _lightDetector.getDetailedAnalysis(originalImage!);

      print('🔍 Análise de Luminosidade:');
      print('   - Condição: $lightCondition');
      print('   - Brilho: ${_lightDetector.getCurrentBrightness().toStringAsFixed(3)}');
      print('   - Contraste: ${_lightAnalysis['contrast']?.toStringAsFixed(3)}');
      print('   - Recomendação: ${_lightAnalysis['recommended_enhancement']}');

      await _processImage();

      if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
        throw Exception('Nenhum documento detectado: Nenhum texto encontrado na imagem');
      }

      double? angle = await getMostFreqAngle();
      if (angle == null || angle == 0.0) {
        modifiedImage = originalImage;
      } else {
        modifiedImage = await rotateImage(originalImage!, angle);
        if (modifiedImage == null) {
          modifiedImage = originalImage;
        }
      }

      if (angle != null && angle != 0.0) {
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/rotated_${DateTime.now().millisecondsSinceEpoch}.jpg';
        File(tempPath).writeAsBytesSync(imge.encodeJpg(modifiedImage!));
        await _processImage(tempPath);
        if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
          throw Exception('Nenhum texto detectado na imagem rotacionada');
        }
        await getMostFreqAngle();
      }

      documentCorners = await _getDocumentCorners();

      if (documentCorners != null) {
        final croppedImage = await cropWithCustomCorners(documentCorners!);
        if (croppedImage != null) {
          modifiedImage = croppedImage;
        }
      }

      final imageToEnhance = modifiedImage ?? originalImage!;
      finalImage = _applyAdaptiveDocumentEnhancement(imageToEnhance, lightCondition);

      print('✅ Processamento adaptativo aplicado: $lightCondition');

    } catch (e) {
      rethrow;
    }
  }

  imge.Image applyManualFilter(imge.Image image, int filterChoice) {
    imge.Image filteredImage = imge.copyResize(image, width: image.width, height: image.height);

    switch (filterChoice) {
      case 0: // Original
        return filteredImage;

      case 1: // Very Dark Enhancement
        return imge.adjustColor(
          filteredImage,
          gamma: 0.6,
          contrast: 1.9,
          brightness: 1.5,
          saturation: 0.7,
        );

      case 2: // Dark Enhancement
        return imge.adjustColor(
          filteredImage,
          gamma: 0.7,
          contrast: 1.7,
          brightness: 1.3,
          saturation: 0.8,
        );

      case 3: // Normal Enhancement
        return imge.adjustColor(
          filteredImage,
          gamma: 0.8,
          contrast: 1.4,
          brightness: 1.1,
          saturation: 0.9,
        );

      case 4: // Bright Enhancement
        return imge.adjustColor(
          filteredImage,
          gamma: 0.9,
          contrast: 1.2,
          brightness: 0.9,
          saturation: 1.0,
        );

      case 5: // Very Bright Enhancement
        return imge.adjustColor(
          filteredImage,
          gamma: 1.0,
          contrast: 1.1,
          brightness: 0.8,
          saturation: 1.0,
        );

      default:
        return filteredImage;
    }
  }

  Future<File?> getProcessedImageWithFilter(int filterChoice) async {
    try {
      final imageToProcess = modifiedImage ?? originalImage;
      if (imageToProcess == null) return null;

      final filteredImage = applyManualFilter(imageToProcess, filterChoice);

      final tempDir = await getTemporaryDirectory();
      final filteredPath = '${tempDir.path}/filtered_${filterChoice}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(filteredPath).writeAsBytesSync(imge.encodeJpg(filteredImage));

      return File(filteredPath);
    } catch (e) {
      print('Erro ao aplicar filtro manual: $e');
      return null;
    }
  }

  imge.Image _applyAdaptiveDocumentEnhancement(imge.Image image, String lightCondition) {
    imge.Image enhancedImage = imge.copyResize(image, width: image.width, height: image.height);

    switch (lightCondition) {
      case 'very_dark':
        enhancedImage = imge.adjustColor(
          enhancedImage,
          contrast: 1.9,
          brightness: 1.5,
        );
        break;

      case 'dark':
        enhancedImage = imge.adjustColor(
          enhancedImage,
          contrast: 1.7,
          brightness: 1.5,
          saturation: -0.5,
        );
        break;

      case 'normal':
        enhancedImage = imge.adjustColor(
          enhancedImage,
          contrast: 1.4,
          brightness: 1.1,
          saturation: -0.5,
        );
        break;

      case 'bright':
        enhancedImage = imge.adjustColor(
          enhancedImage,
          contrast: 1.2,
          brightness: 1.0,
          saturation: -0.5,
        );
        break;

      case 'very_bright':
        enhancedImage = imge.adjustColor(
          enhancedImage,
          contrast: 1.1,
          brightness: 0.8,
          saturation: -0.5,
        );
        break;

      default:
        enhancedImage = imge.adjustColor(
          enhancedImage,
          contrast: 1.35,
          brightness: 1.15,
          saturation: -0.5,
        );
    }

    return enhancedImage;
  }

  Future<void> _processImage([String? imagePath]) async {
    try {
      final path = imagePath ?? _imageFile.path;
      final inputImage = InputImage.fromFilePath(path);
      _recognizedText = await _textRecognizer.processImage(inputImage);
    } catch (e) {
      _recognizedText = null;
    }
  }

  Future<double?> getMostFreqAngle() async {
    if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
      return null;
    }

    Map<double, int> angleFrequency = {};
    Map<double, List<TextBlock>> angleBlocks = {};

    for (TextBlock block in _recognizedText!.blocks) {
      if (block.cornerPoints.length >= 2) {
        final p1 = block.cornerPoints[0];
        final p2 = block.cornerPoints[1];
        double dx = (p2.x - p1.x).toDouble();
        double dy = (p2.y - p1.y).toDouble();
        double angle = math.atan2(dy, dx) * 180 / math.pi;

        if (angle > 90) angle -= 180;
        if (angle < -90) angle += 180;

        angle = (angle * 10).round() / 10.0;

        angleFrequency[angle] = (angleFrequency[angle] ?? 0) + 1;
        angleBlocks[angle] ??= [];
        angleBlocks[angle]!.add(block);
      }
    }

    if (angleFrequency.isEmpty) {
      return null;
    }

    double mostFreqAngle = angleFrequency.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    const angleTolerance = 5.0;
    textGroup = _recognizedText!.blocks.where((block) {
      if (block.cornerPoints.length < 2) return false;
      final p1 = block.cornerPoints[0];
      final p2 = block.cornerPoints[1];
      double dx = (p2.x - p1.x).toDouble();
      double dy = (p2.y - p1.y).toDouble();
      double angle = math.atan2(dy, dx) * 180 / math.pi;

      if (angle > 90) angle -= 180;
      if (angle < -90) angle += 180;
      angle = (angle * 10).round() / 10.0;

      return (angle - mostFreqAngle).abs() <= angleTolerance;
    }).toList();

    return mostFreqAngle;
  }

  Future<imge.Image?> rotateImage(imge.Image originalImg, double angleDegrees) async {
    try {
      final rotated = imge.copyRotate(originalImg, angle: -angleDegrees);
      if (rotated.width <= 0 || rotated.height <= 0) {
        return null;
      }
      return rotated;
    } catch (e) {
      return null;
    }
  }

  Future<List<List<int>>?> _getDocumentCorners() async {
    if (textGroup.isEmpty) {
      return null;
    }

    int minX = textGroup[0].cornerPoints[0].x;
    int maxX = minX;
    int minY = textGroup[0].cornerPoints[0].y;
    int maxY = minY;

    for (var block in textGroup) {
      for (var point in block.cornerPoints) {
        minX = math.min(minX, point.x);
        maxX = math.max(maxX, point.x);
        minY = math.min(minY, point.y);
        maxY = math.max(maxY, point.y);
      }
    }

    const margin = 20;
    minX = math.max(0, minX - margin);
    maxX = math.min(modifiedImage!.width, maxX + margin);
    minY = math.max(0, minY - margin);
    maxY = math.min(modifiedImage!.height, maxY + margin);

    return [
      [minX, minY],
      [maxX, minY],
      [maxX, maxY],
      [minX, maxY],
    ];
  }

  Future<List<int>?> _getMinMaxCoordinates(List<List<int>> customCorners) async{
    if (customCorners.length != 4) {
      return null;
    }
    if (modifiedImage == null) {
      return null;
    }

    final imageWidth = modifiedImage!.width;
    final imageHeight = modifiedImage!.height;

    for (var corner in customCorners) {
      if (corner.length != 2) {
        return null;
      }
      final x = corner[0];
      final y = corner[1];
      if (x < 0 || x >= imageWidth || y < 0 || y >= imageHeight) {
        return null;
      }
    }

    final minX = customCorners.map((c) => c[0]).reduce(math.min);
    final maxX = customCorners.map((c) => c[0]).reduce(math.max);
    final minY = customCorners.map((c) => c[1]).reduce(math.min);
    final maxY = customCorners.map((c) => c[1]).reduce(math.max);

    return [minX, maxX, minY, maxY];
  }

  Future<List<int>?> getPreviewMinMax(InputImage inputImage) async {
    try {
      _recognizedText = await _textRecognizer.processImage(inputImage);
      if (_recognizedText == null || _recognizedText!.blocks.isEmpty) {
        return null;
      }

      if (textGroup.isEmpty) {
        return null;
      }

      final imageSize = inputImage.metadata!.size;
      int minX = textGroup[0].cornerPoints[0].x;
      int maxX = minX;
      int minY = textGroup[0].cornerPoints[0].y;
      int maxY = minY;

      for (var block in textGroup) {
        for (var point in block.cornerPoints) {
          minX = math.min(minX, point.x);
          maxX = math.max(maxX, point.x);
          minY = math.min(minY, point.y);
          maxY = math.max(maxY, point.y);
        }
      }

      const margin = 20;
      minX = math.max(0, minX - margin);
      maxX = math.min(imageSize.width.toInt(), maxX + margin);
      minY = math.max(0, minY - margin);
      maxY = math.min(imageSize.height.toInt(), maxY + margin);

      return [minX, maxX, minY, maxY];
    } catch (e) {
      return null;
    }
  }

  Future<imge.Image?> cropWithCustomCorners(List<List<int>> customCorners) async {
    try {
      List<int>? coordinates = await _getMinMaxCoordinates(customCorners);

      int minX = 0;
      int maxX = 0;
      int minY = 0;
      int maxY = 0;
      if (coordinates == null) {
        return null;
      } else {
        minX = coordinates[0];
        maxX = coordinates[1];
        minY = coordinates[2];
        maxY = coordinates[3];
      }
      final cropWidth = maxX - minX;
      final cropHeight = maxY - minY;

      if (cropWidth <= 0 || cropHeight <= 0) {
        return null;
      }

      final croppedImage = imge.copyCrop(
        modifiedImage!,
        x: minX,
        y: minY,
        width: cropWidth,
        height: cropHeight,
      );

      if (croppedImage.width <= 0 || croppedImage.height <= 0) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final debugPath = '${tempDir.path}/debug_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(debugPath).writeAsBytesSync(imge.encodeJpg(croppedImage));

      return croppedImage;
    } catch (e) {
      return null;
    }
  }

  Future<imge.Image?> cropWithCorners(List<List<double>> corners) async {
    try {
      if (corners.length != 4) {
        return null;
      }
      if (originalImage == null) {
        return null;
      }

      final intCorners = corners.map((c) => [c[0].round(), c[1].round()]).toList();
      return await cropWithCustomCorners(intCorners.cast<List<int>>());
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> get lightAnalysis => _lightAnalysis;

  void dispose() {
    _textRecognizer.close();
    _lightDetector.dispose();
  }
}

class ImageBasedLightDetector {
  double _currentBrightness = 0.5;
  String _currentCondition = 'normal';

  Future<String> analyzeImageBrightness(imge.Image image) async {
    try {
      final brightness = _calculateImageBrightness(image);
      _currentBrightness = brightness;

      if (brightness < 0.05) {
        _currentCondition = 'very_dark';
      } else if (brightness < 0.1) {
        _currentCondition = 'dark';
      } else if (brightness < 0.4) {
        _currentCondition = 'normal';
      } else if (brightness < 0.7) {
        _currentCondition = 'bright';
      } else {
        _currentCondition = 'very_bright';
      }

      return _currentCondition;
    } catch (e) {
      _currentCondition = 'normal';
      _currentBrightness = 0.5;
      return _currentCondition;
    }
  }

  double _calculateImageBrightness(imge.Image image) {
    int totalPixels = 0;
    double sumBrightness = 0;

    final sampleRate = math.max(1, (image.width * image.height) ~/ 1000);

    for (int y = 0; y < image.height; y += sampleRate) {
      for (int x = 0; x < image.width; x += sampleRate) {
        if (x < image.width && y < image.height) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r / 255.0;
          final g = pixel.g / 255.0;
          final b = pixel.b / 255.0;

          final brightness = (r * 0.2126 + g * 0.7152 + b * 0.0722);
          sumBrightness += brightness;
          totalPixels++;
        }
      }
    }

    return totalPixels > 0 ? sumBrightness / totalPixels : 0.5;
  }

  Map<String, dynamic> getDetailedAnalysis(imge.Image image) {
    final brightness = _currentBrightness;
    final condition = _currentCondition;

    double contrastLevel = _estimateContrast(image);

    return {
      'brightness': brightness,
      'condition': condition,
      'contrast': contrastLevel,
      'recommended_enhancement': _getRecommendedEnhancement(brightness, contrastLevel),
    };
  }

  double _estimateContrast(imge.Image image) {
    final List<double> samples = [];
    final sampleSize = 100;

    for (int i = 0; i < sampleSize; i++) {
      final x = math.Random().nextInt(image.width);
      final y = math.Random().nextInt(image.height);
      final pixel = image.getPixel(x, y);
      final brightness = (pixel.r * 0.2126 +
          pixel.g * 0.7152 +
          pixel.b * 0.0722) / 255.0;
      samples.add(brightness);
    }

    samples.sort();
    final minBrightness = samples.first;
    final maxBrightness = samples.last;

    return maxBrightness - minBrightness;
  }

  String _getRecommendedEnhancement(double brightness, double contrast) {
    if (brightness < 0.3 && contrast < 0.3) return 'high_enhancement';
    if (brightness < 0.4 && contrast < 0.4) return 'medium_enhancement';
    if (brightness > 0.8 && contrast < 0.2) return 'reduce_brightness';
    return 'balanced_enhancement';
  }

  double getCurrentLux() => _currentBrightness * 1000;
  String getLightCondition() => _currentCondition;
  double getCurrentBrightness() => _currentBrightness;

  void dispose() {
  }
}

class ScanFileScreen extends StatefulWidget {
  final sectionId;
  const ScanFileScreen({super.key, required this.sectionId});

  @override
  State<ScanFileScreen> createState() => _ScanFileScreenState();
}

class _ScanFileScreenState extends State<ScanFileScreen> {
  final DatabaseService dbService = DatabaseService();
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  String? _processedImagePath;
  bool _isProcessing = false;
  TextBasedDocumentImageProcessor? _processor;
  Map<String, dynamic>? _aiAnalysis;
  bool _isAnalyzingAI = false;
  final ImagePicker _picker = ImagePicker();
  bool _showScanAnimation = false;
  double _scanPosition = 0.0;
  late Timer _scanTimer;
  int _selectedFilter = -1; // -1 = automático, 0-5 = filtros manuais
  bool _showFilterOptions = false;
  List<String> _filterOptions = [
    'Automático',
    'Muito Escuro',
    'Escuro',
    'Normal',
    'Claro',
    'Muito Claro',
    'Original'
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _showScanAnimation = true;

    _scanTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_showScanAnimation) {
        setState(() {
          _scanPosition += 5;
          final screenHeight = MediaQuery.of(context).size.height;
          if (_scanPosition > screenHeight * 2) {
            _scanPosition = 0.0;
          }
        });
      }
    });
  }
  Future<void> _applyManualFilter(int filterIndex) async {
    if (_processor == null) return;

    setState(() {
      _selectedFilter = filterIndex;
      _isProcessing = true;
    });

    try {
      final filteredFile = await _processor!.getProcessedImageWithFilter(filterIndex);
      if (filteredFile != null && mounted) {
        setState(() {
          _processedImagePath = filteredFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aplicar filtro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Método para alternar visibilidade das opções de filtro
  void _toggleFilterOptions() {
    setState(() {
      _showFilterOptions = !_showFilterOptions;
    });
  }

  // Widget para os botões de filtro circulares
  Widget _buildFilterSelector() {
    if (!_showFilterOptions || _processedImagePath == null) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'Selecionar Filtro',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(7, (index) {
                return _buildFilterButton(index);
              }),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _toggleFilterOptions,
              child: Text(
                'Fechar',
                style: TextStyle(color: AppColors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para cada botão de filtro circular
  Widget _buildFilterButton(int filterIndex) {
    final bool isSelected = _selectedFilter == filterIndex;
    final String label = _filterOptions[filterIndex];

    Color buttonColor;
    switch (filterIndex) {
      case 0: buttonColor = AppColors.green; break; // Automático
      case 1: buttonColor = Colors.grey[900]!; break; // Muito Escuro
      case 2: buttonColor = Colors.grey[700]!; break; // Escuro
      case 3: buttonColor = Colors.grey[500]!; break; // Normal
      case 4: buttonColor = Colors.grey[300]!; break; // Claro
      case 5: buttonColor = Colors.grey[100]!; break; // Muito Claro
      case 6: buttonColor = AppColors.white; break; // Original
      default: buttonColor = AppColors.grey;
    }

    return GestureDetector(
      onTap: () => _applyManualFilter(filterIndex),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.green : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                filterIndex == 0 ? 'A' : (filterIndex == 6 ? 'O' : filterIndex.toString()),
                style: TextStyle(
                  color: filterIndex >= 4 ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: filterIndex == 0 || filterIndex == 6 ? 14 : 16,
                ),
              ),
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // Botão para abrir/fechar opções de filtro
  Widget _buildFilterToggleButton() {
    if (_processedImagePath == null) return SizedBox.shrink();

    return Positioned(
      top: 50,
      right: 20,
      child: FloatingActionButton(
        onPressed: _toggleFilterOptions,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.dark,
        mini: true,
        child: Icon(
          _showFilterOptions ? Icons.close : Icons.filter_alt,
          size: 20,
        ),
      ),
    );
  }

  // Indicador do filtro atual
  Widget _buildCurrentFilterIndicator() {
    if (_processedImagePath == null || _selectedFilter == -1) {
      return SizedBox.shrink();
    }

    return Positioned(
      top: 50,
      left: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Filtro: ${_filterOptions[_selectedFilter]}',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      _controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
      );
      _initializeControllerFuture = _controller!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao inicializar câmera: $e')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      setState(() {
        _capturedImage = image;
      });
      await _processCapturedImage(_capturedImage!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar imagem: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _capturedImage = pickedFile;
        });
        await _processCapturedImage(_capturedImage!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<void> _confirm() async {
    if (_capturedImage == null || _isProcessing || _isAnalyzingAI) return;

    await _analyzeWithAI();

    if (mounted) {
      Navigator.pop(context, {
        'imagePath': _processedImagePath,
        'aiAnalysis': _aiAnalysis,
      });
    }
  }

  Future<void> _processCapturedImage(XFile imageFile) async {
    setState(() {
      _isProcessing = true;
      _showScanAnimation = true;
      _selectedFilter = -1;
      _scanPosition = 0.0;
    });

    try {
      final imagePath = imageFile.path;
      final imageFileObj = File(imagePath);
      _processor = TextBasedDocumentImageProcessor(imageFileObj);
      await _processor!.initialize();

      if (_processor!.finalImage != null) {
        final tempDir = await getTemporaryDirectory();
        final processedPath = '${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        File(processedPath).writeAsBytesSync(imge.encodeJpg(_processor!.finalImage!));

        if (mounted) {
          setState(() {
            _processedImagePath = processedPath;
          });
        }
      } else {
        throw Exception('Falha no processamento da imagem - finalImage é null');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no processamento: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _showScanAnimation = false;
        });
      }
      _processor?.dispose();
    }
  }

  Future<void> _analyzeWithAI() async {

    StringBuffer invoicesString = StringBuffer();
    List<Transaction> invoices = await dbService.getNoPaidInvoices(widget.sectionId);
    for (var invoice in invoices) {
      invoicesString.write("id: ${invoice.id} -> entidade: ${invoice.entity}, valor: ${invoice.amount}, refMesAno: ${invoice.monthRef}\n");
    }

    if (_processedImagePath == null || _isAnalyzingAI) return;

    setState(() {
      _isAnalyzingAI = true;
    });

    try {
      final imageFile = File(_processedImagePath!);
      final imageBytes = await imageFile.readAsBytes();
      final imageBase64 = base64Encode(imageBytes);

      String apiKey = "AIzaSyABII33nClj-Qu3oqZAiQQgOEpkZtY4PHo";
      Uri url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');

      final prompt = """Recebeste uma imagem de um documento financeiro (ex.: fatura, recibo, comprovativo de pagamento).
Deves extrair informações e responder **APENAS** com um objeto JSON de linha única no formato seguinte, sem explicações adicionais e sem texto fora do JSON:

{
  "tipo_documento": <número do documento da lista abaixo>,
  "entidade": "string | UNKNOWN",
  "data_emissao": "dd mm yyyy | UNKNOWN",
  "valor_total": "string numérica (ex.: '23.45')" | "UNKNOWN",
  "data_limite": "dd mm yyyy" | "UNKNOWN",
  "é_crédito": "0" | "1" | "UNKNOWN",
  "mes_ano_ref": "mm/yyyy" | "UNKNOWN",
  "descrição": "string | UNKNOWN",
  "ids_ref_fatura": "string | UNKNOWN"
}

### Lista de tipos de documento:
1 = Comprovativo de Compra (talão ou fatura de loja)
2 = Fatura ou Nota de Cobrança (emitida por empresa ou prestador de serviços)
3 = Comprovativo de Pagamento (ex.: multibanco, transferência, recibo de pagamento)
4 = Outro (não identificado)

### Regras obrigatórias:
1. O campo "tipo_documento" deve ser **apenas o número** correspondente da lista acima.
2. "entidade" deve conter o nome da loja, empresa ou instituição identificada no documento (Ao menos que seja mesmo o nome da entidade, não deve conter mais que uma palavra. Sem subtítulos, nem adicionais). Se não for possível determinar, usar "UNKNOWN".
3. A "data_emissao" deve estar no formato exacto "dd mm yyyy" (com zeros à esquerda). Se não houver data clara, usar "UNKNOWN".
4. O "valor_total" deve representar o montante total pago ou a pagar, apenas o número (com ponto decimal). Se não identificado, usar "UNKNOWN".
5. "data_limite" deve ser incluída apenas para tipo 2 (Nota de Cobrança), no formato "dd mm yyyy". Caso contrário, "UNKNOWN".
6. Nunca escrever texto adicional, explicações, metadados, arrays, múltiplos objetos ou JSON inválido. Apenas um único objeto JSON válido numa linha.
7. Se o documento não corresponder a nenhum dos três tipos principais, definir "tipo_documento" como 4 (Outro).
8. Caso múltiplos documentos sejam visíveis, considera apenas o que ocupa a maior área na imagem.
9. Em caso de transferência ou Pagamento por Multibanco, o nome da entidade deve ser o nome que está atribuído ao nome do destinatário.
10. Em caso de comprovativo e nota de cobrança, deve incluir também o mês e o ano da referência que o valor foi atribuído.
11. O argumento 'é_crédito' tem valor de '0' se não for crédito e '1' se for crédito.
12. Analisa a imagem de um talão, fatura ou comprovativo de pagamento.
Identifica o tipo de compra ou o contexto geral da despesa, mas não descrevas produtos individuais, valores ou detalhes específicos.
O objetivo é produzir uma descrição curta (até 7 palavras), que resuma de forma genérica e natural o tipo de gasto realizado.
Exemplos:
-Supermercado com alimentos e produtos de higiene → "Compras para a casa";
-Restaurante ou bar → "Refeição fora de casa";
-Comprovativo de transferência de um terceiro → "Transferência de dinheiro de <nome do remetente>";
-Farmácia ou parafarmácia → "Produtos de saúde";
-Talão de supermercado de animais → "Produtos para animais de estimação";
-Recibo de hotel → "Alojamento e estadia";
-Talão de combustível → "Combustível e transporte".
13. No parâmetro "ids_ref_fatura" deve conter ids de faturas que pareça ser condizente com o comprovativo em questão. Se houver
alguma fatura que tenha a mesma referência de mês e ano (monthRef/mes_ano_ref), mesmo valor e nome de entidade condizente com o comprovativo, adicione ao parâmetro
apenas o id dessa fatura. Se as faturas apenas tiverem entidade e/ou valor condizente, adiciona o id dessa(s) fatura(s). 
Aqui estão as faturas reais para analizar:
${invoicesString.toString()}

### Exemplos de saída válida:
{"tipo_documento":1,"entidade":"Continente","data_emissao":"05 10 2025","valor_total":"23.45","descrição":"Compras para a casa"}
{"tipo_documento":2,"entidade":"EDP Comercial","data_emissao":"01 09 2025","valor_total":"65.90","descrição":"Fatura de Energia (EDP) de setembro","data_limite":"30 09 2025","mes_ano_ref":"09/2025"}
{"tipo_documento":3,"entidade":"CASA PIA","data_emissao":"03 10 2025","valor_total":"25.00","descrição":"Pagamento do serviço casa PIA","mes_ano_ref":"10/2025","é_crédito":"0","ids_ref_fatura":"2025-10-02 12:07:37.790990,2025-10-01 10:07:37.865099"}
{"tipo_documento":3,"entidade":"Diogo","data_emissao":"07 10 2025","valor_total":"500.00","descrição":"Transferencia de Diogo","mes_ano_ref":"10/2025","é_crédito":"1","ids_ref_fatura":''""";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inlineData': {
                    'mimeType': 'image/jpeg',
                    'data': imageBase64
                  }
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['candidates'][0]['content']['parts'][0]['text'];

        final jsonMatch = RegExp(r'\{.*\}').firstMatch(content);
        if (jsonMatch != null) {
          final aiResult = jsonDecode(jsonMatch.group(0)!);
          if (mounted) {
            setState(() {
              _aiAnalysis = aiResult;
            });
          }
        } else {

        }
      } else {

      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na análise IA: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingAI = false;
        });
      }
    }
  }

  Future<void> _retryCapture() async {
    setState(() {
      _capturedImage = null;
      _processedImagePath = null;
      _aiAnalysis = null;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _processor?.dispose();
    _scanTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        title: Text('Escanear'),
        backgroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _controller == null || _initializeControllerFuture == null
                ? Center(child: CircularProgressIndicator(color: AppColors.white))
                : FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (_processedImagePath != null) {
                    return Center(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagem processada
                          Image.file(
                            File(_processedImagePath!),
                            fit: BoxFit.contain,
                          ),

                          // Animação de scan
                          if (_showScanAnimation)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: _scanPosition,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.green,
                                      AppColors.green,
                                      Colors.transparent,
                                    ],
                                    stops: [0.0, 0.3, 0.7, 1.0],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.green.withAlpha(200),
                                      blurRadius: 10,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Indicador do filtro atual
                          _buildCurrentFilterIndicator(),

                          // Seletor de filtros
                          _buildFilterSelector(),

                          // Botão toggle de filtros
                          _buildFilterToggleButton(),

                          // Botões de ação inferiores
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Botão Repetir
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: TextButton(
                                      onPressed: _retryCapture,
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.all(AppColors.white),
                                        foregroundColor: WidgetStateProperty.all(AppColors.dark),
                                        fixedSize: WidgetStateProperty.all(Size(50, 50)),
                                      ),
                                      child: Icon(Icons.repeat),
                                    ),
                                  ),
                                  // Botão Confirmar
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: TextButton(
                                      onPressed: (_isProcessing || _isAnalyzingAI) ? null : _confirm,
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.all(
                                            (_isProcessing || _isAnalyzingAI) ? AppColors.grey : AppColors.green
                                        ),
                                        foregroundColor: WidgetStateProperty.all(AppColors.white),
                                        fixedSize: WidgetStateProperty.all(Size(50, 50)),
                                      ),
                                      child: _isAnalyzingAI
                                          ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                                        ),
                                      )
                                          : Icon(Icons.check),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (_capturedImage != null) {
                    return Center(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagem capturada
                          Image.file(
                            File(_capturedImage!.path),
                            fit: BoxFit.contain,
                          ),

                          // Animação de scan durante processamento
                          if (_showScanAnimation)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: _scanPosition.clamp(0.0, MediaQuery.of(context).size.height),
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      AppColors.green.withAlpha(200),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.green.withAlpha(200),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Overlay de processamento (opcional)
                          if (_isProcessing)
                            Container(
                              color: Colors.black.withOpacity(0.3),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: AppColors.white),
                                    SizedBox(height: 16),
                                    Text(
                                      'Processando imagem...',
                                      style: TextStyle(color: AppColors.white, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Botões de ação inferiores
                          Positioned(
                            bottom: 20,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Botão Repetir
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: TextButton(
                                      onPressed: _retryCapture,
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.all(AppColors.white),
                                        foregroundColor: WidgetStateProperty.all(AppColors.dark),
                                        fixedSize: WidgetStateProperty.all(Size(50, 50)),
                                      ),
                                      child: Icon(Icons.repeat),
                                    ),
                                  ),
                                  // Botão Confirmar
                                  Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: TextButton(
                                      onPressed: _isProcessing ? null : _confirm,
                                      style: ButtonStyle(
                                        backgroundColor: WidgetStateProperty.all(
                                            _isProcessing ? AppColors.grey : AppColors.green
                                        ),
                                        foregroundColor: WidgetStateProperty.all(AppColors.white),
                                        fixedSize: WidgetStateProperty.all(Size(50, 50)),
                                      ),
                                      child: Icon(Icons.check),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Tela da câmera
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Preview da câmera
                        CameraPreview(_controller!),

                        // Botão de captura central
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: SizedBox(
                                width: 80,
                                height: 80,
                                child: FloatingActionButton(
                                  onPressed: _takePicture,
                                  backgroundColor: AppColors.white,
                                  foregroundColor: AppColors.dark,
                                  child: Icon(Icons.camera_alt, size: 30),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Botão da galeria
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: FloatingActionButton(
                            onPressed: _pickFromGallery,
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.dark,
                            mini: true,
                            child: Icon(Icons.photo_library, size: 24),
                          ),
                        ),
                      ],
                    );
                  }
                } else {
                  return Center(child: CircularProgressIndicator(color: AppColors.white));
                }
              },
            ),
          ),
        ],
      ),
    );
  }


}