// lib/models/reglement.dart
class Reglement {
  final int? id;
  final int commandeId;

  /// Doit être l’un de : CHEQUE, CB, VIREMENT, ESPECES, AUTRES
  final String mode;
  final String? numeroCheque; // requis si mode == CHEQUE
  final double montant;
  final String dateIso; // ISO-8601 (yyyy-MM-ddTHH:mm:ss.mmm)

  Reglement({
    this.id,
    required this.commandeId,
    required this.mode,
    this.numeroCheque,
    required this.montant,
    required this.dateIso,
  });

  Reglement copyWith({
    int? id,
    int? commandeId,
    String? mode,
    String? numeroCheque,
    double? montant,
    String? dateIso,
  }) {
    return Reglement(
      id: id ?? this.id,
      commandeId: commandeId ?? this.commandeId,
      mode: mode ?? this.mode,
      numeroCheque: numeroCheque ?? this.numeroCheque,
      montant: montant ?? this.montant,
      dateIso: dateIso ?? this.dateIso,
    );
  }

  DateTime get date => DateTime.parse(dateIso);
  bool get isCheque => mode == 'CHEQUE';

  factory Reglement.fromMap(Map<String, dynamic> m) {
    return Reglement(
      id: m['id'] as int?,
      commandeId: m['commande_id'] as int,
      mode: (m['mode'] as String).toUpperCase(),
      numeroCheque: m['numero_cheque'] as String?,
      montant: (m['montant'] as num).toDouble(),
      dateIso: m['date_iso'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commande_id': commandeId,
      'mode': mode,
      'numero_cheque': numeroCheque,
      'montant': montant,
      'date_iso': dateIso,
    };
  }
}
