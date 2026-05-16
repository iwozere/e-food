class CachedProduct {
  final String barcode;
  final String name;
  final String? brand;
  final double? packSizeG;
  final double kcalPer100g;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final String? imageUrl;
  final String source; // 'off' | 'manual'
  final int fetchedAt; // Unix ms

  const CachedProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.packSizeG,
    required this.kcalPer100g,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.imageUrl,
    required this.source,
    required this.fetchedAt,
  });

  CachedProduct copyWith({
    String? name,
    String? brand,
    double? packSizeG,
    double? kcalPer100g,
    double? proteinG,
    double? carbsG,
    double? fatG,
    String? imageUrl,
    String? source,
    int? fetchedAt,
  }) =>
      CachedProduct(
        barcode: barcode,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        packSizeG: packSizeG ?? this.packSizeG,
        kcalPer100g: kcalPer100g ?? this.kcalPer100g,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        imageUrl: imageUrl ?? this.imageUrl,
        source: source ?? this.source,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  Map<String, dynamic> toMap() => {
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'pack_size_g': packSizeG,
        'kcal_per_100g': kcalPer100g,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'image_url': imageUrl,
        'source': source,
        'fetched_at': fetchedAt,
      };

  factory CachedProduct.fromMap(Map<String, dynamic> map) => CachedProduct(
        barcode: map['barcode'] as String,
        name: map['name'] as String,
        brand: map['brand'] as String?,
        packSizeG: (map['pack_size_g'] as num?)?.toDouble(),
        kcalPer100g: (map['kcal_per_100g'] as num).toDouble(),
        proteinG: (map['protein_g'] as num?)?.toDouble(),
        carbsG: (map['carbs_g'] as num?)?.toDouble(),
        fatG: (map['fat_g'] as num?)?.toDouble(),
        imageUrl: map['image_url'] as String?,
        source: map['source'] as String,
        fetchedAt: map['fetched_at'] as int,
      );
}
