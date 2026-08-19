class OperationLine {
  const OperationLine({
    required this.id,
    required this.moveId,
    required this.productId,
    required this.productName,
    required this.description,
    required this.destination,
    required this.doneQuantity,
    required this.expectedQuantity,
    required this.unit,
    required this.moveLineIds,
    required this.sourcePackage,
    required this.destinationPackage,
    required this.destinationContainer,
  });

  final int id;
  final int moveId;
  final int? productId;
  final String productName;
  final String description;
  final String destination;
  final double doneQuantity;
  final double expectedQuantity;
  final String unit;
  final List<int> moveLineIds;
  final String sourcePackage;
  final String destinationPackage;
  final String destinationContainer;

  factory OperationLine.fromJson(Map<String, dynamic> json) {
    final product = json['product_id'];
    final destination = json['location_dest_id'];
    final unit = json['product_uom'];
    final moveUnit = json['_unit']?.toString() ?? '';
    final fallbackUnit = unit is List && unit.length > 1
        ? unit[1].toString()
        : 'Unité(s)';
    return OperationLine(
      id: (json['_line_id'] as num?)?.toInt() ?? (json['id'] as num).toInt(),
      moveId:
          (json['_move_id'] as num?)?.toInt() ?? (json['id'] as num).toInt(),
      productId: product is List && product.isNotEmpty
          ? (product[0] as num).toInt()
          : null,
      productName: product is List && product.length > 1
          ? product[1].toString()
          : 'Produit',
      description: json['description_picking'] is String
          ? json['description_picking'] as String
          : '',
      destination: destination is List && destination.length > 1
          ? destination[1].toString()
          : '',
      doneQuantity:
          (json['_done_quantity'] as num?)?.toDouble() ??
          (json['quantity'] as num?)?.toDouble() ??
          0,
      expectedQuantity: (json['product_uom_qty'] as num?)?.toDouble() ?? 0,
      unit: moveUnit.isEmpty ? fallbackUnit : moveUnit,
      moveLineIds:
          (json['_move_line_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map((id) => (id as num).toInt())
              .toList(growable: false),
      sourcePackage: (json['_source_package'] ?? '').toString(),
      destinationPackage: (json['_destination_package'] ?? '').toString(),
      destinationContainer: (json['_destination_container'] ?? '').toString(),
    );
  }

  OperationLine copyWith({double? doneQuantity}) => OperationLine(
    id: id,
    moveId: moveId,
    productId: productId,
    productName: productName,
    description: description,
    destination: destination,
    doneQuantity: doneQuantity ?? this.doneQuantity,
    expectedQuantity: expectedQuantity,
    unit: unit,
    moveLineIds: moveLineIds,
    sourcePackage: sourcePackage,
    destinationPackage: destinationPackage,
    destinationContainer: destinationContainer,
  );
}
