// ignore_for_file: avoid_print
//
// ForkScale accuracy evaluation harness.
//
// Calls the real Gemini API for every labelled photo in a manifest and reports
// how close the model's portion/calorie estimates are to ground truth. This is
// the evidence the 2026-06-24 review (§1, §4) found missing: it turns "is it
// accurate?" into a number you can track across prompt/model changes.
//
// It is intentionally Flutter-free so it runs under plain `dart run` in CI-less
// environments. It reuses the app's prompt + response schema from
// lib/core/services/gemini_prompt.dart so the harness can never drift from the
// shipped prompt.
//
// NOTE: this measures the *model layer* (LLM weight/kcal estimates). The app
// additionally overrides kcal/100g with USDA values (see UsdaService); to also
// measure that layer, run with --usda once the USDA lookup is exposed to a
// headless context. Until then, treat these numbers as the raw model baseline.
//
// Usage:
//   GEMINI_KEY=AIza... dart run tool/eval/run_eval.dart \
//       --manifest tool/eval/sample_manifest.json \
//       --out docs/eval-baseline-2026-06.md
//
// Manifest format: see tool/eval/sample_manifest.json and tool/eval/README.md.

import 'dart:convert';
import 'dart:io';

import 'package:fork_scale/core/services/gemini_prompt.dart';
import 'package:http/http.dart' as http;

const _model = 'gemini-2.5-flash';
const _endpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

Future<void> main(List<String> args) async {
  final opts = _parseArgs(args);
  final key = Platform.environment['GEMINI_KEY'] ?? opts['key'];
  if (key == null || key.isEmpty) {
    stderr.writeln('Missing API key. Set GEMINI_KEY env var or pass --key.');
    exitCode = 2;
    return;
  }

  final manifestPath = opts['manifest'] ?? 'tool/eval/sample_manifest.json';
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Manifest not found: $manifestPath');
    exitCode = 2;
    return;
  }

  final manifestDir = manifestFile.parent.path;
  final entries = (jsonDecode(await manifestFile.readAsString()) as List)
      .cast<Map<String, dynamic>>();
  if (entries.isEmpty) {
    stderr.writeln('Manifest is empty — add labelled photos first.');
    exitCode = 2;
    return;
  }

  print('Evaluating ${entries.length} photo(s) against $_model …\n');

  final results = <_Result>[];
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    final imagePath = _resolve(manifestDir, e['image'] as String);
    final label = e['image'] as String;
    stdout.write('[${i + 1}/${entries.length}] $label … ');
    try {
      final r = await _evalOne(e, imagePath, key);
      results.add(r);
      print(r.parseFailed
          ? 'PARSE-FAIL'
          : 'pred=${r.predictedKcal.toStringAsFixed(0)} kcal '
              '(truth=${r.truthKcal.toStringAsFixed(0)})');
    } catch (err) {
      results.add(_Result(label: label, parseFailed: true, truthKcal: 0));
      print('ERROR: $err');
    }
    // Be gentle with the free-tier rate limit (10 req/min).
    if (i < entries.length - 1) {
      await Future<void>.delayed(const Duration(seconds: 7));
    }
  }

  final report = _buildReport(results);
  final outPath = opts['out'];
  if (outPath != null) {
    await File(outPath).writeAsString(report);
    print('\nReport written to $outPath');
  } else {
    print('\n$report');
  }
}

