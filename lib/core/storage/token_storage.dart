import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// Persists the Sanctum token and cached user across launches.
class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.kAuthToken, value: token);

  static Future<String?> getToken() =>
      _storage.read(key: AppConstants.kAuthToken);

  static Future<void> clear() async {
    await _storage.delete(key: AppConstants.kAuthToken);
    await _storage.delete(key: AppConstants.kAuthUser);
  }

  static Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: AppConstants.kAuthUser, value: jsonEncode(user));

  static Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: AppConstants.kAuthUser);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
