/// Contrat d'accès au magasin clé/valeur des paramètres.
abstract class ISettingsRepository {
  /// Lit la valeur associée à [key], ou null si absente.
  Future<String?> read(String key);

  /// Écrit [value] sous la clé [key] (écrase si existante).
  Future<void> write(String key, String value);
}
