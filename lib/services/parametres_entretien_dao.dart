import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/parametres_entretien.dart';

class ParametresEntretienDAO {
  static final _col = FirebaseFirestore.instance.collection(
    'parametres_entretien',
  );

  static void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[ParametresEntretienDAO.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  static Future<ParametresEntretien> getParametres() async {
    const fallback = ParametresEntretien(
      seuilVidange: 10000,
      seuilFrein: 10000,
    );

    try {
      final doc = await _col.doc('default').get();
      if (!doc.exists) {
        await _col.doc('default').set({
          'seuilVidange': 10000,
          'seuilFrein': 10000,
        });
        return fallback;
      }
      final data = doc.data();
      if (data == null) return fallback;
      return ParametresEntretien.fromMap(data);
    } catch (e, st) {
      _logError('getParametres', e, st);
      // valeur par défaut en cas d’erreur Firestore
      return fallback;
    }
  }

  static Future<void> updateParametres(ParametresEntretien p) async {
    try {
      await _col.doc('default').update(p.toMap());
    } catch (e, st) {
      _logError('updateParametres', e, st);
      rethrow;
    }
  }
}
