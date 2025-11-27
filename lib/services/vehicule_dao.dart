// lib/services/vehicule_dao.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vehicule.dart';

const String _kVehiculesCol = 'vehicules';

class VehiculeDAO {
  static final _col = FirebaseFirestore.instance.collection(_kVehiculesCol);

  // -------- Helpers --------
  static void _logError(String where, Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('[VehiculeDAO.$where] error: $error');
      debugPrint(stack.toString());
    }
  }

  static Vehicule _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? <String, dynamic>{};
    return Vehicule.fromMap(data, d.id); // <-- id Firestore (String)
  }

  static Map<String, dynamic> _toFirestore(
    Vehicule v, {
    bool isUpdate = false,
  }) {
    final m = Map<String, dynamic>.from(v.toMap());

    // normalisation défensive (tri/filtre)
    final immat = (m['immatriculation'] as String?)?.trim() ?? '';
    m['immatriculation'] = immat;
    m['immatriculation_norm'] = immat.toUpperCase().replaceAll(' ', '');

    if (isUpdate) {
      m['updated_at'] = FieldValue.serverTimestamp();
    } else {
      m['created_at'] = FieldValue.serverTimestamp();
    }
    return m;
  }

  // -------- READ --------
  static Future<List<Vehicule>> getAll() async {
    try {
      final snap = await _col.orderBy('immatriculation').get();
      return snap.docs.map(_fromDoc).toList(growable: false);
    } catch (e, st) {
      _logError('getAll', e, st);
      rethrow;
    }
  }

  static Future<Vehicule?> getById(String id) async {
    try {
      final d = await _col.doc(id).get();
      if (!d.exists) return null;
      return _fromDoc(d);
    } catch (e, st) {
      _logError('getById($id)', e, st);
      rethrow;
    }
  }

  // -------- WRITE --------
  /// Crée si `v.id == null`, sinon met à jour le doc existant.
  /// Renvoie toujours le `Vehicule` persisté (avec `id`).
  static Future<Vehicule> upsert(Vehicule v) async {
    try {
      if (v.id == null) {
        // CREATE (id auto Firestore)
        final ref = await _col.add(_toFirestore(v, isUpdate: false));
        final d = await ref.get();
        return _fromDoc(d);
      } else {
        // UPDATE
        await _col.doc(v.id).update(_toFirestore(v, isUpdate: true));
        final d = await _col.doc(v.id!).get();
        return _fromDoc(d);
      }
    } catch (e, st) {
      _logError('upsert', e, st);
      rethrow;
    }
  }

  static Future<void> delete(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e, st) {
      _logError('delete($id)', e, st);
      rethrow;
    }
  }

  // -------- STREAM --------
  static Stream<List<Vehicule>> watchAll() {
    try {
      return _col
          .orderBy('immatriculation')
          .snapshots()
          .map((q) => q.docs.map(_fromDoc).toList(growable: false));
    } catch (e, st) {
      _logError('watchAll', e, st);
      // flux de secours pour éviter un crash des listeners
      return const Stream<List<Vehicule>>.empty();
    }
  }
}
