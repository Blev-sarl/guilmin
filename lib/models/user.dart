class OdooUser {
  final int? id;
  final String name;
  final String login;
  const OdooUser({this.id, required this.name, required this.login});
  factory OdooUser.fromJson(Map<String, dynamic> j) => OdooUser(
    id: j['uid'] as int?,
    name: (j['name'] ?? '').toString(),
    login: (j['username'] ?? j['login'] ?? '').toString(),
  );
}
