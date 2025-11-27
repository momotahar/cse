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

  // ------- LOAD -------
  Future<void> loadVehicules() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await VehiculeDAO.getAll();
      // IMPORTANT : on force une liste modifiable
      _vehicules = List<Vehicule>.from(data);
    } catch (e, st) {
      _error = 'Erreur lors du chargement : $e';
      debugPrint('VehiculeProvider.loadVehicules error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ------- CREATE or UPDATE (upsert) -------
  Future<Vehicule> addVehicule(Vehicule v) async {
    try {
      final saved = await VehiculeDAO.upsert(v);

      final i = _vehicules.indexWhere((x) => x.id == saved.id);

      if (i >= 0) {
        // remplacer un élément -> on crée une nouvelle liste
        final newList = List<Vehicule>.from(_vehicules);
        newList[i] = saved;
        _vehicules = newList;
      } else {
        // ajouter un élément -> nouvelle liste avec spread
        _vehicules = [..._vehicules, saved];
      }

      notifyListeners();
      return saved;
    } catch (e, st) {
      debugPrint('VehiculeProvider.addVehicule error: $e\n$st');
      _error = 'Erreur lors de l’ajout';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateVehicule(Vehicule v) async {
    if (v.id == null) {
      throw ArgumentError('updateVehicule nécessite un id');
    }
    try {
      final saved = await VehiculeDAO.upsert(v);
      final i = _vehicules.indexWhere((x) => x.id == saved.id);

      if (i >= 0) {
        final newList = List<Vehicule>.from(_vehicules);
        newList[i] = saved;
        _vehicules = newList;
      }

      notifyListeners();
    } catch (e, st) {
      debugPrint('VehiculeProvider.updateVehicule error: $e\n$st');
      _error = 'Erreur lors de la mise à jour';
      notifyListeners();
      rethrow;
    }
  }

  // ------- DELETE -------
  Future<void> deleteVehicule(String id) async {
    try {
      await VehiculeDAO.delete(id);

      // on ne modifie pas la liste en place, on recrée
      _vehicules = _vehicules
          .where((v) => v.id?.toString() != id.toString())
          .toList();

      notifyListeners();
    } catch (e, st) {
      debugPrint('VehiculeProvider.deleteVehicule error: $e\n$st');
      _error = 'Erreur lors de la suppression';
      notifyListeners();
      rethrow;
    }
  }

  // ------- REAL-TIME (optionnel) -------
  void startRealtime() {
    _sub?.cancel();
    try {
      _sub = VehiculeDAO.watchAll().listen(
        (data) {
          // pareil, on force une liste modifiable
          _vehicules = List<Vehicule>.from(data);
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
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
