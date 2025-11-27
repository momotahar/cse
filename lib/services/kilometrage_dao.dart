import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/kilometrage.dart';

class KilometrageDAO {
  static final _col = FirebaseFirestore.instance.collection('kilometrages');

  static void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[KilometrageDAO.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<void> addOrUpdateKilometrage(Kilometrage k) async {
    try {
      final q = await _col
          .where('vehiculeId', isEqualTo: k.vehiculeId)
          .where('mois', isEqualTo: k.mois)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        await _col.add(k.toMap());
      } else {
        await _col.doc(q.docs.first.id).update(k.toMap());
      }
    } catch (e, st) {
      _logError('addOrUpdateKilometrage', e, st);
      rethrow;
    }
  }

  static Future<Kilometrage?> getDernierKilometrage(String vehiculeId) async {
    try {
      final q = await _col
          .where('vehiculeId', isEqualTo: vehiculeId)
          .orderBy('mois', descending: true)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return null;
      return Kilometrage.fromMap(q.docs.first.id, q.docs.first.data());
    } catch (e, st) {
      _logError('getDernierKilometrage($vehiculeId)', e, st);
      // on renvoie null pour éviter un crash côté UI
      return null;
    }
  }
}
