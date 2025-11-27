// lib/providers/depot_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/depot.dart';
import '../services/depots_dao.dart';

class DepotProvider extends ChangeNotifier {
  final DepotsDao _dao = DepotsDao();

  List<Depot> items = [];
  bool loading = false;

  StreamSubscription<List<Depot>>? _subscription;

  String? _lastError;
  String? get lastError => _lastError;

  DepotProvider() {
    _subscription = _dao.streamAll().listen(
      (data) {
        items = data;
        notifyListeners();
      },
      onError: (error, stack) {
        _setError(error, stack);
      },
    );
  }

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[DepotProvider] Error: $error');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<String> add(
    String nom,
    String adresse, {
    String? ville,
    String? cp,
  }) async {
    try {
      clearError();
      return await _dao.create(
        nom: nom,
        adresse: adresse,
        ville: ville,
        cp: cp,
      );
    } catch (e, st) {
      _setError(e, st);
      // valeur de secours pour éviter un crash
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
}
