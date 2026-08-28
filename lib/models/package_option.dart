class PackageOption {
  const PackageOption({
    required this.id,
    required this.name,
    required this.location,
    required this.container,
    this.createdAt,
    this.productCount = 0,
  });
  final int id;
  final String name;
  final String location;
  final String container;
  final DateTime? createdAt;
  final int productCount;

  factory PackageOption.fromJson(Map<String, dynamic> json) {
    String relationName(dynamic value) =>
        value is List && value.length > 1 ? value[1].toString() : '';
    return PackageOption(
      id: (json['id'] as num).toInt(),
      name: (json['complete_name'] ?? json['name'] ?? '').toString(),
      location: relationName(json['location_id']),
      container: relationName(json['package_dest_id']),
      createdAt: (json['pack_date'] ?? json['create_date']) is String
          ? DateTime.tryParse(((json['pack_date'] ?? json['create_date']) as String).replaceFirst(' ', 'T'))
          : null,
      productCount: (json['_product_count'] as num?)?.toInt() ?? 0,
    );
  }
}
