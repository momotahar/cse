import 'package:flutter/foundation.dart';

/// Modèle compatible avec l’ancien code (mêmes champs de base)
/// + ajout du retard (isLate / lateMinutes)
/// + id en String? (Firestore)
@immutable
class PresenceModel {
  final String? id; // Firestore doc id
  final String agent; // "Nom Prénom"
  final String reunion; // type / intitulé
  final String date; // "dd-MM-yyyy"
  final String time; // "HH:mm"

  // Nouveaux champs pour le retard
  final bool isLate; // l’agent est en retard ?
  final int lateMinutes; // minutes de retard (0 si à l’heure)

  // Métadonnées
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PresenceModel({
    this.id,
    required this.agent,
    required this.reunion,
    required this.date,
    required this.time,
    this.isLate = false,
    this.lateMinutes = 0,
    this.createdAt,
    this.updatedAt,
  });

  PresenceModel copyWith({
    String? id,
    String? agent,
    String? reunion,
    String? date,
    String? time,
    bool? isLate,
    int? lateMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PresenceModel(
      id: id ?? this.id,
      agent: agent ?? this.agent,
      reunion: reunion ?? this.reunion,
      date: date ?? this.date,
      time: time ?? this.time,
      isLate: isLate ?? this.isLate,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore -> modèle
  factory PresenceModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime? _ts(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      // Timestamp Firestore
      if (v.toString().contains('Timestamp')) {
        return (v as dynamic).toDate() as DateTime;
      }
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return PresenceModel(
      id: id,
      agent: (map['agent'] ?? '') as String,
      reunion: (map['reunion'] ?? '') as String,
      date: (map['date'] ?? '') as String,
      time: (map['time'] ?? '') as String,
      isLate: (map['is_late'] as bool?) ?? false,
      lateMinutes: (map['late_minutes'] as num?)?.toInt() ?? 0,
      createdAt: _ts(map['created_at']),
      updatedAt: _ts(map['updated_at']),
    );
  }

  /// modèle -> Firestore
  Map<String, dynamic> toMap() {
    final now = DateTime.now();
    return {
      'agent': agent,
      'reunion': reunion,
      'date': date,
      'time': time,
      'is_late': isLate,
      'late_minutes': lateMinutes,
      'created_at': createdAt ?? now,
      'updated_at': updatedAt ?? now,
      // 👉 Pas d’“id” dans les champs: Firestore gère l’id du document
    };
  }
}
