import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_embedder/flutter_embedder.dart';
import 'package:path_provider/path_provider.dart';

class TarjetaResultado {
  final int indice;
  final Map<String, dynamic> enriquecimiento;
  final double score; // cosine similarity en [-1, 1], en práctica [0, 1]

  TarjetaResultado({
    required this.indice,
    required this.enriquecimiento,
    required this.score,
  });

  @override
  String toString() =>
      'TarjetaResultado(idx=$indice, score=${score.toStringAsFixed(4)}, '
      'enriq=${enriquecimiento.toString().substring(0, enriquecimiento.toString().length.clamp(0, 80))}...)';
}

class BusquedaService {
  final GemmaEmbedder _embedder;
  final List<List<double>> _vectores;
  final List<Map<String, dynamic>> _enriquecimientos;
  final int _dim;

  BusquedaService._({
    required GemmaEmbedder embedder,
    required List<List<double>> vectores,
    required List<Map<String, dynamic>> enriquecimientos,
  })  : _embedder = embedder,
        _vectores = vectores,
        _enriquecimientos = enriquecimientos,
        _dim = vectores.first.length;

  /// Carga modelo, tokenizer, vectores y enriquecimientos. Llamar UNA vez al iniciar.
  static Future<BusquedaService> crear() async {
    await initFlutterEmbedder();

    // 1. Copiar assets (reusa los del smoke test si ya existen)
    final modelPath =
        await _copyAsset('assets/models/model_quantized.onnx');
    await _copyAsset('assets/models/model_quantized.onnx_data');
    final tokenizerPath =
        await _copyAsset('assets/models/tokenizer.json');

    final embedder = GemmaEmbedder.create(
      modelPath: modelPath,
      tokenizerPath: tokenizerPath,
    );

    // 2. Cargar vectores
    final vectoresRaw =
        await rootBundle.loadString('assets/data/vectors.json');
    final vectoresJson = jsonDecode(vectoresRaw) as List;
    final vectores = vectoresJson
        .map((v) =>
            (v as List).cast<num>().map((n) => n.toDouble()).toList(growable: false))
        .toList(growable: false);

    // 3. Cargar enriquecimientos
    final enriqRaw =
        await rootBundle.loadString('assets/data/enriquecimientos.json');
    final enriqJson = jsonDecode(enriqRaw) as List;
    final enriquecimientos = enriqJson
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    // 4. Validar paridad de corpus
    if (vectores.length != enriquecimientos.length) {
      throw StateError(
        'Mismatch: ${vectores.length} vectores vs ${enriquecimientos.length} enriquecimientos',
      );
    }

    return BusquedaService._(
      embedder: embedder,
      vectores: vectores,
      enriquecimientos: enriquecimientos,
    );
  }

  /// Embebe la query y devuelve top-K enriquecimientos por cosine similarity.
  /// Asume que los vectores del corpus están L2-normalizados y que Gemma
  /// devuelve el query embedding también normalizado, por lo que el cosine
  /// se calcula como un dot product simple.
  Future<List<TarjetaResultado>> buscar(String query, {int topK = 3}) async {
    if (query.trim().isEmpty) return [];

    // 1. Embed query (768 floats, ya normalizado)
    final queryEmbedding = _embedder.embed(texts: [query]).first.cast<double>();

    if (queryEmbedding.length != _dim) {
      throw StateError(
        'Dim mismatch: query=${queryEmbedding.length} vs corpus=$_dim',
      );
    }

    // 2. Dot product contra todos los vectores
    final n = _vectores.length;
    final scores = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final v = _vectores[i];
      double dot = 0.0;
      for (int j = 0; j < _dim; j++) {
        dot += queryEmbedding[j] * v[j];
      }
      scores[i] = dot;
    }

    // 3. Top-K por score descendente
    final indices = List<int>.generate(n, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));

    final k = topK.clamp(1, n);

    // 4. Construir resultados
    return [
      for (final i in indices.take(k))
        TarjetaResultado(
          indice: i,
          enriquecimiento: _enriquecimientos[i],
          score: scores[i],
        ),
    ];
  }

  /// Diagnóstico: estadísticas de scores sobre TODO el corpus para una query.
  /// Útil para calibrar el threshold de confianza.
  Future<Map<String, double>> diagnostico(String query) async {
    final resultados = await buscar(query, topK: _vectores.length);
    final scores = resultados.map((r) => r.score).toList();
    scores.sort();
    return {
      'min': scores.first,
      'max': scores.last,
      'p50': scores[scores.length ~/ 2],
      'p90': scores[(scores.length * 0.9).floor()],
      'p99': scores[(scores.length * 0.99).floor()],
      'top1_minus_top2': resultados[0].score - resultados[1].score,
    };
  }

  static Future<String> _copyAsset(String assetPath) async {
    final dir = await getApplicationSupportDirectory();
    final fileName = assetPath.split('/').last;
    final outFile = File('${dir.path}/$fileName');
    if (!await outFile.exists()) {
      final bytes = await rootBundle.load(assetPath);
      await outFile.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }
    return outFile.path;
  }
}