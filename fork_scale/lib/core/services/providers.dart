import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/meals_repository.dart';
import 'gemini_service.dart';
import 'image_service.dart';
import 'usda_service.dart';

final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('gemini_api_key');
});

final geminiServiceProvider = Provider<GeminiService?>((ref) {
  final keyAsync = ref.watch(geminiApiKeyProvider);
  return keyAsync.valueOrNull != null
      ? GeminiService(apiKey: keyAsync.valueOrNull!)
      : null;
});

final imageServiceProvider = Provider<ImageService>((_) => ImageService());

final usdaServiceProvider = Provider<UsdaService>((_) => UsdaService());

final mealsRepositoryProvider =
    Provider<MealsRepository>((_) => MealsRepository());

final dailyGoalProvider = FutureProvider<int>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('daily_goal') ?? 2000;
});

final utensilLengthsProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'fork': prefs.getDouble('fork_length_cm') ?? 18.5,
    'knife': prefs.getDouble('knife_length_cm') ?? 21.0,
    'spoon': prefs.getDouble('spoon_length_cm') ?? 20.0,
  };
});
