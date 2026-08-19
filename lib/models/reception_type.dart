class ReceptionType {
  final int id;
  final String name;
  final String sequenceCode;
  final String warehouse;
  final String code;
  final int operationCount;
  const ReceptionType({
    required this.id,
    required this.name,
    required this.sequenceCode,
    required this.warehouse,
    required this.code,
    required this.operationCount,
  });
  factory ReceptionType.fromJson(Map<String, dynamic> j) {
    final w = j['warehouse_id'];
    return ReceptionType(
      id: j['id'] as int,
      name: (j['name'] ?? 'Réception').toString(),
      sequenceCode: (j['sequence_code'] ?? '').toString(),
      warehouse: w is List && w.length > 1 ? w[1].toString() : '',
      code: (j['code'] ?? '').toString(),
      operationCount: (j['count_picking'] as num?)?.toInt() ?? 0,
    );
  }
}
