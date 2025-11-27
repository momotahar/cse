import 'package:flutter/foundation.dart';
import '../models/depense.dart';
import '../services/depense_dao.dart';

/// Provider compatible avec tes écrans:
/// - setFilters(from,to,fournisseurLike) => recharge la période & filtre en mémoire
/// - refresh() => recharge la dernière période mémorisée
/// - add/update/delete => puis refresh()
/// - KPIs: totalAmount / invoiceCount / sumBySupplier
class DepenseProvider extends ChangeNotifier {
  final DepenseDao _dao;

  DepenseProvider({DepenseDao? dao}) : _dao = dao ?? DepenseDao();

  // Dataset courant (dernière période chargée depuis Firestore)
  List<Depense> _all = [];
  // Vue filtrée (appliquée en mémoire)
  List<Depense> _filtered = [];
  List<Depense> get depenses => _filtered;

  // Période courante mémorisée pour refresh()
  DateTime? _from;
  DateTime? _to;

  // Filtres mémoire
  String? _fournisseurLike;

  // Dernière erreur (optionnel, pour afficher un message dans l’UI si besoin)
  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[DepenseProvider] Error: $error');
      debugPrint(stack.toString());
    }
  }

  void clearError() {
    _lastError = null;
  }

  // ─────────────────────────────────────────────────────────
  /// Applique les filtres et (si nécessaire) recharge la période depuis Firestore.
  /// - Si `from`/`to` changent par rapport à l’état courant, on refetch.
  /// - Puis on filtre en mémoire avec `fournisseurLike`.
  Future<void> setFilters({
    DateTime? from,
    DateTime? to,
    String? fournisseurLike,
    bool silent = false, // pour éviter un notify sur certains écrans si besoin
  }) async {
    try {
      clearError();

      // normalise fournisseurLike
      _fournisseurLike = (fournisseurLike ?? '').trim().isEmpty
          ? null
          : fournisseurLike!.trim();

      final bool periodChanged =
          !_sameDateTime(_from, from) || !_sameDateTime(_to, to);

      if (periodChanged) {
        // mémorise la période courante
        _from = from;
        _to = to;

        if (_from == null && _to == null) {
          // Toute la base
          _all = await _dao.fetchAll();
        } else {
          _all = await _dao.fetchRange(from: _from, to: _to);
        }
      }

      _applyFilters(notify: !silent);
    } catch (e, st) {
      _setError(e, st);
      if (!silent) notifyListeners();
    }
  }

  /// Recharge la dernière période mémorisée, puis réapplique les filtres mémoire.
  Future<void> refresh({bool silent = false}) async {
    try {
      clearError();

      if (_from == null && _to == null) {
        _all = await _dao.fetchAll();
      } else {
        _all = await _dao.fetchRange(from: _from, to: _to);
      }
      _applyFilters(notify: !silent);
    } catch (e, st) {
      _setError(e, st);
      if (!silent) notifyListeners();
    }
  }

  void _applyFilters({bool notify = true}) {
    try {
      Iterable<Depense> it = _all;

      if (_fournisseurLike != null) {
        final q = _fournisseurLike!.toLowerCase();
        it = it.where((d) => d.fournisseur.toLowerCase().contains(q));
      }

      _filtered = it.toList();
      if (notify) notifyListeners();
    } catch (e, st) {
      _setError(e, st);
      if (notify) notifyListeners();
    }
  }

  bool _sameDateTime(DateTime? a, DateTime? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.isAtSameMomentAs(b);
  }

  // ───────────────────────────── CRUD ─────────────────────────────

  Future<void> addDepense(Depense d) async {
    try {
      clearError();
      await _dao.add(d);
      await refresh(silent: false);
    } catch (e, st) {
      _setError(e, st);
      notifyListeners();
    }
  }

  Future<void> updateDepense(Depense d) async {
    try {
      clearError();
      await _dao.update(d);
      await refresh(silent: false);
    } catch (e, st) {
      _setError(e, st);
      notifyListeners();
    }
  }

  Future<void> deleteDepense(String id) async {
    try {
      clearError();
      await _dao.delete(id);
      await refresh(silent: false);
    } catch (e, st) {
      _setError(e, st);
      notifyListeners();
    }
  }

  // ───────────── KPIs / Agrégats pour le dashboard ───────────────

  Future<double> totalAmount({required int year}) async {
    try {
      clearError();
      return await _dao.totalAmount(year: year);
    } catch (e, st) {
      _setError(e, st);
      // valeur de secours pour éviter un crash
      return 0.0;
    }
  }

  Future<int> invoiceCount({required int year}) async {
    try {
      clearError();
      return await _dao.invoiceCount(year: year);
    } catch (e, st) {
      _setError(e, st);
      // valeur de secours pour éviter un crash
      return 0;
    }
  }

  Future<List<DepenseSupplierSum>> sumBySupplier({
    required int year,
    required int month,
  }) async {
    try {
      clearError();
      return await _dao.sumBySupplier(year: year, month: month);
    } catch (e, st) {
      _setError(e, st);
      // valeur de secours pour éviter un crash
      return <DepenseSupplierSum>[];
    }
  }
}
