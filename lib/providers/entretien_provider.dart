import 'package:flutter/foundation.dart';
import '../models/entretien.dart';
import '../services/entretien_dao.dart';

class EntretienProvider with ChangeNotifier {
  List<Entretien> _items = [];
  bool _isLoading = false;
  String? _error;

  List<Entretien> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadByVehicule(int vehiculeId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await EntretienDAO.getByVehicule(vehiculeId);
    } catch (e, st) {
      _error = 'Erreur chargement: $e';
      debugPrint('EntretienProvider.loadByVehicule error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addEntretien(Entretien e, {int? forVehiculeReload}) async {
    try {
      await EntretienDAO.insert(e);
      if (forVehiculeReload != null) {
        _items = await EntretienDAO.getByVehicule(forVehiculeReload);
      }
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur ajout: $e';
      debugPrint('EntretienProvider.addEntretien error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> updateEntretien(Entretien e) async {
    try {
      await EntretienDAO.update(e);
      final i = _items.indexWhere((x) => x.id == e.id);
      if (i != -1) _items[i] = e;
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur mise à jour: $e';
      debugPrint('EntretienProvider.updateEntretien error: $e\n$st');
      notifyListeners();
    }
  }

  List<Entretien> byVehicule(int vehiculeId) {
    try {
      final list = _items.where((e) => e.vehiculeId == vehiculeId).toList()
        ..sort((a, b) {
          final ad = (a.datePrevue ?? '');
          final bd = (b.datePrevue ?? '');
          final c = ad.compareTo(bd);
          if (c != 0) return c;
          return (a.type).compareTo(b.type);
        });
      return list;
    } catch (_) {
      return const <Entretien>[];
    }
  }

  Future<void> deleteEntretien(int id, {int? forVehiculeReload}) async {
    try {
      await EntretienDAO.delete(id);
      _items.removeWhere((x) => x.id == id);
      if (forVehiculeReload != null) {
        _items = await EntretienDAO.getByVehicule(forVehiculeReload);
      }
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur suppression: $e';
      debugPrint('EntretienProvider.deleteEntretien error: $e\n$st');
      notifyListeners();
    }
  }

  /// Temps réel (optionnel)
  void startRealtime(int vehiculeId) {
    try {
      EntretienDAO.watchByVehicule(vehiculeId).listen((list) {
        _items = list;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('EntretienProvider.startRealtime error: $e\n$st');
    }
  }
}
