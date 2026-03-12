import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _user;
  String? _token;
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

    if (storedToken != null && userId != null && userEmail != null) {
      _token = storedToken;
      _user = User(
        id: userId,
        email: userEmail,
        name: userName,
      );
      notifyListeners();
    }
  }

  Future<void> _storeAuth(User user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_email', user.email);
    if (user.name != null) {
      await prefs.setString('user_name', user.name!);
    }
  }

  Future<void> _clearStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
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
      _user = User.fromJson(response['user']);

      // Store auth data
      await _storeAuth(_user!, _token!);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
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

      _token = response['token'];
      _user = User.fromJson(response['user']);

      // Store auth data
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

    // Clear stored auth data
    await _clearStoredAuth();

    notifyListeners();
  }
}