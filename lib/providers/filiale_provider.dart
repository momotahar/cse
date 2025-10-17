import 'package:cse_kch/services/filiale_dao.dart';
import 'package:flutter/foundation.dart';
import '../models/filiale_model.dart';

class FilialeProvider extends ChangeNotifier {
  List<FilialeModel> _filiales = [];
  bool _isLoading = false;
  String? _error;

  List<FilialeModel> get filiales => _filiales;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Chargement avec filtre local (abréviation / désignation).
  Future<void> loadFiliales({String? q}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final all = await FilialeDAO.getAll();
      final query = (q ?? '').trim().toLowerCase();
      _filiales = query.isEmpty
          ? all
          : all.where((f) {
              final a = f.abreviation.toLowerCase();
              final d = f.designation.toLowerCase();
              return a.contains(query) || d.contains(query);
            }).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFiliale(FilialeModel f) async {
    await FilialeDAO.insert(f);
    await loadFiliales(); // refresh
  }

  Future<void> updateFiliale(FilialeModel f) async {
    await FilialeDAO.update(f);
    await loadFiliales(); // refresh
  }

  Future<void> deleteFiliale(int id) async {
    await FilialeDAO.delete(id);
    _filiales.removeWhere((x) => x.id == id);
    notifyListeners();
  }

  /// Accès rapide par id (à partir du cache courant)
  FilialeModel? byId(int? id) {
    if (id == null) return null;
    try {
      return _filiales.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }
}
