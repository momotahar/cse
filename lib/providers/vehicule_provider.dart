// lib/providers/vehicule_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vehicule.dart';
import '../services/vehicule_dao.dart';

class VehiculeProvider with ChangeNotifier {
  List<Vehicule> _vehicules = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Vehicule>>? _sub;

  List<Vehicule> get vehicules => _vehicules;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge tous les véhicules (one-shot)
  Future<void> loadVehicules() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _vehicules = await VehiculeDAO.getAll();
    } catch (e, st) {
      _error = 'Erreur lors du chargement : $e';
      debugPrint('VehiculeProvider.loadVehicules error: $e\n$st');
      rethrow; // remonte à l’UI
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajout
  Future<void> addVehicule(Vehicule v) async {
    try {
      final n = await VehiculeDAO.insert(v);
      if (n != 1) throw StateError('Insertion non confirmée');
      await loadVehicules();
    } catch (e, st) {
      debugPrint('VehiculeProvider.addVehicule error: $e\n$st');
      _error = 'Erreur lors de l’ajout';
      notifyListeners();
      rethrow;
    }
  }

  /// Mise à jour
  Future<void> updateVehicule(Vehicule v) async {
    try {
      final n = await VehiculeDAO.update(v);
      if (n != 1) throw StateError('Mise à jour non confirmée');
      await loadVehicules();
    } catch (e, st) {
      debugPrint('VehiculeProvider.updateVehicule error: $e\n$st');
      _error = 'Erreur lors de la mise à jour';
      notifyListeners();
      rethrow;
    }
  }

  /// Suppression
  Future<void> deleteVehicule(int id) async {
    try {
      final n = await VehiculeDAO.delete(id);
      if (n != 1) throw StateError('Suppression non confirmée');
      _vehicules.removeWhere((v) => v.id == id);
      notifyListeners();
    } catch (e, st) {
      debugPrint('VehiculeProvider.deleteVehicule error: $e\n$st');
      _error = 'Erreur lors de la suppression';
      notifyListeners();
      rethrow;
    }
  }

  /// Écoute temps réel (optionnelle). Appeler `startRealtime()` puis `dispose()`.
  void startRealtime() {
    _sub?.cancel();
    try {
      _sub = VehiculeDAO.watchAll().listen(
        (data) {
          _vehicules = data;
          notifyListeners();
        },
        onError: (e, st) {
          debugPrint('VehiculeProvider.startRealtime stream error: $e\n$st');
          _error = 'Erreur flux temps réel : $e';
          notifyListeners();
        },
      );
    } catch (e, st) {
      debugPrint('VehiculeProvider.startRealtime error: $e\n$st');
      _error = 'Erreur initialisation flux';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
