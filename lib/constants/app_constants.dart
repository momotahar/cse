// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

class AppConstants {
  static const Color primaryBlue = Color(0xFF2196F3); // Bleu clair (CSE)
  static const Color darkBlue = Color(0xFF0D47A1); // Bleu foncé (Suivi)
  static const Color backUpper = Color(0xFF292542);
  static const double HEURES_INITIALES_PAR_DEFAUT = 22.0;
  static const List<String> typesReunion = [
    'CSE',
    'CSE EXTRA',
    'CSSCT',
    'CSSCT EXTRA',
    'PRÉPA',
    'VISITES DÉPÔTS',
    'NAO',
    'AUTRES COMMISSIONS',
    'RP Base Sud',
    'RP Base Ouest',
    'RP Base Nord',
  ];

  static List<String> titulaires = [
    'MEDJABRA MEHDI',
    'BOUMEDIENE FADELA',
    'DIARRA BAHA',
    'SENINI MALIKA',
    'DBILI MOHAMED',
    'PIET NASSIMA',
    'MAVOUNZA CEDRIC',
    'SECK EL HADJ DAOUDA',
    'CURIER THIERRY',
    'SAIDI MABROUK',
  ];

  static List<String> suppleants = [
    'YATE IBRAHIM',
    'KEZZOUL SABRINA',
    'BOUAMRI OMAR',
    'IMOUNSSI SEBBA SOUHILA',
    'NADA MASHAB',
    'CAMARA MINTY',
    'MOHAMED OMAR',
    'CHILLAN PATRICK',
    'LESSAULT STEPHANE',
    'COLOMBO AXEL',
  ];
  final List<Map<String, dynamic>> keolisFilialesIdfJson = [
    {"abreviation": "KSVM", "designation": "Keolis Seine Val-de-Marne"},
    {"abreviation": "KSVV", "designation": "Keolis Seine Val-Vallée"},
    {"abreviation": "KSE", "designation": "Keolis Seine Essonne"},
    {"abreviation": "KSVB", "designation": "Keolis Seine Val-Briard"},
    {
      "abreviation": "KVYVS",
      "designation": "Keolis Vélizy-Vallée de la Bièvre",
    },
    {"abreviation": "KOVM", "designation": "Keolis Ouest Val-de-Marne"},
    {"abreviation": "KPVB", "designation": "Keolis Portes & Val-de-Brie"},
    {"abreviation": "KVOE", "designation": "Keolis Val-d’Essonne 2 Vallées"},
    {"abreviation": "KVOIS", "designation": "Keolis Val-Oise Seine"},
    {"abreviation": "KVDO", "designation": "Keolis Val-d’Oise"},
    {"abreviation": "KKF", "designation": "Keolis Kréteil Fun"},
    {"abreviation": "KCIF", "designation": "Keolis CIF"},
  ];
  // final FilialeModel keolisFiliale = FilialeModel(
  //   id: 1,
  //   abreviation: "KEOLIS",
  //   designation: "Keolis Île-de-France",
  // );

  final List<Map<String, dynamic>> agentsJson = [
    // Titulaires
    {
      "name": "MEDJABRA",
      "surname": "MEHDI",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "BOUMEDIENE",
      "surname": "FADELA",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "DIARRA",
      "surname": "BAHA",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "SENINI",
      "surname": "MALIKA",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "DBILI",
      "surname": "MOHAMED",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "PIET",
      "surname": "NASSIMA",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "MAVOUNZA",
      "surname": "CEDRIC",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "SECK",
      "surname": "EL HADJ DAOUDA",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "CURIER",
      "surname": "THIERRY",
      "statut": "Titulaire",
      "filiale_id": 1,
    },
    {
      "name": "SAIDI",
      "surname": "MABROUK",
      "statut": "Titulaire",
      "filiale_id": 1,
    },

    // Suppléants
    {
      "name": "YATE",
      "surname": "IBRAHIM",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "KEZZOUL",
      "surname": "SABRINA",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "BOUAMRI",
      "surname": "OMAR",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "IMOUNSSI",
      "surname": "SEBBA SOUHILA",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "NADA",
      "surname": "MASHAB",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "CAMARA",
      "surname": "MINTY",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "MOHAMED",
      "surname": "OMAR",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "CHILLAN",
      "surname": "PATRICK",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "LESSAULT",
      "surname": "STEPHANE",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
    {
      "name": "COLOMBO",
      "surname": "AXEL",
      "statut": "Suppléant",
      "filiale_id": 1,
    },
  ];
}
