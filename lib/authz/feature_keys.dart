// lib/authz/feature_keys.dart
class FeatureKeys {
  static const billetterie = 'billetterie';
  static const vehicules = 'vehicules';
  static const entretien = 'entretien';
  static const kilometrage = 'kilometrage';
  static const incidents = 'incidents';
  static const comptabilite = 'comptabilite';
  static const modeles = 'modeles';
  static const agents = 'agents';
  static const filiales = 'filiales';
  static const participations = 'participations';
  static const statsParticipations = 'statsParticipations'; // UI seulement
  static const adminAuthz = 'adminAuthz'; // UI seulement
  static const planningSyndical = 'planningSyndical';
  static const depotsAdmin = 'depotsAdmin';

  static const all = <String>{
    billetterie,
    vehicules,
    entretien,
    kilometrage,
    incidents,
    comptabilite,
    modeles,
    agents,
    filiales,
    participations,
    statsParticipations,
    adminAuthz,
    planningSyndical,
    depotsAdmin,
  };
}
