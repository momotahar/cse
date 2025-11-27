import 'package:flutter/foundation.dart';
import '../models/billet.dart';
import '../services/billet_dao.dart';

class BilletProvider with ChangeNotifier {
  List<Billet> _billets = [];
  bool _isLoading = false;
  String? _error;

  List<Billet> get billets => _billets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Charge tout (avec filtre local optionnel sur libellé)
  Future<void> loadBillets({String? q}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final all = await BilletDAO.getAll();
      if (q == null || q.trim().isEmpty) {
        _billets = all;
      } else {
        final s = q.trim().toLowerCase();
        _billets = all
            .where((b) => b.libelle.toLowerCase().contains(s))
            .toList();
      }
    } catch (e, st) {
      _error = 'Erreur chargement: $e';
      debugPrint('BilletProvider.loadBillets error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addBillet(Billet b) async {
    try {
      await BilletDAO.insert(b);
      await loadBillets();
    } catch (e, st) {
      _error = 'Erreur ajout';
      debugPrint('BilletProvider.addBillet error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> updateBillet(Billet b) async {
    try {
      await BilletDAO.update(b);
      await loadBillets();
    } catch (e, st) {
      _error = 'Erreur mise à jour';
      debugPrint('BilletProvider.updateBillet error: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> deleteBillet(int id) async {
    try {
      await BilletDAO.delete(id);
      _billets.removeWhere((x) => x.id == id);
      notifyListeners();
    } catch (e, st) {
      _error = 'Erreur suppression';
      debugPrint('BilletProvider.deleteBillet error: $e\n$st');
      notifyListeners();
    }
  }

  /// Temps réel (si tu veux un catalogue live)
  void listenBillets() {
    try {
      BilletDAO.watchAll().listen((list) {
        _billets = list;
        notifyListeners();
      });
    } catch (e, st) {
      debugPrint('BilletProvider.listenBillets error: $e\n$st');
    }
  }
}
