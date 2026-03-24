import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
  String? _refreshToken;
  bool _isLoading = false;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _token != null;

  AuthService() {
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('auth_token');
    final userId = prefs.getInt('user_id');
    final userEmail = prefs.getString('user_email');
    final userName = prefs.getString('user_name');
    final storedRefreshToken = prefs.getString('refresh_token');

    if (storedToken != null && userId != null && userEmail != null) {
      _token = storedToken;
      _refreshToken = storedRefreshToken;
      _user = User(
        id: userId,
        email: userEmail,
        name: userName,
      );
      notifyListeners();
    }
  }

  Future<void> _storeAuth(User user, String token, {String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_email', user.email);
    if (user.name != null) {
      await prefs.setString('user_name', user.name!);
    }

    if (refreshToken != null) {
      await prefs.setString('refresh_token', refreshToken);
    }
  }

  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('refresh_token');
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return true;
      }

      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! num) {
        return true;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)));
    } catch (_) {
      return true;
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      throw Exception('Geen refresh token beschikbaar');
    }

    final response = await ApiService.refreshToken(refreshToken: _refreshToken!);
    _token = response['token'] as String?;
    _refreshToken = response['refreshToken'] as String?;

    if (_user == null || _token == null || _refreshToken == null) {
      throw Exception('Ongeldig refresh antwoord');
    }

    await _storeAuth(_user!, _token!, refreshToken: _refreshToken);
  }

  Future<String> getValidAccessToken() async {
    if (_token == null) {
      throw Exception('Not authenticated');
    }

    if (_isTokenExpired(_token!)) {
      await _refreshAccessToken();
    }

    if (_token == null) {
      throw Exception('Not authenticated');
    }

    return _token!;
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.login(
        email: email,
        password: password,
      );

      _token = response['token'];
      _refreshToken = response['refreshToken'];
      _user = User.fromJson(response['user']);

      // Store auth data
      await _storeAuth(_user!, _token!, refreshToken: _refreshToken);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  
  Future<void> updateProfile({
    required String email,
    required String name,
    }) async {
      if (_user == null || _token == null) {
        throw Exception('Not authenticated');
      }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.updateProfile(
        userId: _user!.id,
        token: _token!,
        email: email,
        name: name,
      );

      _user = User.fromJson(response);
      await _storeAuth(_user!, _token!);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _refreshToken = null;

    // Clear stored auth data
    await _clearStoredAuth();

    notifyListeners();
  }
  Future<void> changePassword({
  required String currentPassword,
  required String newPassword,
  required String confirmNewPassword,
  }) async {
    if (_token == null) {
      throw Exception('Niet ingelogd');
    }

    _isLoading = true;
    notifyListeners();

    try {
      await ApiService.changePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmNewPassword: confirmNewPassword,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}