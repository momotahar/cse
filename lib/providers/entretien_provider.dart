// lib/providers/entretien_provider.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'parametres_provider.dart';

enum AlerteCouleur { none, orange, rouge }

class EntretienProvider extends ChangeNotifier {
  final _col = FirebaseFirestore.instance.collection('entretiens');

  Map<String, int> derniersKmVidange = {};
  Map<String, int> derniersKmFrein = {};

  String? _lastError;
  String? get lastError => _lastError;

  void _setError(Object error, StackTrace stack) {
    _lastError = error.toString();
    if (kDebugMode) {
      debugPrint('[EntretienProvider] Error: $error');
      debugPrint(stack.toString());
    }
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
  }

  Future<void> enregistrerKilometrage(String vehiculeId, int kmMois) async {
    try {
      clearError();
      await _col.add({
        'vehiculeId': vehiculeId,
        'kmMois': kmMois,
        'date': DateTime.now(),
      });
      notifyListeners();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  Future<void> enregistrerEntretien({
    required String vehiculeId,
    required String type, // 'vidange' | 'frein'
    required int kmEntr,
  }) async {
    try {
      clearError();
      await _col.add({
        'vehiculeId': vehiculeId,
        'type': type,
        'kmEntr': kmEntr,
        'date': DateTime.now(),
      });

      if (type == 'vidange') {
        derniersKmVidange[vehiculeId] = kmEntr;
      } else {
        derniersKmFrein[vehiculeId] = kmEntr;
      }

      notifyListeners();
    } catch (e, st) {
      _setError(e, st);
    }
  }

  _AlerteResult evaluer({
    required String vehiculeId,
    required int kmMois,
    DateTime? prochainCtTech,
  }) {
    try {
      clearError();

      final now = DateTime.now();
      final diffCt = prochainCtTech != null
          ? prochainCtTech.difference(now).inDays
          : 9999;

      AlerteCouleur ct = AlerteCouleur.none;
      if (diffCt <= 0) {
        ct = AlerteCouleur.rouge;
      } else if (diffCt <= 60) {
        ct = AlerteCouleur.orange;
      }

      final kmVid = derniersKmVidange[vehiculeId] ?? 0;
      final kmFr = derniersKmFrein[vehiculeId] ?? 0;

      int seuilVidange = 10000;
      int seuilFrein = 10000;

      // Ces valeurs peuvent venir du ParametresProvider
      // si tu veux, tu peux les injecter ici à la création du provider.

      AlerteCouleur vid = AlerteCouleur.none;
      AlerteCouleur fr = AlerteCouleur.none;

      if ((kmMois - kmVid) > seuilVidange) vid = AlerteCouleur.rouge;
      if ((kmMois - kmFr) > seuilFrein) fr = AlerteCouleur.rouge;

      return _AlerteResult(ct: ct, vidange: vid, frein: fr);
    } catch (e, st) {
      _setError(e, st);
      return _AlerteResult(
        ct: AlerteCouleur.none,
        vidange: AlerteCouleur.none,
        frein: AlerteCouleur.none,
      );
    }
  }
}

class _AlerteResult {
  final AlerteCouleur ct;
  final AlerteCouleur vidange;
  final AlerteCouleur frein;

  _AlerteResult({required this.ct, required this.vidange, required this.frein});
}
