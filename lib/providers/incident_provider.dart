import 'package:flutter/foundation.dart';
import '../models/incident.dart';
import '../services/incident_dao.dart';

class IncidentProvider extends ChangeNotifier {
  bool isLoading = false;

  /// Dataset complet (tous incidents chargés)
  List<Incident> _all = [];

  /// Dataset courant visible (après période + filtres)
  List<Incident> incidents = [];

  /// Dernière période appliquée pour `setFilters`
  int? _periodYear;
  int? _periodMonth;

  // ──────────────────────────────────────────────────────────────────────────
  // Chargement
  Future<void> loadIncidents({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      _all = await IncidentDAO.getAll();
      // Si une période était active, on la respecte; sinon, tout.
      if (_periodYear != null && _periodMonth != null) {
        await filterByMonthYear(month: _periodMonth!, year: _periodYear!);
      } else if (_periodYear != null) {
        await filterByYear(_periodYear!);
      } else {
        incidents = List.of(_all);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadIncidents(silent: true);

  // ──────────────────────────────────────────────────────────────────────────
  // Périodes
  Future<void> filterByYear(int year) async {
    _periodYear = year;
    _periodMonth = null;
    incidents = _all.where((e) => e.dateIncident.year == year).toList();
    notifyListeners();
  }

  Future<void> filterByMonthYear({
    required int month,
    required int year,
  }) async {
    _periodYear = year;
    _periodMonth = month;
    incidents = _all
        .where(
          (e) => e.dateIncident.year == year && e.dateIncident.month == month,
        )
        .toList();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Filtres additionnels (s’appliquent sur la période courante)
  Future<void> setFilters({
    String? base, // si null => ne pas filtrer par base
    bool? arretTravail, // null => tous
    String? agentLike, // null/'' => pas de filtre
  }) async {
    // Point de départ = période courante (déjà dans incidents)
    var list = (_periodYear != null || _periodMonth != null)
        ? List<Incident>.from(
            _all.where(
              (e) =>
                  (_periodYear == null || e.dateIncident.year == _periodYear) &&
                  (_periodMonth == null ||
                      e.dateIncident.month == _periodMonth),
            ),
          )
        : List<Incident>.from(_all);

    if ((base ?? '').isNotEmpty) {
      final b = base!.trim().toLowerCase();
      list = list.where((e) => e.base.trim().toLowerCase() == b).toList();
    }

    if (arretTravail != null) {
      list = list.where((e) => e.arretTravail == arretTravail).toList();
    }

    if ((agentLike ?? '').isNotEmpty) {
      final q = agentLike!.trim().toLowerCase();
      list = list.where((e) => e.agentNom.toLowerCase().contains(q)).toList();
    }

    incidents = list;
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KPIs pour le dashboard

  /// Total d’incidents (si `year` est fourni => restreint)
  Future<int> totalCount({int? year}) async {
    if (year == null) return _all.length;
    return _all.where((e) => e.dateIncident.year == year).length;
  }

  /// Répartition arrêt OUI/NON (optionnellement pour une année)
  Future<IncidentArretSplit> arretSplit({int? year}) async {
    Iterable<Incident> src = _all;
    if (year != null) {
      src = src.where((e) => e.dateIncident.year == year);
    }
    final yes = src.where((e) => e.arretTravail).length;
    final no = src.length - yes;
    return IncidentArretSplit(yes: yes, no: no);
  }

  /// Compte par base, pour un (year, month) donné (si `year`/`month` null => tous)
  Future<List<IncidentBaseCount>> countByBase({int? year, int? month}) async {
    Iterable<Incident> src = _all;
    if (year != null) {
      src = src.where((e) => e.dateIncident.year == year);
    }
    if (month != null) {
      src = src.where((e) => e.dateIncident.month == month);
    }

    final Map<String, int> map = {};
    for (final e in src) {
      final key = e.base.trim();
      map[key] = (map[key] ?? 0) + 1;
    }
    final list =
        map.entries
            .map((e) => IncidentBaseCount(base: e.key, count: e.value))
            .toList()
          ..sort(
            (a, b) => a.base.toLowerCase().compareTo(b.base.toLowerCase()),
          );
    return list;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CRUD
  Future<void> addIncident(Incident inc) async {
    await IncidentDAO.insert(inc);
    await refresh();
  }

  Future<void> updateIncident(Incident inc) async {
    await IncidentDAO.update(inc);
    await refresh();
  }

  Future<void> deleteIncident(int id) async {
    await IncidentDAO.delete(id);
    await refresh();
  }
}