Future<_Result> _evalOne(
    Map<String, dynamic> entry, String imagePath, String key) async {
  final utensil = (entry['utensil'] as String?) ?? 'fork';
  final lengthCm = (entry['utensil_length_cm'] as num?)?.toDouble() ?? 18.5;
  final truthKcal = (entry['truth_total_kcal'] as num).toDouble();
  final truthItems = ((entry['items'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();

  final bytes = await File(imagePath).readAsBytes();
  final body = jsonEncode({
    'contents': [
      {
        'parts': [
          {'text': buildAnalysisPrompt(utensil, lengthCm)},
          {
            'inline_data': {
              'mime_type': 'image/jpeg',
              'data': base64Encode(bytes),
            }
          },
        ]
      }
    ],
    'generationConfig': {
      'temperature': 0.2,
      'maxOutputTokens': 8192,
      'thinkingConfig': {'thinkingBudget': 0},
      'responseMimeType': 'application/json',
      'responseSchema': geminiResponseSchema,
    },
  });

  final resp = await http
      .post(Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: body)
      .timeout(const Duration(seconds: 90));

  if (resp.statusCode != 200) {
    throw 'HTTP ${resp.statusCode}: ${resp.body}';
  }

  final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
  final text =
      decoded['candidates'][0]['content']['parts'][0]['text'] as String;

  Map<String, dynamic> json;
  try {
    json = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    return _Result(
        label: entry['image'] as String, parseFailed: true, truthKcal: truthKcal);
  }

  final items = ((json['items'] as List?) ?? const [])
      .cast<Map<String, dynamic>>();
  var predicted = 0.0;
  for (final it in items) {
    final w = (it['weight_g'] as num?)?.toDouble() ?? 0;
    final kcal = (it['kcal_per_100g'] as num?)?.toDouble() ?? 0;
    predicted += w / 100.0 * kcal;
  }

  // Per-item weight error, matched by case-insensitive name containment.
  final weightErrors = <double>[];
  for (final t in truthItems) {
    final tName = (t['name'] as String).toLowerCase();
    final tWeight = (t['truth_weight_g'] as num?)?.toDouble();
    if (tWeight == null) continue;
    final match = items.firstWhere(
      (it) {
        final n = (it['name'] as String? ?? '').toLowerCase();
        return n.contains(tName) || tName.contains(n);
      },
      orElse: () => const {},
    );
    final mw = (match['weight_g'] as num?)?.toDouble();
    if (mw != null) weightErrors.add((mw - tWeight).abs());
  }

  return _Result(
    label: entry['image'] as String,
    truthKcal: truthKcal,
    predictedKcal: predicted,
    utensilDetected: json['utensil_detected'] as bool? ?? false,
    scaleConfidence: json['scale_confidence'] as String?,
    weightErrors: weightErrors,
  );
}

String _buildReport(List<_Result> results) {
  final n = results.length;
  final parsed = results.where((r) => !r.parseFailed).toList();
  final parseFailRate = (n - parsed.length) / n;
  final utensilRate =
      parsed.isEmpty ? 0.0 : parsed.where((r) => r.utensilDetected).length / parsed.length;

  double mae = 0, mape = 0;
  for (final r in parsed) {
    final err = (r.predictedKcal - r.truthKcal).abs();
    mae += err;
    if (r.truthKcal != 0) mape += err / r.truthKcal;
  }
  if (parsed.isNotEmpty) {
    mae /= parsed.length;
    mape = mape / parsed.length * 100;
  }

  final allWeightErrors = parsed.expand((r) => r.weightErrors).toList();
  final weightMae = allWeightErrors.isEmpty
      ? null
      : allWeightErrors.reduce((a, b) => a + b) / allWeightErrors.length;

  final now = DateTime.now().toIso8601String().split('T').first;
  final b = StringBuffer()
    ..writeln('# ForkScale accuracy baseline ($now)')
    ..writeln()
    ..writeln('Model: `$_model` · photos: $n · '
        'generated by `tool/eval/run_eval.dart`.')
    ..writeln()
    ..writeln('## Headline metrics')
    ..writeln()
    ..writeln('| Metric | Value |')
    ..writeln('|---|---|')
    ..writeln('| Total-kcal MAE | ${mae.toStringAsFixed(1)} kcal |')
    ..writeln('| Total-kcal MAPE | ${mape.toStringAsFixed(1)} % |')
    ..writeln('| Per-item weight MAE | '
        '${weightMae == null ? 'n/a (no item truth)' : '${weightMae.toStringAsFixed(1)} g'} |')
    ..writeln('| Utensil-detection rate | ${(utensilRate * 100).toStringAsFixed(0)} % |')
    ..writeln('| Parse-failure rate | ${(parseFailRate * 100).toStringAsFixed(0)} % |')
    ..writeln()
    ..writeln('## Per-photo')
    ..writeln()
    ..writeln('| Photo | Truth kcal | Pred kcal | Abs err | APE % | Utensil | Conf |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final r in results) {
    if (r.parseFailed) {
      b.writeln('| ${r.label} | ${r.truthKcal.toStringAsFixed(0)} | — | — | — | — | parse-fail |');
      continue;
    }
    final err = (r.predictedKcal - r.truthKcal).abs();
    final ape = r.truthKcal == 0 ? 0 : err / r.truthKcal * 100;
    b.writeln('| ${r.label} | ${r.truthKcal.toStringAsFixed(0)} | '
        '${r.predictedKcal.toStringAsFixed(0)} | ${err.toStringAsFixed(0)} | '
        '${ape.toStringAsFixed(0)} | ${r.utensilDetected ? '✓' : '✗'} | '
        '${r.scaleConfidence ?? '—'} |');
  }
  b
    ..writeln()
    ..writeln('> MAE = mean absolute error, MAPE = mean absolute % error, '
        'both on total kcal over successfully-parsed photos. Commit this file '
        'as the baseline and re-run after prompt/model/USDA changes to detect '
        'regressions.');
  return b.toString();
}

String _resolve(String dir, String path) =>
    File(path).isAbsolute ? path : '$dir/$path';

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) map[args[i].substring(2)] = args[i + 1];
  }
  return map;
}

class _Result {
  final String label;
  final bool parseFailed;
  final double truthKcal;
  final double predictedKcal;
  final bool utensilDetected;
  final String? scaleConfidence;
  final List<double> weightErrors;

  _Result({
    required this.label,
    required this.truthKcal,
    this.parseFailed = false,
    this.predictedKcal = 0,
    this.utensilDetected = false,
    this.scaleConfidence,
    this.weightErrors = const [],
  });
}
