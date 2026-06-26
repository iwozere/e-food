import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fork_scale/core/database/meals_repository.dart';
import 'package:fork_scale/core/services/gemini_service.dart';
import 'package:fork_scale/core/services/image_service.dart';
import 'package:fork_scale/features/capture/capture_controller.dart';
import 'package:fork_scale/models/enums.dart';
import 'package:fork_scale/models/meal.dart';

class _FakeImageService extends ImageService {
  final List<String> deleted = [];
  final String path;
  _FakeImageService(this.path);

  @override
  Future<({Uint8List apiBytes, String savedPath})> processCapture(
    File source, {
    required String filename,
  }) async =>
      (apiBytes: Uint8List(0), savedPath: path);

  @override
  Future<void> deletePhoto(String p) async => deleted.add(p);
}

class _FakeGemini extends GeminiService {
  final Object? throwThis;
  final GeminiAnalysisResult? result;
  _FakeGemini({this.throwThis, this.result}) : super(apiKey: 'test');

  @override
  Future<GeminiAnalysisResult> analyzeImage({
    required Uint8List imageBytes,
    required String utensil,
    required double utensilLengthCm,
  }) async {
    if (throwThis != null) throw throwThis!;
    return result!;
  }
}

class _FakeRepo extends MealsRepository {
  final List<Meal> inserted = [];
  @override
  Future<int> insertMeal(Meal meal) async {
    inserted.add(meal);
    return 1;
  }
}

CaptureController _controller({
  Object? thrown,
  GeminiAnalysisResult? result,
  required _FakeImageService image,
  _FakeRepo? repo,
}) =>
    CaptureController(
      gemini: _FakeGemini(throwThis: thrown, result: result),
      imageService: image,
      mealsRepository: repo ?? _FakeRepo(),
    );

void main() {
  final source = File('dummy.jpg');
  const okResult = GeminiAnalysisResult(
    utensilDetected: true,
    scaleConfidence: 'high',
    items: [],
    totalKcal: 400,
    notes: null,
  );

  Future<CaptureOutcome> run(CaptureController c) => c.analyze(
        source: source,
        utensil: Utensil.fork,
        utensilLengthCm: 18.5,
      );

  test('success returns CaptureSuccess with the saved photo path', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome = await run(_controller(result: okResult, image: image));
    expect(outcome, isA<CaptureSuccess>());
    final s = outcome as CaptureSuccess;
    expect(s.result.photoPath, '/photos/a.jpg');
    expect(s.result.totalKcal, 400);
    expect(image.deleted, isEmpty); // photo kept on success
  });

  test('timeout is retryable and keeps the photo', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome =
        await run(_controller(thrown: TimeoutException('x'), image: image));
    expect(outcome, isA<CaptureRetryable>());
    expect((outcome as CaptureRetryable).reason, CaptureRetryReason.timeout);
    expect(outcome.savedPath, '/photos/a.jpg');
    expect(image.deleted, isEmpty);
  });

  test('rate limit is retryable and keeps the photo', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome = await run(
        _controller(thrown: const GeminiRateLimitException(), image: image));
    expect((outcome as CaptureRetryable).reason, CaptureRetryReason.rateLimit);
    expect(image.deleted, isEmpty);
  });

  test('401/403 returns ApiKeyError and discards the photo', () async {
    for (final code in [401, 403]) {
      final image = _FakeImageService('/photos/a.jpg');
      final outcome = await run(
          _controller(thrown: GeminiApiException(code, 'no'), image: image));
      expect(outcome, isA<CaptureApiKeyError>());
      expect(image.deleted, ['/photos/a.jpg']);
    }
  });

  test('503 is retryable and keeps the photo', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome = await run(
        _controller(thrown: GeminiApiException(503, 'busy'), image: image));
    expect((outcome as CaptureRetryable).reason, CaptureRetryReason.overloaded);
    expect(image.deleted, isEmpty);
  });

  test('other API error is terminal and discards the photo', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome = await run(
        _controller(thrown: GeminiApiException(500, 'boom'), image: image));
    final e = outcome as CaptureError;
    expect(e.kind, CaptureErrorKind.apiError);
    expect(e.statusCode, 500);
    expect(e.detail, 'boom');
    expect(image.deleted, ['/photos/a.jpg']);
  });

  test('truncated parse error maps to responseCutOff and discards', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome = await run(_controller(
        thrown: const GeminiParseException('raw', truncated: true),
        image: image));
    expect((outcome as CaptureError).kind, CaptureErrorKind.responseCutOff);
    expect(image.deleted, ['/photos/a.jpg']);
  });

  test('non-truncated parse error maps to couldNotRead', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome = await run(
        _controller(thrown: const GeminiParseException('raw'), image: image));
    expect((outcome as CaptureError).kind, CaptureErrorKind.couldNotRead);
  });

  test('unexpected error is terminal and discards the photo', () async {
    final image = _FakeImageService('/photos/a.jpg');
    final outcome =
        await run(_controller(thrown: StateError('weird'), image: image));
    expect((outcome as CaptureError).kind, CaptureErrorKind.unexpected);
    expect(image.deleted, ['/photos/a.jpg']);
  });

  test('saveForLater inserts a pending meal', () async {
    final repo = _FakeRepo();
    final c = _controller(
        result: okResult, image: _FakeImageService('/p.jpg'), repo: repo);
    await c.saveForLater(savedPath: '/p.jpg', utensil: Utensil.fork);
    expect(repo.inserted, hasLength(1));
    expect(repo.inserted.single.pending, isTrue);
    expect(repo.inserted.single.photoPath, '/p.jpg');
    expect(repo.inserted.single.totalKcal, 0);
  });
}
