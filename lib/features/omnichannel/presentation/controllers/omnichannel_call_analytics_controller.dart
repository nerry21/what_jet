import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../../data/models/omnichannel_call_analytics_summary_model.dart';
import '../../data/repositories/omnichannel_repository.dart';

class OmnichannelCallAnalyticsController extends ChangeNotifier {
  OmnichannelCallAnalyticsController({
    required OmnichannelRepository repository,
    this.recentLimit = 8,
  }) : _repository = repository;

  final OmnichannelRepository _repository;
  final int recentLimit;

  OmnichannelCallAnalyticsSnapshotModel? _snapshot;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  OmnichannelCallAnalyticsSnapshotModel? get snapshot => _snapshot;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get hasData => _snapshot != null;

  Future<void> initialize() async {
    if (_snapshot != null || _isLoading) {
      return;
    }

    await refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    if (_isLoading || _isRefreshing) {
      return;
    }

    if (silent) {
      _isRefreshing = true;
    } else {
      _isLoading = true;
      _errorMessage = null;
    }
    notifyListeners();

    try {
      _snapshot = await _repository.loadCallAnalytics(recentLimit: recentLimit);
      _errorMessage = null;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = 'Gagal memuat analytics panggilan: $error';
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
