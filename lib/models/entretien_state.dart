import 'package:flutter/foundation.dart';

@immutable
class EntretienState {
  final int vehiculeId; // même ID int que tes docs "vehicules"
  final int kmRefVidange; // baseline vidange (km_entr le jour de l’entretien)
  final int kmRefFrein; // baseline freins
  final DateTime updatedAt;

  const EntretienState({
    required this.vehiculeId,
    required this.kmRefVidange,
    required this.kmRefFrein,
    required this.updatedAt,
  });

  EntretienState copyWith({
    int? kmRefVidange,
    int? kmRefFrein,
    DateTime? updatedAt,
  }) => EntretienState(
    vehiculeId: vehiculeId,
    kmRefVidange: kmRefVidange ?? this.kmRefVidange,
    kmRefFrein: kmRefFrein ?? this.kmRefFrein,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory EntretienState.fromMap(Map<String, dynamic> m) => EntretienState(
    vehiculeId: (m['vehiculeId'] as num).toInt(),
    kmRefVidange: (m['kmRefVidange'] as num?)?.toInt() ?? 0,
    kmRefFrein: (m['kmRefFrein'] as num?)?.toInt() ?? 0,
    updatedAt: _ts(m['updated_at']) ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'vehiculeId': vehiculeId,
    'kmRefVidange': kmRefVidange,
    'kmRefFrein': kmRefFrein,
    'updated_at': updatedAt,
  };
}

DateTime? _ts(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v.toString().contains('Timestamp'))
    return (v as dynamic).toDate() as DateTime;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
