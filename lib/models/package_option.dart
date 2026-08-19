class PackageOption {
  const PackageOption({
    required this.id,
    required this.name,
    required this.location,
    required this.container,
  });
  final int id;
  final String name;
  final String location;
  final String container;

  factory PackageOption.fromJson(Map<String, dynamic> json) {
    String relationName(dynamic value) =>
        value is List && value.length > 1 ? value[1].toString() : '';
    return PackageOption(
      id: (json['id'] as num).toInt(),
      name: (json['complete_name'] ?? json['name'] ?? '').toString(),
      location: relationName(json['location_id']),
      container: relationName(json['package_dest_id']),
    );
  }
}
