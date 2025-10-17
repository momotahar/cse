// import 'package:flutter/foundation.dart';
// import '../models/presence_model.dart';
// import '../services/presence_dao.dart';

// /// Provider “présences”
// /// Remplace l’usage précédent d’`AppDataProvider` pour cette partie.
// class PresenceProvider extends ChangeNotifier {
//   final PresenceDao _dao;

//   PresenceProvider({PresenceDao? dao}) : _dao = dao ?? PresenceDao();

//   List<PresenceModel> _presences = [];
//   List<PresenceModel> get presences => _presences;

//   // (optionnel) derniers filtres en mémoire si tu veux les garder
//   String? _reunionLike;
//   DateTime? _exactDate; // si tu veux filtrer localement sur une date

//   /// Charge tout (appelé au démarrage des écrans)
//   Future<void> fetchPresences() async {
//     _presences = await _dao.fetchAll();
//     _applyFilters(notify: true);
//   }

//   /// Ajout
//   Future<void> addPresence(PresenceModel p) async {
//     await _dao.add(p);
//     await fetchPresences();
//   }

//   /// Update
//   Future<void> updatePresence(PresenceModel p) async {
//     await _dao.update(p);
//     await fetchPresences();
//   }

//   /// Delete
//   Future<void> deletePresence(String id) async {
//     await _dao.delete(id);
//     await fetchPresences();
//   }

//   /// (Optionnel) filtres mémoire – pour mimer l’ancien usage côté écran
//   void setFilters({String? reunionLike, DateTime? exactDate}) {
//     _reunionLike = (reunionLike ?? '').trim().isEmpty ? null : reunionLike;
//     _exactDate = exactDate;
//     _applyFilters();
//   }

//   void _applyFilters({bool notify = true}) {
//     Iterable<PresenceModel> it = _presences;

//     if (_reunionLike != null) {
//       final q = _reunionLike!.toLowerCase();
//       it = it.where((p) => p.reunion.toLowerCase().contains(q));
//     }
//     if (_exactDate != null) {
//       final y = _exactDate!.year;
//       final m = _exactDate!.month.toString().padLeft(2, '0');
//       final d = _exactDate!.day.toString().padLeft(2, '0');
//       final key = '$d-$m-$y'; // même format “dd-MM-yyyy”
//       it = it.where((p) => p.date == key);
//     }

//     _presences = it.toList();
//     if (notify) notifyListeners();
//   }
// }
import 'package:flutter/foundation.dart';
import 'package:cse_kch/models/presence_model.dart';
import 'package:cse_kch/services/presence_dao.dart';

class PresenceProvider extends ChangeNotifier {
  final PresenceDao _dao;

  PresenceProvider({PresenceDao? dao}) : _dao = dao ?? PresenceDao();

  bool isLoading = false;
  List<PresenceModel> _all = [];
  List<PresenceModel> get presences => _all;

  /// Recharge tout (appelée au démarrage et après modifs)
  Future<void> fetchPresences() async {
    isLoading = true;
    notifyListeners();
    try {
      _all = await _dao.fetchAll();

      // Tri côté UI si tu veux un affichage cohérent (date desc + time)
      _all.sort((a, b) {
        int cmp;
        try {
          cmp = _parse(a.date).compareTo(_parse(b.date));
        } catch (_) {
          cmp = 0;
        }
        if (cmp != 0) return -cmp; // desc
        return b.time.compareTo(a.time);
      });
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Ajoute UNE présence (un doc Firestore)
  Future<String> addPresence(PresenceModel p) async {
    final id = await _dao.add(p);
    // Option: rafraîchir immédiatement
    await fetchPresences();
    return id;
  }

  /// Ajoute PLUSIEURS présences (ex: pour plusieurs agents sélectionnés)
  Future<void> addManyPresences(List<PresenceModel> items) async {
    await _dao.addMany(items);
    await fetchPresences();
  }

  Future<void> deletePresence(String id) async {
    await _dao.delete(id);
    await fetchPresences();
  }

  Future<void> updatePresence(PresenceModel p) async {
    await _dao.update(p);
    await fetchPresences();
  }

  DateTime _parse(String ddMMyyyy) {
    final parts = ddMMyyyy.split('-'); // dd-MM-yyyy
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);
    return DateTime(y, m, d);
  }
}
