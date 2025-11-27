import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SyndicEvent {
  final String id;
  final String type; // ex : CSE, DP, CSSCT, ...
  final DateTime date; // Jour "local" (sans heure)
  final String time; // "HH:mm"
  final String depotId;
  final String depotLabel;
  final String depotAdresse;
  final List<String> agentIds;
  final List<String> agentNoms;
  final String status; // planifie | annule | tenu
  final String createdBy;

  const SyndicEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.time,
    required this.depotId,
    required this.depotLabel,
    required this.depotAdresse,
    required this.agentIds,
    required this.agentNoms,
    required this.status,
    required this.createdBy,
  });

  /// Stockage Firestore
  /// - `date` en UTC, jour uniquement
  /// - `time` au format "HH:mm"
  Map<String, dynamic> toMap() => {
    'type': type,
    'date': Timestamp.fromDate(DateTime.utc(date.year, date.month, date.day)),
    'time': time,
    'depot_id': depotId,
    'depot_label': depotLabel,
    'depot_adresse': depotAdresse,
    'agent_ids': agentIds,
    'agent_noms': agentNoms,
    'status': status,
    'created_by': createdBy,
    'updated_at': FieldValue.serverTimestamp(),
  };

  factory SyndicEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    // date Firestore → local, jour-only
    final ts =
        (m['date'] as Timestamp?) ??
        Timestamp.fromDate(DateTime.utc(1970, 1, 1));
    final local = ts.toDate().toLocal();
    final dayOnly = DateTime(local.year, local.month, local.day);

    final timeStr = (m['time'] ?? '09:00').toString().padLeft(5, '0');

    return SyndicEvent(
      id: d.id,
      type: (m['type'] ?? '').toString(),
      date: dayOnly,
      time: timeStr,
      depotId: (m['depot_id'] ?? '').toString(),
      depotLabel: (m['depot_label'] ?? '').toString(),
      depotAdresse: (m['depot_adresse'] ?? '').toString(),
      agentIds: (m['agent_ids'] as List? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      agentNoms: (m['agent_noms'] as List? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
      status: (m['status'] ?? 'planifie').toString(),
      createdBy: (m['created_by'] ?? '').toString(),
    );
  }

  /// Utilitaires d’heure (compatibilité avec l’ancien code)
  TimeOfDay get timeOfDay {
    final parts = time.split(':');
    final h = int.tryParse(parts.elementAt(0)) ?? 9;
    final m = int.tryParse(parts.elementAt(1)) ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  int get timeH => timeOfDay.hour;
  int get timeM => timeOfDay.minute;

  /// Heure lisible "HH:mm"
  String get timeLabel =>
      '${timeH.toString().padLeft(2, '0')}:${timeM.toString().padLeft(2, '0')}';

  /// Construit un DateTime précis (jour + heure locale)
  DateTime get startDateTime =>
      DateTime(date.year, date.month, date.day, timeH, timeM);

  /// Copie immuable si besoin
  SyndicEvent copyWith({
    String? id,
    String? type,
    DateTime? date,
    String? time,
    String? depotId,
    String? depotLabel,
    String? depotAdresse,
    List<String>? agentIds,
    List<String>? agentNoms,
    String? status,
    String? createdBy,
  }) {
    return SyndicEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      time: time ?? this.time,
      depotId: depotId ?? this.depotId,
      depotLabel: depotLabel ?? this.depotLabel,
      depotAdresse: depotAdresse ?? this.depotAdresse,
      agentIds: agentIds ?? this.agentIds,
      agentNoms: agentNoms ?? this.agentNoms,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
