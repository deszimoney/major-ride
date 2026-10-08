import '../config/app_config.dart';

/// A row of `public.users` — the profile that sits alongside Supabase Auth.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.provider = 'email',
    this.role = 'user',
  });

  final String id;
  final String name;
  final String email;
  final String provider;
  final String role;

  bool get isAdmin => role == 'admin';

  static String normalizeEmail(String? email) =>
      (email ?? '').trim().toLowerCase();

  /// The seeded owner account is always an admin, exactly as database.js does.
  static String roleFor(String email) =>
      normalizeEmail(email) == AppConfig.adminEmail ? 'admin' : 'user';

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    name: (map['name'] ?? '') as String,
    email: normalizeEmail(map['email'] as String?),
    provider: (map['provider'] ?? 'email') as String,
    role: (map['role'] ?? 'user') as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'provider': provider,
    'role': role,
  };
}
