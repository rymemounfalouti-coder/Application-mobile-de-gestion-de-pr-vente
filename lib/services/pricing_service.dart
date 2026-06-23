import '../data/mock_presales_data.dart';

class PricingResult {
  const PricingResult({
    required this.basePrice,
    required this.appliedUnitPrice,
    required this.tariffLabel,
    required this.discountRate,
    required this.discountAmount,
    required this.grossTotal,
    required this.lineTotal,
  });

  final double basePrice;
  final double appliedUnitPrice;
  final String tariffLabel;
  final double discountRate;
  final double discountAmount;
  final double grossTotal;
  final double lineTotal;
}

class PricingService {
  const PricingService._();

  static double getPriceForClient(
    OrderProduct product,
    CommercialClient client,
  ) {
    return switch (client.category) {
      'Grossistes' => product.prixGrossiste,
      'Supermarchés & Grandes Surfaces' => product.prixGMS,
      'Cafés & Restaurants' => product.prixCHR,
      _ => product.prixStandard,
    };
  }

  static String getTariffLabel(CommercialClient client) {
    return switch (client.category) {
      'Grossistes' => 'Grossiste',
      'Supermarchés & Grandes Surfaces' => 'GMS',
      'Cafés & Restaurants' => 'CHR',
      _ => 'Standard',
    };
  }

  static double getQuantityDiscount(int quantity) {
    if (quantity > 20) return .08;
    if (quantity >= 11) return .05;
    if (quantity >= 6) return .03;
    return 0;
  }

  static PricingResult calculateLineTotal(
    OrderProduct product,
    CommercialClient client,
    int quantity,
  ) {
    final basePrice = getPriceForClient(product, client);
    final discountRate = getQuantityDiscount(quantity);
    final appliedUnitPrice = basePrice * (1 - discountRate);
    final grossTotal = basePrice * quantity;
    final lineTotal = appliedUnitPrice * quantity;
    return PricingResult(
      basePrice: basePrice,
      appliedUnitPrice: appliedUnitPrice,
      tariffLabel: getTariffLabel(client),
      discountRate: discountRate,
      discountAmount: grossTotal - lineTotal,
      grossTotal: grossTotal,
      lineTotal: lineTotal,
    );
  }
}

double getPriceForClient(OrderProduct product, CommercialClient client) {
  return PricingService.getPriceForClient(product, client);
}

double getQuantityDiscount(int quantity) {
  return PricingService.getQuantityDiscount(quantity);
}

PricingResult calculateLineTotal(
  OrderProduct product,
  CommercialClient client,
  int quantity,
) {
  return PricingService.calculateLineTotal(product, client, quantity);
}
