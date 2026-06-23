class OrderCartItem {
  OrderCartItem({
    required this.productId,
    required this.name,
    required this.shortName,
    required this.unitPrice,
    required this.quantity,
  });

  final int productId;
  final String name;
  final String shortName;
  final double unitPrice;
  final int quantity;

  double get total => unitPrice * quantity;

  OrderCartItem copyWith({int? quantity}) {
    return OrderCartItem(
      productId: productId,
      name: name,
      shortName: shortName,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }
}
