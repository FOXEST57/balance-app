import '../entities/activity_entry.dart';

/// Contrat d'accès aux données d'activité physique.
abstract class IActivityRepository {
  /// Insère une entrée d'activité et renvoie l'entité complétée.
  Future<ActivityEntry> insert(ActivityEntry entry);

  /// Met à jour une entrée d'activité existante.
  Future<void> update(ActivityEntry entry);

  /// Supprime une entrée par son identifiant.
  Future<void> delete(int id);

  /// Toutes les entrées d'une journée donnée (triées par date de création).
  Future<List<ActivityEntry>> forDay(DateTime day);

  /// Toutes les entrées entre [from] (inclus) et [to] (exclu).
  Future<List<ActivityEntry>> between(DateTime from, DateTime to);

  /// Retourne l'entrée « pas » pour une journée donnée (ou null).
  Future<ActivityEntry?> stepsEntryForDay(DateTime day);

  /// Met à jour (ou crée) l'entrée « pas » de la journée.
  Future<ActivityEntry> upsertStepsForDay({
    required DateTime day,
    required int steps,
    required double kcal,
    required int minutes,
  });
}
