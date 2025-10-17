// lib/models/commande.dart
import 'package:flutter/foundation.dart';

@immutable
class Commande {
  final int? id;

  /// Date stockée en base au format ISO 8601 (yyyy-MM-ddTHH:mm:ss.mmmZ…)
  final String dateIso;

  final int billetId;
  final String billetLibelle;

  /// Prix CSE unitaire au moment de la commande (snapshot)
  final double prixCse;

  final int qte;
  final String agent;
  final String email;
  final String base;

  const Commande({
    required this.id,
    required this.dateIso,
    required this.billetId,
    required this.billetLibelle,
    required this.prixCse,
    required this.qte,
    required this.agent,
    required this.email,
    required this.base,
  });

  /// Confort
  DateTime get date => DateTime.parse(dateIso);
  double get montantCse => prixCse * qte;

  /// copyWith qui accepte bien `dateIso`
  Commande copyWith({
    int? id,
    String? dateIso,
    int? billetId,
    String? billetLibelle,
    double? prixCse,
    int? qte,
    String? agent,
    String? email,
    String? base,
  }) {
    return Commande(
      id: id ?? this.id,
      dateIso: dateIso ?? this.dateIso,
      billetId: billetId ?? this.billetId,
      billetLibelle: billetLibelle ?? this.billetLibelle,
      prixCse: prixCse ?? this.prixCse,
      qte: qte ?? this.qte,
      agent: agent ?? this.agent,
      email: email ?? this.email,
      base: base ?? this.base,
    );
  }

  // ---- Mapping DB (colonnes alignées avec CommandeDAO/DBService) ----
  factory Commande.fromMap(Map<String, dynamic> m) {
    return Commande(
      id: m['id'] as int?,
      dateIso: m['date_iso'] as String,
      billetId: m['billet_id'] as int,
      billetLibelle: m['billet_libelle'] as String,
      prixCse: (m['prix_cse'] as num).toDouble(),
      qte: m['qte'] as int,
      agent: m['agent'] as String,
      email: m['email'] as String,
      base: m['base'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date_iso': dateIso,
      'billet_id': billetId,
      'billet_libelle': billetLibelle,
      'prix_cse': prixCse,
      'qte': qte,
      'agent': agent,
      'email': email,
      'base': base,
    };
  }
}
