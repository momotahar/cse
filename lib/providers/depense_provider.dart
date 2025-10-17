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
  }

  /// Recharge la dernière période mémorisée, puis réapplique les filtres mémoire.
  Future<void> refresh({bool silent = false}) async {
    if (_from == null && _to == null) {
      _all = await _dao.fetchAll();
    } else {
      _all = await _dao.fetchRange(from: _from, to: _to);
    }
    _applyFilters(notify: !silent);
  }

  void _applyFilters({bool notify = true}) {
    Iterable<Depense> it = _all;

    if (_fournisseurLike != null) {
      final q = _fournisseurLike!.toLowerCase();
      it = it.where((d) => d.fournisseur.toLowerCase().contains(q));
    }

    _filtered = it.toList();
    if (notify) notifyListeners();
  }

  bool _sameDateTime(DateTime? a, DateTime? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    return a.isAtSameMomentAs(b);
  }

  // ───────────────────────────── CRUD ─────────────────────────────

  Future<void> addDepense(Depense d) async {
    await _dao.add(d);
    await refresh();
  }

  Future<void> updateDepense(Depense d) async {
    await _dao.update(d);
    await refresh();
  }

  Future<void> deleteDepense(String id) async {
    await _dao.delete(id);
    await refresh();
  }

  // ───────────── KPIs / Agrégats pour le dashboard ───────────────

  Future<double> totalAmount({required int year}) =>
      _dao.totalAmount(year: year);

  Future<int> invoiceCount({required int year}) =>
      _dao.invoiceCount(year: year);

  Future<List<DepenseSupplierSum>> sumBySupplier({
    required int year,
    required int month,
  }) => _dao.sumBySupplier(year: year, month: month);
}
