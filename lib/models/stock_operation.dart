class StockOperation {
  const StockOperation({
    required this.id,
    required this.reference,
    required this.supplierReference,
    required this.origin,
    required this.partner,
    required this.scheduledDate,
    required this.state,
    required this.hasPackages,
  });

  final int id;
  final String reference;
  final String supplierReference;
  final String origin;
  final String partner;
  final DateTime? scheduledDate;
  final String state;
  final bool hasPackages;

  factory StockOperation.fromJson(Map<String, dynamic> json) {
    final partner = json['partner_id'];
    final rawDate = json['scheduled_date'];
    final rawSupplierReference = json['partner_ref'];
    return StockOperation(
      id: json['id'] as int,
      reference: (json['name'] ?? '').toString(),
      supplierReference: rawSupplierReference is String
          ? rawSupplierReference.trim()
          : '',
      origin: json['origin'] is String ? json['origin'] as String : '',
      partner: partner is List && partner.length > 1
          ? partner[1].toString()
          : '',
      scheduledDate: rawDate is String
          ? DateTime.tryParse(rawDate.replaceFirst(' ', 'T'))
          : null,
      state: (json['state'] ?? 'draft').toString(),
      hasPackages: json['_has_packages'] == true,
    );
  }
}
