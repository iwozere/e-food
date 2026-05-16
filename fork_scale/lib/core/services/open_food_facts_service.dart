import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/cached_product.dart';

class OffProductNotFoundException implements Exception {}

class OffServiceException implements Exception {
  final int statusCode;
  const OffServiceException(this.statusCode);
}

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const _fields =
      'product_name,brands,nutriments,serving_size,product_quantity,image_front_small_url,countries_tags';
  static const _userAgent = 'ForkScale/1.0 (forkscale@example.com)';
  static const _timeoutSeconds = 5;

  Future<CachedProduct> lookup(String barcode) async {
    return _attempt(barcode);
  }

  Future<CachedProduct> _attempt(String barcode, {bool isRetry = false}) async {
    final uri = Uri.parse('$_baseUrl/$barcode?fields=$_fields');
    late http.Response response;
    try {
      response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: _timeoutSeconds));
    } catch (_) {
      throw OffServiceException(0);
    }

    if (response.statusCode == 404) throw OffProductNotFoundException();

    if ((response.statusCode == 429 || response.statusCode >= 500) && !isRetry) {
      await Future.delayed(const Duration(seconds: 3));
      return _attempt(barcode, isRetry: true);
    }

    if (response.statusCode != 200) {
      throw OffServiceException(response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['status'] == 0) throw OffProductNotFoundException();

    final product = body['product'] as Map<String, dynamic>;
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    final kcal = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ??
        (nutriments['energy_100g'] as num?)?.toDouble() ?? 0.0;

    final packRaw = product['product_quantity'];
    double? packSizeG;
    if (packRaw != null) {
      packSizeG = double.tryParse(packRaw.toString());
    }

    return CachedProduct(
      barcode: barcode,
      name: (product['product_name'] as String?)?.trim() ?? barcode,
      brand: (product['brands'] as String?)?.split(',').first.trim(),
      packSizeG: packSizeG,
      kcalPer100g: kcal,
      proteinG: (nutriments['proteins_100g'] as num?)?.toDouble(),
      carbsG: (nutriments['carbohydrates_100g'] as num?)?.toDouble(),
      fatG: (nutriments['fat_100g'] as num?)?.toDouble(),
      imageUrl: product['image_front_small_url'] as String?,
      source: 'off',
      fetchedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}
