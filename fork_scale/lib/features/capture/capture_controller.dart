import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/meals_repository.dart';
import '../../core/services/gemini_service.dart';
import '../../core/services/image_service.dart';
import '../../core/services/providers.dart';
import '../../models/analysis_result.dart';
import '../../models/enums.dart';
import '../../models/meal.dart';

/// Why an analysis can be retried (the photo is kept so the user can save it).
enum CaptureRetryReason { timeout, rateLimit, overloaded }

/// Terminal (non-retryable) failure categories.
enum CaptureErrorKind { apiError, responseCutOff, couldNotRead, unexpected }

/// Result of [CaptureController.analyze]. The widget maps these to UI; the
/// controller owns the orchestration and orphan-photo cleanup so both are
/// testable without a camera or a real network.
sealed class CaptureOutcome {
  const CaptureOutcome();
}

class CaptureSuccess extends CaptureOutcome {
  final AnalysisResult result;
  const CaptureSuccess(this.result);
}

/// The key is missing/invalid (or a 401/403 came back). Photo discarded.
class CaptureApiKeyError extends CaptureOutcome {
  const CaptureApiKeyError();
}

/// Transient failure — [savedPath] is retained so the user can save for later.
class CaptureRetryable extends CaptureOutcome {
  final CaptureRetryReason reason;
  final String savedPath;
  const CaptureRetryable(this.reason, this.savedPath);
}

/// Terminal failure — photo discarded. [detail] is the raw body/text for the
/// optional diagnostics dialog.
class CaptureError extends CaptureOutcome {
  final CaptureErrorKind kind;
  final int? statusCode;
  final String? detail;
  const CaptureError(this.kind, {this.statusCode, this.detail});
}

/// Orchestrates capture → resize → analyze → persist/error-route. Pure of any
/// Flutter UI so it can be unit-tested with fake services.
class CaptureController {
  final GeminiService gemini;
  final ImageService imageService;
  final MealsRepository mealsRepository;

  CaptureController({
    required this.gemini,
    required this.imageService,
    required this.mealsRepository,
  });

  Future<CaptureOutcome> analyze({
    required File source,
    required Utensil utensil,
    required double utensilLengthCm,
  }) async {
    String? savedPath;
    try {
      final filename = '${const Uuid().v4()}.jpg';
      final processed =
          await imageService.processCapture(source, filename: filename);
      savedPath = processed.savedPath;

      final result = await gemini.analyzeImage(
        imageBytes: processed.apiBytes,
        utensil: utensil.name,
        utensilLengthCm: utensilLengthCm,
      );

      return CaptureSuccess(AnalysisResult(
        utensilDetected: result.utensilDetected,
        scaleConfidence: result.scaleConfidence,
        items: result.items,
        totalKcal: result.totalKcal,
        notes: result.notes,
        photoPath: processed.savedPath,
        utensil: utensil.name,
      ));
    } on TimeoutException {
      return _retryOrDiscard(CaptureRetryReason.timeout, savedPath);
    } on GeminiRateLimitException {
      return _retryOrDiscard(CaptureRetryReason.rateLimit, savedPath);
    } on GeminiApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _discard(savedPath);
        return const CaptureApiKeyError();
      }
      if (e.statusCode == 503) {
        return _retryOrDiscard(CaptureRetryReason.overloaded, savedPath);
      }
      await _discard(savedPath);
      return CaptureError(CaptureErrorKind.apiError,
          statusCode: e.statusCode, detail: e.body);
    } on GeminiParseException catch (e) {
      await _discard(savedPath);
      return CaptureError(
        e.truncated
            ? CaptureErrorKind.responseCutOff
            : CaptureErrorKind.couldNotRead,
        detail: e.rawText,
      );
    } catch (e) {
      await _discard(savedPath);
      return CaptureError(CaptureErrorKind.unexpected, detail: e.toString());
    }
  }

  /// Persists a kept photo as a pending meal to analyze later from History.
  Future<void> saveForLater({
    required String savedPath,
    required Utensil utensil,
  }) async {
    await mealsRepository.insertMeal(Meal(
      createdAt: DateTime.now(),
      photoPath: savedPath,
      totalKcal: 0,
      utensil: utensil,
      modelUsed: 'gemini',
      mealType: Meal.detectTypeFromTime(),
      pending: true,
    ));
  }

  // A retryable failure can only occur after the photo was saved; if it somehow
  // wasn't, fall back to a terminal error rather than dereferencing null.
  CaptureOutcome _retryOrDiscard(CaptureRetryReason reason, String? savedPath) {
    if (savedPath == null) {
      return const CaptureError(CaptureErrorKind.unexpected);
    }
    return CaptureRetryable(reason, savedPath);
  }

  Future<void> _discard(String? path) async {
    if (path == null) return;
    await imageService.deletePhoto(path);
  }
}

/// Null when no API key is configured (mirrors [geminiServiceProvider]).
final captureControllerProvider = Provider<CaptureController?>((ref) {
  final gemini = ref.watch(geminiServiceProvider);
  if (gemini == null) return null;
  return CaptureController(
    gemini: gemini,
    imageService: ref.watch(imageServiceProvider),
    mealsRepository: ref.watch(mealsRepositoryProvider),
  );
});
