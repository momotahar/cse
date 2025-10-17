import 'package:flutter/foundation.dart';
import '../models/kilometrage.dart';
import '../services/kilometrage_dao.dart';

class KilometrageProvider with ChangeNotifier {
  List<Kilometrage> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Kilometrage> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ───────────── Loads ─────────────
  Future<void> loadByAnnee(int annee) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await KilometrageDAO.getByAnnee(annee);
    } catch (e, st) {
      _error = 'Erreur chargement: $e';
      debugPrint('KilometrageProvider.loadByAnnee error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadByVehicule(int vehiculeId, {int? annee}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await KilometrageDAO.getByVehicule(vehiculeId, annee: annee);
    } catch (e, st) {
      _error = 'Erreur chargement: $e';
      debugPrint('KilometrageProvider.loadByVehicule error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ───────────── CRUD ─────────────
  Future<void> addKilometrage(Kilometrage k) async {
    try {
      await KilometrageDAO.insert(k);
      // reload: selon ton écran (par année ou véhicule). Ici on recharge tout.
      _items = await KilometrageDAO.getAll();
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur ajout: $e';
      debugPrint('KilometrageProvider.addKilometrage error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> updateKilometrage(Kilometrage k) async {
    try {
      await KilometrageDAO.update(k);
      final idx = _items.indexWhere((e) => e.id == k.id);
      if (idx != -1) _items[idx] = k;
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur mise à jour: $e';
      debugPrint('KilometrageProvider.updateKilometrage error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> deleteKilometrage(int id) async {
    try {
      await KilometrageDAO.delete(id);
      _items.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur suppression: $e';
      debugPrint('KilometrageProvider.deleteKilometrage error: $e\n$st');
      notifyListeners();
    }
  }

  /// Upsert par (vehiculeId, mois, annee)
  Future<void> upsertByKey({
    required int vehiculeId,
    required int mois,
    required int annee,
    required int kilometrage,
  }) async {
    try {
      await KilometrageDAO.upsertByKey(
        vehiculeId: vehiculeId,
        mois: mois,
        annee: annee,
        kilometrage: kilometrage,
      );
      // Recharge utile (à adapter à ton écran courant)
      _items = await KilometrageDAO.getByVehicule(vehiculeId, annee: annee);
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur upsert: $e';
      debugPrint('KilometrageProvider.upsertByKey error: $e\n$st');
      notifyListeners();
    }
  }

  // ───────────── Temps réel (optionnel) ─────────────
  void startRealtimeByAnnee(int annee) {
    try {
      KilometrageDAO.watchByAnnee(annee).listen((data) {
        _items = data;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('KilometrageProvider.startRealtimeByAnnee error: $e\n$st');
    }
  }

  void startRealtimeByVehicule(int vehiculeId, {int? annee}) {
    try {
      KilometrageDAO.watchByVehicule(vehiculeId, annee: annee).listen((data) {
        _items = data;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('KilometrageProvider.startRealtimeByVehicule error: $e\n$st');
    }
  }
}
