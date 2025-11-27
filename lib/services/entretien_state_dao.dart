import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/entretien_state.dart';

const _kCol = 'entretien_state';
final _col = FirebaseFirestore.instance.collection(_kCol);

class EntretienStateDAO {
  static String _docId(int vehiculeId) => vehiculeId.toString();

  static void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[EntretienStateDAO.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<EntretienState?> getByVehicule(int vehiculeId) async {
    try {
      final d = await _col.doc(_docId(vehiculeId)).get();
      if (!d.exists) return null;
      final m = d.data() ?? {};
      m['vehiculeId'] = vehiculeId;
      return EntretienState.fromMap(m);
    } catch (e, st) {
      _logError('getByVehicule($vehiculeId)', e, st);
      // En cas d’erreur on renvoie null pour ne pas faire crasher l’app
      return null;
    }
  }

  static Future<void> upsert(EntretienState s) async {
    try {
      await _col
          .doc(_docId(s.vehiculeId))
          .set(s.toMap(), SetOptions(merge: true));
    } catch (e, st) {
      _logError('upsert(${s.vehiculeId})', e, st);
      rethrow;
    }
  }
}
