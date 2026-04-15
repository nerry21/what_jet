import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/admin_auth_session_model.dart';
import '../../data/models/admin_user_model.dart';
import '../../data/repositories/admin_auth_repository.dart';

class AdminAuthController extends ChangeNotifier {
  AdminAuthController({required AdminAuthRepository repository})
    : _repository = repository;

  final AdminAuthRepository _repository;

  bool _isInitializing = false;
  bool _isSubmitting = false;
  bool _isOffline = false;
  String? _errorMessage;
  AdminUserModel? _authenticatedUser;

  bool get isInitializing => _isInitializing;
  bool get isSubmitting => _isSubmitting;
  bool get isOffline => _isOffline;
  String? get errorMessage => _errorMessage;
  AdminUserModel? get authenticatedUser => _authenticatedUser;

  Future<void> initialize() async {
    if (_isInitializing) {
      return;
    }

    _isInitializing = true;
    _clearError();
    notifyListeners();

    try {
      _authenticatedUser = await _repository.restoreSession();
    } catch (error) {
      _applyError(error);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<AdminAuthSessionModel?> login({
    required String email,
    required String password,
  }) async {
    _isSubmitting = true;
    _clearError();
    notifyListeners();

    try {
      final session = await _repository.login(email: email, password: password);
      _authenticatedUser = session.user;
      return session;
    } catch (error) {
      _applyError(error);
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } finally {
      _authenticatedUser = null;
      notifyListeners();
    }
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    _isOffline = false;
  }

  void _applyError(Object error) {
    _isOffline = error is ApiException && error.isOffline;
    _errorMessage = _friendlyMessage(error);
  }

  String _friendlyMessage(Object error) {
    if (error is ApiException) {
      if (error.isOffline) {
        return 'Server admin tidak bisa dijangkau.';
      }

      return error.message;
    }

    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }

    return text.replaceFirst('Bad state: ', '');
  }
}
