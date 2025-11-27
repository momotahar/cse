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

  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[IncidentProvider] Error: $error');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Chargement
  Future<void> loadIncidents({bool silent = false}) async {
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      clearError();
      _all = await IncidentDAO.getAll();
      // Si une période était active, on la respecte; sinon, tout.
      if (_periodYear != null && _periodMonth != null) {
        await filterByMonthYear(month: _periodMonth!, year: _periodYear!);
      } else if (_periodYear != null) {
        await filterByYear(_periodYear!);
      } else {
        incidents = List.of(_all);
      }
    } catch (e, st) {
      _setError(e, st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadIncidents(silent: true);

  // ──────────────────────────────────────────────────────────────────────────
  // Périodes
  Future<void> filterByYear(int year) async {
    try {
      clearError();
      _periodYear = year;
      _periodMonth = null;
      incidents = _all.where((e) => e.dateIncident.year == year).toList();
      notifyListeners();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> filterByMonthYear({
    required int month,
    required int year,
  }) async {
    try {
      clearError();
      _periodYear = year;
      _periodMonth = month;
      incidents = _all
          .where(
            (e) => e.dateIncident.year == year && e.dateIncident.month == month,
          )
          .toList();
      notifyListeners();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Filtres additionnels (s’appliquent sur la période courante)
  Future<void> setFilters({
    String? base, // si null => ne pas filtrer par base
    bool? arretTravail, // null => tous
    String? agentLike, // null/'' => pas de filtre
  }) async {
    try {
      clearError();

      // Point de départ = période courante (déjà dans incidents)
      var list = (_periodYear != null || _periodMonth != null)
          ? List<Incident>.from(
              _all.where(
                (e) =>
                    (_periodYear == null ||
                        e.dateIncident.year == _periodYear) &&
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
    } catch (e, st) {
      _setError(e, st);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // KPIs pour le dashboard

  /// Total d’incidents (si `year` est fourni => restreint)
  Future<int> totalCount({int? year}) async {
    try {
      clearError();
      if (year == null) return _all.length;
      return _all.where((e) => e.dateIncident.year == year).length;
    } catch (e, st) {
      _setError(e, st);
      return 0;
    }
  }

  /// Répartition arrêt OUI/NON (optionnellement pour une année)
  Future<IncidentArretSplit> arretSplit({int? year}) async {
    try {
      clearError();
      Iterable<Incident> src = _all;
      if (year != null) {
        src = src.where((e) => e.dateIncident.year == year);
      }
      final yes = src.where((e) => e.arretTravail).length;
      final no = src.length - yes;
      return IncidentArretSplit(yes: yes, no: no);
    } catch (e, st) {
      _setError(e, st);
      return IncidentArretSplit(yes: 0, no: 0);
    }
  }

  /// Compte par base, pour un (year, month) donné (si `year`/`month` null => tous)
  Future<List<IncidentBaseCount>> countByBase({int? year, int? month}) async {
    try {
      clearError();
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
    } catch (e, st) {
      _setError(e, st);
      return <IncidentBaseCount>[];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CRUD
  Future<void> addIncident(Incident inc) async {
    try {
      clearError();
      await IncidentDAO.insert(inc);
      await refresh();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> updateIncident(Incident inc) async {
    try {
      clearError();
      await IncidentDAO.update(inc);
      await refresh();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> deleteIncident(int id) async {
    try {
      clearError();
      await IncidentDAO.delete(id);
      await refresh();
    } catch (e, st) {
      _setError(e, st);
    }
  }
}

// Tu as déjà ces classes quelque part dans ton code.
// Je les laisse ici en rappel de la signature attendue.
class IncidentArretSplit {
  final int yes;
  final int no;
  IncidentArretSplit({required this.yes, required this.no});
}

class IncidentBaseCount {
  final String base;
  final int count;
  IncidentBaseCount({required this.base, required this.count});
}
