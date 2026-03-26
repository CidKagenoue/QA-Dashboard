import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_service.dart';
import 'auth_service.dart';

class AccountManagementService extends ChangeNotifier {
  AuthService? _authService;
  List<User> _accounts = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isCreating = false;
  final Set<int> _updatingAccountIds = <int>{};
  final Set<int> _deletingAccountIds = <int>{};

  List<User> get accounts => List<User>.unmodifiable(_accounts);
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  bool get isCreating => _isCreating;
  bool get canManageAccounts => _authService?.canManageAccounts ?? false;

  void bindAuth(AuthService authService) {
    final previousUserId = _authService?.user?.id;
    final previousToken = _authService?.token;

    _authService = authService;

    if (!authService.isAuthenticated) {
      _resetState();
      return;
    }

    if (!authService.canManageAccounts) {
      _accounts = const [];
      _hasLoaded = false;
      _isLoading = false;
      _updatingAccountIds.clear();
      _deletingAccountIds.clear();
      notifyListeners();
      return;
    }

    final authChanged =
        previousUserId != authService.user?.id ||
        previousToken != authService.token;

    if (authChanged) {
      _hasLoaded = false;
      Future.microtask(loadAccounts);
    }
  }

  Future<void> loadAccounts({String? search}) async {
    if (!canManageAccounts) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final token = await _requireToken();
      final accountsJson = await ApiService.fetchAccounts(
        token: token,
        search: search,
      );

      _accounts = accountsJson.map(User.fromJson).toList()..sort(_sortUsers);
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadAccounts();

  Future<User> createAccount({
    required String email,
    required String password,
    String? name,
    required List<int> departmentIds,
    required bool isAdmin,
    required AccountAccess access,
  }) async {
    final token = await _requireToken();

    _isCreating = true;
    notifyListeners();

    try {
      final response = await ApiService.createAccount(
        token: token,
        email: email,
        password: password,
        name: name,
        departmentIds: departmentIds,
        isAdmin: isAdmin,
        access: access,
      );

      final account = _readAccountFromResponse(response);
      _upsertAccount(account);
      _hasLoaded = true;
      return account;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<User> updateAccount({
    required User account,
    required bool isAdmin,
    required AccountAccess access,
  }) async {
    final token = await _requireToken();

    _updatingAccountIds.add(account.id);
    notifyListeners();

    try {
      final response = await ApiService.updateAccountAccess(
        token: token,
        accountId: account.id,
        isAdmin: isAdmin,
        access: access,
      );

      final updatedAccount = _readAccountFromResponse(response);
      _upsertAccount(updatedAccount);

      if (_authService?.user?.id == updatedAccount.id) {
        await _authService?.updateCurrentUser(updatedAccount);
      }

      return updatedAccount;
    } finally {
      _updatingAccountIds.remove(account.id);
      notifyListeners();
    }
  }

  Future<void> deleteAccount(int accountId) async {
    final token = await _requireToken();

    _deletingAccountIds.add(accountId);
    notifyListeners();

    try {
      await ApiService.deleteAccount(token: token, accountId: accountId);

      _accounts = _accounts.where((account) => account.id != accountId).toList()
        ..sort(_sortUsers);
    } finally {
      _deletingAccountIds.remove(accountId);
      notifyListeners();
    }
  }

  bool isUpdating(int accountId) => _updatingAccountIds.contains(accountId);

  bool isDeleting(int accountId) => _deletingAccountIds.contains(accountId);

  Future<String> _requireToken() async {
    final authService = _authService;
    if (authService == null || !authService.isAuthenticated) {
      throw Exception('You are not authenticated');
    }

    return authService.getValidAccessToken();
  }

  User _readAccountFromResponse(Map<String, dynamic> response) {
    final accountJson = response['account'];
    if (accountJson is! Map) {
      throw Exception('Invalid account payload received from the server');
    }

    return User.fromJson(Map<String, dynamic>.from(accountJson));
  }

  void _upsertAccount(User account) {
    final existingIndex = _accounts.indexWhere((item) => item.id == account.id);
    if (existingIndex == -1) {
      _accounts = <User>[..._accounts, account]..sort(_sortUsers);
      return;
    }

    final updatedAccounts = List<User>.from(_accounts);
    updatedAccounts[existingIndex] = account;
    updatedAccounts.sort(_sortUsers);
    _accounts = updatedAccounts;
  }

  void _resetState() {
    _accounts = const [];
    _isLoading = false;
    _hasLoaded = false;
    _isCreating = false;
    _updatingAccountIds.clear();
    _deletingAccountIds.clear();
    notifyListeners();
  }
}

int _sortUsers(User left, User right) {
  final leftLabel = left.displayName.toLowerCase();
  final rightLabel = right.displayName.toLowerCase();
  return leftLabel.compareTo(rightLabel) != 0
      ? leftLabel.compareTo(rightLabel)
      : left.email.toLowerCase().compareTo(right.email.toLowerCase());
}
