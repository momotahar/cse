// lib/models/vehicule.dart
import 'package:flutter/foundation.dart';

@immutable
class Vehicule {
  /// ID Firestore (préféré)
  final String? id;

  /// Ancien ID numérique si déjà présent historiquement
  final int? legacyId;

  // ---- Champs existants ----
  final String immatriculation;
  final String? dateEntree;
  final String? marque;
  final String? modele;
  final String? baseGeo; // 'base_geographique'
  final String? collaborateur;
  final String? statut;
  final String? prochainCtTech; // 'prochain_ct'

  // ---- Champs supplémentaires ----
  final bool? kitSecurite; // dispo / pas dispo
  final int? kmRef; // dernier km d’entretien (référence)
  final int?
  kmMois; // km relevé du mois (ne remplace pas kmRef automatiquement)

  const Vehicule({
    this.id,
    this.legacyId,
    required this.immatriculation,
    this.dateEntree,
    this.marque,
    this.modele,
    this.baseGeo,
    this.collaborateur,
    this.statut,
    this.prochainCtTech,
    this.kitSecurite,
    this.kmRef,
    this.kmMois,
  });

  Vehicule copyWith({
    String? id,
    int? legacyId,
    String? immatriculation,
    String? dateEntree,
    String? marque,
    String? modele,
    String? baseGeo,
    String? collaborateur,
    String? statut,
    String? prochainCtTech,
    bool? kitSecurite,
    int? kmRef,
    int? kmMois,
  }) {
    return Vehicule(
      id: id ?? this.id,
      legacyId: legacyId ?? this.legacyId,
      immatriculation: immatriculation ?? this.immatriculation,
      dateEntree: dateEntree ?? this.dateEntree,
      marque: marque ?? this.marque,
      modele: modele ?? this.modele,
      baseGeo: baseGeo ?? this.baseGeo,
      collaborateur: collaborateur ?? this.collaborateur,
      statut: statut ?? this.statut,
      prochainCtTech: prochainCtTech ?? this.prochainCtTech,
      kitSecurite: kitSecurite ?? this.kitSecurite,
      kmRef: kmRef ?? this.kmRef,
      kmMois: kmMois ?? this.kmMois,
    );
  }

  /// Map -> Modèle (docId = id Firestore si fourni par le DAO)
  factory Vehicule.fromMap(Map<String, dynamic> map, [String? docId]) {
    // legacyId
    int? legacy;
    final rawId = map['id'];
    if (rawId is int) {
      legacy = rawId;
    } else if (rawId is String) {
      final p = int.tryParse(rawId);
      if (p != null) legacy = p;
    }

    // id Firestore prioritaire si connu
    String? strId = docId;
    if (strId == null) {
      if (rawId is String) {
        strId = rawId;
      } else if (rawId is int) {
        strId = rawId.toString();
      }
    }

    int? _asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return Vehicule(
      id: strId,
      legacyId: legacy,
      immatriculation: (map['immatriculation'] ?? '').toString(),
      dateEntree: map['date_entree'] as String?,
      marque: map['marque'] as String?,
      modele: map['modele'] as String?,
      baseGeo: map['base_geographique'] as String?,
      collaborateur: map['collaborateur'] as String?,
      statut: map['statut'] as String?,
      prochainCtTech: map['prochain_ct'] as String?,
      kitSecurite: map['kit_securite'] as bool?,
      kmRef: _asInt(map['km_ref']),
      kmMois: _asInt(map['km_mois']),
    );
  }

  /// Modèle -> Map (clés historiques conservées)
  Map<String, dynamic> toMap() {
    return {
      if (legacyId != null) 'id': legacyId, // compat ancien schéma
      'immatriculation': immatriculation,
      'date_entree': dateEntree,
      'marque': marque,
      'modele': modele,
      'base_geographique': baseGeo,
      'collaborateur': collaborateur,
      'statut': statut,
      'prochain_ct': prochainCtTech,
      'kit_securite': kitSecurite ?? false,
      'km_ref': kmRef,
      'km_mois': kmMois,
    };
  }
}
