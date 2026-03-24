import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
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
        }
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
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.login(email: email, password: password);

      await _applyAuthResponse(response);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(String email, String password, {String? name}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await ApiService.register(
        email: email,
        password: password,
        name: name,
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
