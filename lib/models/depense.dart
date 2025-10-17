import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class Depense {
  final String? id;
  final DateTime date; // date de facture
  final String fournisseur;
  final String libelle;
  final double montantTtc;
  final String? numeroFacture;

  const Depense({
    this.id,
    required this.date,
    required this.fournisseur,
    required this.libelle,
    required this.montantTtc,
    this.numeroFacture,
  });

  /// Parsing robuste depuis une Map Firestore ou locale.
  /// Priorité au champ `date_iso` (String ISO). Fallback sur `date` (Timestamp/DateTime).
  factory Depense.fromMap(Map<String, Object?> m) {
    // --- id ---
    final String? id = m['id'] is String ? m['id'] as String? : null;

    // --- date ---
    DateTime? parsedDate;
    final rawIso = m['date_iso'];
    if (rawIso is String && rawIso.isNotEmpty) {
      parsedDate = DateTime.tryParse(rawIso);
    }
    if (parsedDate == null) {
      final rawDate = m['date'];
      if (rawDate is Timestamp) parsedDate = rawDate.toDate();
      if (rawDate is DateTime) parsedDate = rawDate;
    }
    parsedDate ??= DateTime.now(); // sécurité minimale

    // --- montant ---
    double parseMontant(Object? v) {
      if (v is num) return v.toDouble();
      if (v is String) {
        final s = v.replaceAll(',', '.').trim();
        return double.tryParse(s) ?? 0.0;
      }
      return 0.0;
    }

    return Depense(
      id: id,
      date: parsedDate,
      fournisseur: (m['fournisseur'] ?? '') as String,
      libelle: (m['libelle'] ?? '') as String,
      montantTtc: parseMontant(m['montant_ttc']),
      numeroFacture: m['numero_facture'] as String?,
    );
  }

  /// Map pour Firestore. On garde `date_iso` (String ISO) comme dans tes requêtes.
  Map<String, Object?> toMap() => {
    'id': id,
    'date_iso': date.toIso8601String(),
    'fournisseur': fournisseur,
    'libelle': libelle,
    'montant_ttc': montantTtc,
    'numero_facture': numeroFacture,
  };

  Depense copyWith({
    String? id,
    DateTime? date,
    String? fournisseur,
    String? libelle,
    double? montantTtc,
    String? numeroFacture,
  }) {
    return Depense(
      id: id ?? this.id,
      date: date ?? this.date,
      fournisseur: fournisseur ?? this.fournisseur,
      libelle: libelle ?? this.libelle,
      montantTtc: montantTtc ?? this.montantTtc,
      numeroFacture: numeroFacture ?? this.numeroFacture,
    );
  }

  @override
  String toString() =>
      'Depense(id: $id, date: $date, fournisseur: $fournisseur, libelle: $libelle, montantTtc: $montantTtc, numeroFacture: $numeroFacture)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Depense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          fournisseur == other.fournisseur &&
          libelle == other.libelle &&
          montantTtc == other.montantTtc &&
          numeroFacture == other.numeroFacture;

  @override
  int get hashCode =>
      Object.hash(id, date, fournisseur, libelle, montantTtc, numeroFacture);
}
