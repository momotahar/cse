// lib/providers/reglement_provider.dart
// ignore_for_file: avoid_print

import 'package:cse_kch/services/reglement_dao.dart';
import 'package:flutter/foundation.dart';
import '../models/reglement.dart';

class ReglementProvider extends ChangeNotifier {
  final List<Reglement> _reglements = [];
  bool _isLoading = false;
  Object? _lastError;

  List<Reglement> get reglements => List.unmodifiable(_reglements);
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  // Charge tous les règlements
  Future<void> loadReglements() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();
    try {
      final rows = await ReglementDAO.getAll();
      _reglements
        ..clear()
        ..addAll(rows);
    } catch (e) {
      _lastError = e;
      if (kDebugMode) print('ReglementProvider.loadReglements error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Ajout
  Future<void> addReglement(Reglement r) async {
    try {
      await ReglementDAO.insert(r);
      // on recharge pour garder la source de vérité (id, etc.)
      await loadReglements();
    } catch (e) {
      _lastError = e;
      notifyListeners();
      rethrow;
    }
  }

  // Mise à jour
  Future<void> updateReglement(Reglement r) async {
    try {
      await ReglementDAO.update(r);
      await loadReglements();
    } catch (e) {
      _lastError = e;
      notifyListeners();
      rethrow;
    }
  }

  // Suppression
  Future<void> deleteReglement(int id) async {
    try {
      await ReglementDAO.delete(id);
      _reglements.removeWhere((x) => x.id == id);
      notifyListeners();
    } catch (e) {
      _lastError = e;
      notifyListeners();
      rethrow;
    }
  }

  /// Agrégat: total payé par commande (commandeId -> somme(montant))
  Map<int, double> get totalByCommande {
    final Map<int, double> m = {};
    for (final r in _reglements) {
      final key = r.commandeId;
      m[key] = (m[key] ?? 0.0) + r.montant;
    }
    return m;
    // Si tu veux *mémoïser*, remplace par un cache + invalidations, mais
    // en général ce calcul est très rapide.
  }

  /// Total payé pour une commande donnée
  double paidFor(int commandeId) => totalByCommande[commandeId] ?? 0.0;

  // Optionnel: flux temps-réel si tu as un watchAll() dans le DAO
  // Appelle `attachStream()` une seule fois (ex: au boot de l’app).
  bool _streamAttached = false;
  void attachStreamOnce() {
    if (_streamAttached) return;
    _streamAttached = true;
    try {
      ReglementDAO.watchAll().listen(
        (rows) {
          _reglements
            ..clear()
            ..addAll(rows);
          notifyListeners();
        },
        onError: (e) {
          _lastError = e;
          notifyListeners();
        },
      );
    } catch (e) {
      _lastError = e;
      notifyListeners();
    }
  }
}
