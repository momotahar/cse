import 'package:flutter/foundation.dart';
import 'package:cse_kch/models/presence_model.dart';
import 'package:cse_kch/services/presence_dao.dart';

class PresenceProvider extends ChangeNotifier {
  final PresenceDao _dao;

  PresenceProvider({PresenceDao? dao}) : _dao = dao ?? PresenceDao();

  bool isLoading = false;
  List<PresenceModel> _all = [];
  List<PresenceModel> get presences => _all;

  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[PresenceProvider] Error: $error');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  /// Recharge tout (appelée au démarrage et après modifs)
  Future<void> fetchPresences() async {
    isLoading = true;
    notifyListeners();
    try {
      clearError();
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
    } catch (e, st) {
      _setError(e, st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Ajoute UNE présence (un doc Firestore)
  Future<String> addPresence(PresenceModel p) async {
    try {
      clearError();
      final id = await _dao.add(p);
      await fetchPresences();
      return id;
    } catch (e, st) {
      _setError(e, st);
      // valeur de secours pour éviter un crash
      return '';
    }
  }

  /// Ajoute PLUSIEURS présences (ex: pour plusieurs agents sélectionnés)
  Future<void> addManyPresences(List<PresenceModel> items) async {
    try {
      clearError();
      await _dao.addMany(items);
      await fetchPresences();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> deletePresence(String id) async {
    try {
      clearError();
      await _dao.delete(id);
      await fetchPresences();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> updatePresence(PresenceModel p) async {
    try {
      clearError();
      await _dao.update(p);
      await fetchPresences();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  DateTime _parse(String ddMMyyyy) {
    final parts = ddMMyyyy.split('-'); // dd-MM-yyyy
    final d = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final y = int.parse(parts[2]);
    return DateTime(y, m, d);
  }
}
