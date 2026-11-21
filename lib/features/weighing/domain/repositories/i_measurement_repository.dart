import '../entities/weight_measurement.dart';

/// Contrat d'accès aux données des pesées.
///
/// Toute implémentation (SQLite locale, API distante, cache…) doit respecter
/// cette interface. Cela permet de remplacer la source de données sans toucher
/// à la logique métier ni à l'UI.
abstract class IMeasurementRepository {
  /// Insère une mesure et renvoie l'entité complétée avec son identifiant.
  Future<WeightMeasurement> insert(WeightMeasurement measurement);

  /// Met à jour une mesure existante (ex. ajout de l'impédance).
  Future<WeightMeasurement> update(WeightMeasurement measurement);

  /// Renvoie les mesures, de la plus récente à la plus ancienne.
  ///
  /// Si [profileId] est fourni, seules les pesées de ce profil sont renvoyées.
  Future<List<WeightMeasurement>> all({int? limit, int? profileId});

  /// Dernière mesure enregistrée (ou null).
  Future<WeightMeasurement?> latest({int? profileId});

  /// Mesures comprises entre [from] et [to], triées chronologiquement.
  Future<List<WeightMeasurement>> range(
    DateTime from,
    DateTime to, {
    int? profileId,
  });

  /// Supprime une mesure par son identifiant.
  Future<void> delete(int id);

  /// Supprime toutes les mesures, ou uniquement celles d'un profil.
  Future<void> deleteAll({int? profileId});
}
