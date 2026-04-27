import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class ModelService {
  Interpreter? _interpreter;
  late List<int> _inputShape;
  late List<int> _outputShape;

  final List<String> classNames = [
    'pothole',
    'waterlogging',
    'open manhole',
  ];

  static const double _confidenceThreshold = 0.25; // ✅ Fixed: pre-filter threshold
  static const double _nmsThreshold = 0.45;

  /// Loads the TFLite model. Safe to call multiple times.
  Future<void> loadModel() async {
    if (_interpreter != null) return; // ✅ Fixed: guard against double init
    _interpreter = await Interpreter.fromAsset(
      'assets/models/best_float32.tflite',
      options: InterpreterOptions()..threads = 4,
    );
    _inputShape = _interpreter!.getInputTensor(0).shape;
    _outputShape = _interpreter!.getOutputTensor(0).shape;

    // ✅ Fixed: assert class count matches model output
    final int numClasses = _outputShape[1] - 4;
    assert(
    numClasses == classNames.length,
    'Model has $numClasses classes but classNames has ${classNames.length}',
    );

    debugPrint('Model input shape: $_inputShape'); // ✅ Fixed: debugPrint
    debugPrint('Model output shape: $_outputShape');
  }

  /// Releases native interpreter memory. Call when done with the service.
  void dispose() {
    // ✅ Fixed: dispose interpreter to prevent memory leaks
    _interpreter?.close();
    _interpreter = null;
  }

  static Float32List _preprocessChannelsLast(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Cannot decode image bytes');
    image = img.copyResize(image, width: 640, height: 640);

    final Float32List input = Float32List(640 * 640 * 3);
    int idx = 0;
    for (int y = 0; y < 640; y++) {
      for (int x = 0; x < 640; x++) {
        final pixel = image.getPixel(x, y);
        input[idx++] = pixel.r / 255.0;
        input[idx++] = pixel.g / 255.0;
        input[idx++] = pixel.b / 255.0;
      }
    }
    return input;
  }

  static Float32List _preprocessChannelsFirst(Uint8List imageBytes) {
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Cannot decode image bytes');
    image = img.copyResize(image, width: 640, height: 640);

    final Float32List input = Float32List(3 * 640 * 640);
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < 640; y++) {
        for (int x = 0; x < 640; x++) {
          final pixel = image.getPixel(x, y);
          final int idx = c * 640 * 640 + y * 640 + x;
          if (c == 0) {
            input[idx] = pixel.r / 255.0;
          } else if (c == 1) {
            input[idx] = pixel.g / 255.0;
          } else {
            input[idx] = pixel.b / 255.0;
          }
        }
      }
    }
    return input;
  }

  /// Auto-calculates severity based on confidence + hazard type.
  static String getSeverity(String hazard, double confidence) {
    // ✅ Fixed: static method
    final h = hazard.toLowerCase();
    if (confidence >= 0.75) return 'critical';
    if (confidence >= 0.50) {
      if (h.contains('manhole') || h.contains('water')) return 'critical';
      return 'high';
    }
    if (confidence >= 0.30) return 'medium';
    return 'low';
  }

  Future<Map<String, dynamic>> runModel(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw StateError('Model not loaded. Call loadModel() before runModel().');
    }

    final bool isChannelsFirst = _inputShape[1] == 3;

    final Float32List input = await Isolate.run(
          () => isChannelsFirst
          ? _preprocessChannelsFirst(imageBytes)
          : _preprocessChannelsLast(imageBytes),
    );

    final int numBoxes = _outputShape[2];
    final int numChannels = _outputShape[1];
    final int numClasses = numChannels - 4;

    final List<List<List<double>>> output = List.generate(
      1,
          (_) => List.generate(numChannels, (_) => List.filled(numBoxes, 0.0)),
    );

    _interpreter!.runForMultipleInputs(
      [
        isChannelsFirst
            ? input.reshape([1, 3, 640, 640])
            : input.reshape([1, 640, 640, 3])
      ],
      {0: output},
    );

    final List<List<double>> result = output[0];

    // ✅ Fixed: apply confidence threshold + simple NMS (best-box selection)
    double maxConf = 0;
    int maxClass = 0;
    double bestX = 0, bestY = 0, bestW = 0, bestH = 0;

    for (int i = 0; i < numBoxes; i++) {
      for (int c = 0; c < numClasses; c++) {
        final double classConf = result[4 + c][i];
        if (classConf < _confidenceThreshold) continue; // ✅ pre-filter
        if (classConf > maxConf) {
          maxConf = classConf;
          maxClass = c;
          bestX = result[0][i];
          bestY = result[1][i];
          bestW = result[2][i];
          bestH = result[3][i];
        }
      }
    }

    if (maxConf == 0) {
      return {
        'hazard': 'none',
        'confidence': 0.0,
        'severity': 'low',
        'bbox': null,
      };
    }

    final String hazardName = maxClass < classNames.length
        ? classNames[maxClass]
        : 'unknown (class $maxClass)';

    final String severity = getSeverity(hazardName, maxConf);

    debugPrint('Detected: $hazardName | Confidence: $maxConf | Severity: $severity');

    return {
      'hazard': hazardName,
      'confidence': maxConf,
      'severity': severity,
      'bbox': [bestX, bestY, bestW, bestH],
    };
  }
}