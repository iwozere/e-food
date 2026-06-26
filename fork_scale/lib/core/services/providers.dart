import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/meals_repository.dart';
import '../database/products_repository.dart';
import '../database/recipes_repository.dart';
import 'gemini_service.dart';
import 'image_service.dart';
import 'open_food_facts_service.dart';
import 'sfcd_service.dart';
import 'usda_service.dart';

/// The Gemini API key is a sensitive credential, so it is kept in the OS secure
/// store (Keychain / EncryptedSharedPreferences) rather than plaintext prefs.
const geminiKeyStorageKey = 'gemini_api_key';
const geminiKeyStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

final geminiApiKeyProvider = FutureProvider<String?>((ref) async {
  // Preferred location: secure storage.
  final secure = await geminiKeyStorage.read(key: geminiKeyStorageKey);
  if (secure != null && secure.isNotEmpty) return secure;

  // One-time migration: an earlier build stored the key in plaintext
  // SharedPreferences. If we still find it there, move it into secure storage
  // and erase the plaintext copy. Runs on first read after upgrade, so it
  // happens even if the user never opens Settings.
  final prefs = await SharedPreferences.getInstance();
  final legacy = prefs.getString(geminiKeyStorageKey);
  if (legacy != null && legacy.isNotEmpty) {
    await geminiKeyStorage.write(key: geminiKeyStorageKey, value: legacy);
    await prefs.remove(geminiKeyStorageKey);
    return legacy;
  }
  return null;
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

/// Emits a new value after every MealsRepository write. Watching this provider
/// in any FutureProvider causes it to automatically refetch after writes —
/// eliminating the need for manual ref.invalidate calls.
final mealsChangesProvider = StreamProvider<int>(
  (ref) => ref.watch(mealsRepositoryProvider).changes,
);

final productsRepositoryProvider =
    Provider<ProductsRepository>((_) => ProductsRepository());

final recipesRepositoryProvider =
    Provider<RecipesRepository>((_) => RecipesRepository());

/// Emits after every RecipesRepository write. Watch it in a FutureProvider to
/// refetch automatically — the recipe analogue of [mealsChangesProvider].
final recipesChangesProvider = StreamProvider<int>(
  (ref) => ref.watch(recipesRepositoryProvider).changes,
);

final offServiceProvider =
    Provider<OpenFoodFactsService>((_) => OpenFoodFactsService());

final sfcdServiceProvider = Provider<SfcdService>((_) => SfcdService());

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

