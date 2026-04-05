import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
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
  User? _user;
  String? _token;
  String? _refreshToken;
  bool _isLoading = false;
  bool _isInitializing = true;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _user != null && _token != null;
  bool get canManageAccounts => _user?.isAdmin ?? false;

  AuthService() {
    _loadStoredAuth();
  }

  Future<void> _loadStoredAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      final storedRefreshToken = prefs.getString('refresh_token');
      final storedUser = prefs.getString('auth_user');

      if (storedToken != null && storedUser != null) {
        final decodedUser = jsonDecode(storedUser);
        if (decodedUser is Map) {
          _token = storedToken;
          _refreshToken = storedRefreshToken;
          _user = User.fromJson(Map<String, dynamic>.from(decodedUser));
          return;
        }
      }

      final userId = prefs.getInt('user_id');
      final userEmail = prefs.getString('user_email');
      final userName = prefs.getString('user_name');

      if (storedToken != null && userId != null && userEmail != null) {
        _token = storedToken;
        _refreshToken = storedRefreshToken;
        _user = User(
          id: userId,
          email: userEmail,
          name: userName,
        );
      }
    } catch (_) {
      await _clearStoredAuth();
      _user = null;
      _token = null;
      _refreshToken = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _storeAuth(
    User user,
    String token, {
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_email', user.email);
    if (user.name != null && user.name!.isNotEmpty) {
      await prefs.setString('user_name', user.name!);
    } else {
      await prefs.remove('user_name');
    }
    await prefs.setString('auth_user', jsonEncode(user.toJson()));

    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString('refresh_token', refreshToken);
    } else {
      await prefs.remove('refresh_token');
    }
  }

  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('refresh_token');
    await prefs.remove('auth_user');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
  }

  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return true;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! num) {
        return true;
      }

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
      );
      return DateTime.now().isAfter(
        expiresAt.subtract(const Duration(seconds: 30)),
      );
    } catch (_) {
      return true;
    }
  }

  Future<void> _refreshAccessToken() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      throw Exception('Geen refresh token beschikbaar');
    }

    final response = await ApiService.refreshToken(
      refreshToken: _refreshToken!,
    );
    _token = (response['accessToken'] ?? response['token']) as String?;
    _refreshToken = response['refreshToken'] as String?;

    if (_user == null || _token == null) {
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

      await _applyAuthResponse(response);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateCurrentUser(User user) async {
    _user = user;

    if (_token != null) {
      await _storeAuth(user, _token!, refreshToken: _refreshToken);
    }

    notifyListeners();
  }

  Future<void> updateProfile({
    required String email,
    required String name,
    List<int>? departmentIds,
  }) async {
    if (_user == null || _token == null) {
      throw Exception('Not authenticated');
    }

    _isLoading = true;
    notifyListeners();

    try {
      final validToken = await getValidAccessToken();
      final response = await ApiService.updateProfile(
        userId: _user!.id,
        token: validToken,
        email: email,
        name: name,
        departmentIds: departmentIds,
      );

      _user = User.fromJson(response);
      await _storeAuth(_user!, _token!, refreshToken: _refreshToken);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;

    _user = null;
    _token = null;
    _refreshToken = null;

    await _clearStoredAuth();

    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await ApiService.logout(refreshToken: refreshToken);
      } catch (_) {
        debugPrint(
          'Logout token revocation failed, local session was still cleared.',
        );
      }
    }

    notifyListeners();
  }

  Future<void> _applyAuthResponse(Map<String, dynamic> response) async {
    final userJson = response['user'];
    if (userJson is! Map) {
      throw Exception('Invalid user payload received from the server');
    }

    _token = (response['accessToken'] ?? response['token']) as String?;
    _refreshToken = response['refreshToken'] as String?;
    _user = User.fromJson(Map<String, dynamic>.from(userJson));

    if (_token == null) {
      throw Exception('Authentication token is missing from the response');
    }

    await _storeAuth(_user!, _token!, refreshToken: _refreshToken);
  }
}
