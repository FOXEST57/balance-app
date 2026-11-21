import '../entities/user_profile.dart';

/// Contrat d'accès aux données des profils utilisateur.
abstract class IProfileRepository {
  /// Tous les profils, le profil actif en premier.
  Future<List<UserProfile>> all();

  /// Profil actuellement sélectionné (ou null si aucun profil).
  Future<UserProfile?> loadActive();

  /// Crée ou met à jour un profil et renvoie sa version persistée.
  Future<UserProfile> save(UserProfile profile);

  /// Définit [id] comme profil actif et désactive les autres.
  Future<void> setActive(int id);

  /// Supprime un profil. Les pesées rattachées sont supprimées par cascade.
  Future<void> delete(int id);
}
