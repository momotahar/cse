// lib/authz/feature_keys.dart
class FeatureKeys {
  static const vehicules = 'Vehicules';
  static const entretien = 'Entretien';
  static const kilometrage = 'Kilometrage';
  static const billetterie = 'Billetterie';
  static const incidents = 'Incidents';
  static const comptabilite = 'Comptabilite';
  static const modeles = 'Modeles';
  static const agents = 'Agents';
  static const filiales = 'Filiales';
  static const participations = 'Participations';
  static const statsParticipations = 'Stats_participations';
  static const adminAuthz = 'Autorisations'; // écran d’admin des droits

  static const all = <String>{
    vehicules,
    entretien,
    kilometrage,
    billetterie,
    incidents,
    comptabilite,
    modeles,
    agents,
    filiales,
    participations,
    statsParticipations,
    adminAuthz,
  };
}
