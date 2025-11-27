import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/syndic_event.dart';
import '../services/syndic_event_dao.dart';

class SyndicEventProvider extends ChangeNotifier {
  final SyndicEventDao _dao = SyndicEventDao();

  List<SyndicEvent> events = [];
  bool loading = false;

  StreamSubscription<List<SyndicEvent>>? _subscription;

  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[SyndicEventProvider] Error: $error');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  /// Écoute en continu les événements du mois donné
  void listenMonth(DateTime month) {
    final from = DateTime.utc(month.year, month.month, 1);
    final to = DateTime.utc(
      month.month == 12 ? month.year + 1 : month.year,
      month.month == 12 ? 1 : month.month + 1,
      1,
    );

    loading = true;
    notifyListeners();

    // On annule une éventuelle souscription précédente
    _subscription?.cancel();

    try {
      clearError();
      _subscription = _dao
          .streamRange(from, to)
          .listen(
            (list) {
              events = list;
              loading = false;
              notifyListeners();
            },
            onError: (error, stack) {
              loading = false;
              _setError(error, stack);
            },
          );
    } catch (e, st) {
      loading = false;
      _setError(e, st);
    }
  }

  Future<String> create(SyndicEvent e) async {
    try {
      clearError();
      return await _dao.create(e);
    } catch (e, st) {
      _setError(e, st);
      return '';
    }
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    try {
      clearError();
      await _dao.update(id, patch);
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> remove(String id) async {
    try {
      clearError();
      await _dao.remove(id);
    } catch (e, st) {
      _setError(e, st);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
