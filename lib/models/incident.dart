// lib/models/incident.dart
import 'package:flutter/foundation.dart';

@immutable
class Incident {
  final int? id;
  final String agentNom;
  final DateTime dateIncident; // jour de l'incident
  final String base;
  final bool arretTravail;
  final String? telephone;
  final DateTime? dateContact; // premier contact après incident (facultatif)
  final String? commentaire;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Incident({
    this.id,
    required this.agentNom,
    required this.dateIncident,
    required this.base,
    required this.arretTravail,
    this.telephone,
    this.dateContact,
    this.commentaire,
    this.createdAt,
    this.updatedAt,
  });

  Incident copyWith({
    int? id,
    String? agentNom,
    DateTime? dateIncident,
    String? base,
    bool? arretTravail,
    String? telephone,
    DateTime? dateContact,
    String? commentaire,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Incident(
      id: id ?? this.id,
      agentNom: agentNom ?? this.agentNom,
      dateIncident: dateIncident ?? this.dateIncident,
      base: base ?? this.base,
      arretTravail: arretTravail ?? this.arretTravail,
      telephone: telephone ?? this.telephone,
      dateContact: dateContact ?? this.dateContact,
      commentaire: commentaire ?? this.commentaire,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _toIsoDate(DateTime? d) =>
      d == null ? '' : d.toIso8601String().substring(0, 10); // YYYY-MM-DD

  static DateTime? _fromIsoDateNullable(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'agent_nom': agentNom,
      'date_incident': _toIsoDate(dateIncident),
      'base': base,
      'arret_travail': arretTravail ? 1 : 0,
      'telephone': telephone,
      'date_contact': _toIsoDate(dateContact),
      'commentaire': commentaire,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': updatedAt?.toIso8601String() ?? now,
    };
  }

  factory Incident.fromMap(Map<String, dynamic> m) {
    return Incident(
      id: m['id'] as int?,
      agentNom: m['agent_nom'] as String,
      dateIncident: DateTime.parse((m['date_incident'] as String)),
      base: m['base'] as String,
      arretTravail: (m['arret_travail'] as int) == 1,
      telephone: m['telephone'] as String?,
      dateContact: _fromIsoDateNullable(m['date_contact'] as String?),
      commentaire: m['commentaire'] as String?,
      createdAt: _fromIsoDateNullable(m['created_at'] as String?),
      updatedAt: _fromIsoDateNullable(m['updated_at'] as String?),
    );
  }
}
