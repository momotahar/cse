// lib/providers/parametres_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Parametres {
  final int seuilVidange;
  final int seuilFrein;

  Parametres({required this.seuilVidange, required this.seuilFrein});

  Map<String, dynamic> toMap() => {
    'seuilVidange': seuilVidange,
    'seuilFrein': seuilFrein,
  };

  factory Parametres.fromMap(Map<String, dynamic> map) => Parametres(
    seuilVidange: (map['seuilVidange'] ?? 10000) as int,
    seuilFrein: (map['seuilFrein'] ?? 10000) as int,
  );
}

class ParametresProvider extends ChangeNotifier {
  final _col = FirebaseFirestore.instance.collection('parametres');
  Parametres? parametres;

  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[ParametresProvider] Error: $error');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  Future<void> loadParametres() async {
    try {
      clearError();
      final snap = await _col.limit(1).get();

      if (snap.docs.isNotEmpty) {
        parametres = Parametres.fromMap(snap.docs.first.data());
      } else {
        parametres = Parametres(seuilVidange: 10000, seuilFrein: 10000);
        await _col.add(parametres!.toMap());
      }

      notifyListeners();
    } catch (e, st) {
      // En cas d’erreur Firestore, on garde l’ancien parametres si présent,
      // sinon on met une valeur par défaut en mémoire pour éviter les crashs.
      parametres ??= Parametres(seuilVidange: 10000, seuilFrein: 10000);
      _setError(e, st);
    }
  }

  Future<void> updateParametres(int seuilVidange, int seuilFrein) async {
    try {
      clearError();

      final snap = await _col.limit(1).get();
      if (snap.docs.isNotEmpty) {
        await _col.doc(snap.docs.first.id).update({
          'seuilVidange': seuilVidange,
          'seuilFrein': seuilFrein,
        });
      } else {
        await _col.add({
          'seuilVidange': seuilVidange,
          'seuilFrein': seuilFrein,
        });
      }

      parametres = Parametres(
        seuilVidange: seuilVidange,
        seuilFrein: seuilFrein,
      );
      notifyListeners();
    } catch (e, st) {
      // On met quand même à jour en mémoire pour que l’UI reste cohérente,
      // même si l’écriture Firestore a échoué.
      parametres = Parametres(
        seuilVidange: seuilVidange,
        seuilFrein: seuilFrein,
      );
      _setError(e, st);
    }
  }
}
