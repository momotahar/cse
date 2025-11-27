import 'package:flutter/foundation.dart';

@immutable
class Reunion {
  final String? id;
  final DateTime date; // date/heure prévue de la réunion
  final String titre;
  final String? base; // ex: "Base Nord"
  final String? type; // ex: "OPS", "RH", ...
  final String? lieu; // ex: "Salle A"
  final String? commentaire;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Reunion({
    this.id,
    required this.date,
    required this.titre,
    this.base,
    this.type,
    this.lieu,
    this.commentaire,
    this.createdAt,
    this.updatedAt,
  });

  Reunion copyWith({
    String? id,
    DateTime? date,
    String? titre,
    String? base,
    String? type,
    String? lieu,
    String? commentaire,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Reunion(
      id: id ?? this.id,
      date: date ?? this.date,
      titre: titre ?? this.titre,
      base: base ?? this.base,
      type: type ?? this.type,
      lieu: lieu ?? this.lieu,
      commentaire: commentaire ?? this.commentaire,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Firestore <-map-> modèle
  factory Reunion.fromMap(Map<String, Object?> m, {String? id}) {
    DateTime? ts(Object? v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      // Timestamp (Firestore) -> DateTime
      if (v.toString().contains('Timestamp')) {
        return (v as dynamic).toDate() as DateTime;
      }
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return Reunion(
      id: id,
      date: ts(m['date']) ?? DateTime.now(),
      titre: (m['titre'] ?? '') as String,
      base: m['base'] as String?,
      type: m['type'] as String?,
      lieu: m['lieu'] as String?,
      commentaire: m['commentaire'] as String?,
      createdAt: ts(m['created_at']),
      updatedAt: ts(m['updated_at']),
    );
  }

  Map<String, Object?> toMap() {
    final now = DateTime.now();
    return {
      'date': date, // Firestore accepte DateTime -> Timestamp auto
      'titre': titre,
      'base': (base ?? '').trim().isEmpty ? null : base,
      'type': (type ?? '').trim().isEmpty ? null : type,
      'lieu': (lieu ?? '').trim().isEmpty ? null : lieu,
      'commentaire': (commentaire ?? '').trim().isEmpty ? null : commentaire,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
    };
  }
}
