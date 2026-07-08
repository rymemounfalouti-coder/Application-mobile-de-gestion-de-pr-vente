const String productImagesAssetDir = 'assets/images/products';

const Set<String> _productImageFiles = {
  'allamma_classique_1kg.jpeg',
  'allamma_classique_200g.jpeg',
  'allamma_classique_250g.jpeg',
  'allamma_classique_2kg.jpeg',
  'allamma_classique_500g.jpeg',
  'allamma_premium_1kg.jpeg',
  'allamma_premium_200g.jpeg',
  'allamma_premium_250g.jpeg',
  'allamma_premium_2kg.jpeg',
  'allamma_premium_500g.jpeg',
  'chaara_classique_1kg.jpeg',
  'chaara_classique_200g.jpeg',
  'chaara_classique_250g.jpeg',
  'chaara_classique_2kg.jpeg',
  'chaara_classique_500.jpeg',
  'chaara_premium_1kg.jpeg',
  'chaara_premium_200g.jpeg',
  'chaara_premium_250g.jpeg',
  'chaara_premium_2kg.jpeg',
  'chaara_premium_500g.jpeg',
};

String resolveProductImageAsset({
  String image = '',
  String name = '',
  String reference = '',
}) {
  final explicit = image.trim();
  if (explicit.isNotEmpty) {
    if (_isRemoteImage(explicit) || explicit.startsWith('assets/')) {
      return explicit;
    }

    final fileName = explicit.split(RegExp(r'[\\/]')).last;
    if (_productImageFiles.contains(fileName)) {
      return '$productImagesAssetDir/$fileName';
    }
  }

  final byReference = _productImageFromReference(reference);
  if (byReference.isNotEmpty) return byReference;

  return _productImageFromName(name);
}

bool _isRemoteImage(String value) {
  final lower = value.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

String _productImageFromReference(String reference) {
  final ref = reference.trim().toLowerCase();
  if (ref.isEmpty) return '';

  final weight = _weightFromText(ref);
  if (weight.isEmpty) return '';

  if (ref.startsWith('alp'))
    return '$productImagesAssetDir/allamma_premium_$weight.jpeg';
  if (ref.startsWith('alc')) {
    return '$productImagesAssetDir/allamma_classique_$weight.jpeg';
  }
  if (ref.startsWith('41022'))
    return '$productImagesAssetDir/chaara_premium_$weight.jpeg';
  if (ref.startsWith('9305')) {
    return '$productImagesAssetDir/chaara_classique_${weight == '500g' ? '500' : weight}.jpeg';
  }

  return '';
}

String _productImageFromName(String name) {
  final normalized = _normalizeProductText(name);
  if (normalized.isEmpty) return '';

  final family =
      normalized.contains('allamma') || normalized.contains('al lamma')
      ? 'allamma'
      : normalized.contains('chaara')
      ? 'chaara'
      : '';
  if (family.isEmpty) return '';

  final range = normalized.contains('premium')
      ? 'premium'
      : normalized.contains('classique')
      ? 'classique'
      : '';
  if (range.isEmpty) return '';

  final weight = _weightFromText(normalized);
  if (weight.isEmpty) return '';

  final fileWeight =
      family == 'chaara' && range == 'classique' && weight == '500g'
      ? '500'
      : weight;
  return '$productImagesAssetDir/${family}_${range}_$fileWeight.jpeg';
}

String _weightFromText(String value) {
  final normalized = value.toLowerCase().replaceAll(',', '.');
  if (RegExp(r'(^|[^0-9])2000([^0-9]|$)').hasMatch(normalized) ||
      normalized.contains('2kg') ||
      normalized.contains('2 kg')) {
    return '2kg';
  }
  if (RegExp(r'(^|[^0-9])1000([^0-9]|$)').hasMatch(normalized) ||
      normalized.contains('1kg') ||
      normalized.contains('1 kg')) {
    return '1kg';
  }
  if (RegExp(r'(^|[^0-9])500([^0-9]|$)').hasMatch(normalized) ||
      normalized.contains('500g') ||
      normalized.contains('500 g')) {
    return '500g';
  }
  if (RegExp(r'(^|[^0-9])250([^0-9]|$)').hasMatch(normalized) ||
      normalized.contains('250g') ||
      normalized.contains('250 g')) {
    return '250g';
  }
  if (RegExp(r'(^|[^0-9])200([^0-9]|$)').hasMatch(normalized) ||
      normalized.contains('200g') ||
      normalized.contains('200 g')) {
    return '200g';
  }
  return '';
}

String _normalizeProductText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll(RegExp('[èéêë]'), 'e')
      .replaceAll(RegExp('[ìíîï]'), 'i')
      .replaceAll(RegExp('[òóôõö]'), 'o')
      .replaceAll(RegExp('[ùúûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}
