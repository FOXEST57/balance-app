# Contrat de données — Balance App (V1.0.0)

Ce document décrit l'ensemble des entités métier, leurs champs, et le schéma de
base de données SQLite. Il sert de référence pour l'intégration future de
cette application dans le projet global de perte de poids et réadaptation
physico-nutritionnelle.

---

## 1. Aperçu de l'architecture des données

```
┌─────────────────────────────────────────────────────────────┐
│                     Domaine (domain)                         │
│  Entités pures (sans dépendance externe) — contrat fixe      │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                 Interfaces (domain/repositories)             │
│  IMeasurementRepository · IProfileRepository                 │
│  ISettingsRepository   · IActivityRepository                 │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│              Implémentation (data) — SQLite local            │
│  MeasurementRepository · ProfileRepository                   │
│  SettingsRepository   · ActivityRepository                   │
└─────────────────────────────────────────────────────────────┘
```

> **Principe d'intégration** : les consommateurs (UI, services) ne dépendent
> **que des interfaces**. Pour brancher une source distante (API du projet
> global), il suffit de créer une nouvelle implémentation des 4 interfaces et
> de modifier les factories dans `lib/core/providers.dart`. Aucun autre fichier
> n'a besoin d'être touché.

---

## 2. Entités du domaine

### 2.1 `UserProfile` — Profil utilisateur

**Fichier** : `lib/features/weighing/domain/entities/user_profile.dart`
**Table** : `profiles`

| Champ | Type | Description |
|---|---|---|
| `id` | `int?` | Identifiant (null tant que non persisté) |
| `name` | `String` | Nom du profil (défaut : « Mon profil ») |
| `isActive` | `bool` | Profil actuellement sélectionné |
| `sex` | `Sex` | `male` / `female` — facteur BIA (1/0) |
| `age` | `int` | Âge en années |
| `heightCm` | `double` | Taille en cm |
| `activityLevel` | `ActivityLevel` | Niveau d'activité (0-4) |
| `targetWeightKg` | `double` | Objectif de poids en kg |
| `manualFatPercent` | `double?` | % de graisse forcé manuellement |
| `manualMusclePercent` | `double?` | % de muscle forcé manuellement |
| `manualWaterPercent` | `double?` | % d'eau forcé manuellement |

**Enums associées :**

- `Sex` : `male` (1) / `female` (0)
- `ActivityLevel` : `sedentary` (1.2), `light` (1.375), `moderate` (1.55),
  `active` (1.725), `veryActive` (1.9) — facteurs multiplicatifs du BMR.

---

### 2.2 `WeightMeasurement` — Pesée

**Fichier** : `lib/features/weighing/domain/entities/weight_measurement.dart`
**Table** : `measurements`

| Champ | Type | Description |
|---|---|---|
| `id` | `int?` | Identifiant |
| `profileId` | `int?` | FK vers `profiles.id` (cascade delete) |
| `timestamp` | `DateTime` | Date/heure de la pesée |
| `composition` | `BodyComposition` | Composition corporelle détaillée |
| `source` | `MeasurementSource` | `ble` / `simulation` / `manual` |
| `waistCm` | `double?` | Tour de taille en cm (optionnel) |
| `note` | `String?` | Note libre |

---

### 2.3 `BodyComposition` — Composition corporelle

**Fichier** : `lib/features/weighing/domain/entities/body_composition.dart`
*(Pas de table dédiée — stockée à plat dans `measurements`)*

| Champ | Type | Description |
|---|---|---|
| `weightKg` | `double` | Poids en kg |
| `fatPercent` | `double?` | % de masse grasse |
| `fatMassKg` | `double?` | Masse grasse en kg |
| `musclePercent` | `double?` | % de masse musculaire |
| `muscleMassKg` | `double?` | Masse musculaire en kg |
| `waterPercent` | `double` | % d'eau corporelle |
| `waterMassKg` | `double` | Masse d'eau en kg |
| `boneMassKg` | `double` | Masse osseuse en kg |
| `bmi` | `double` | Indice de masse corporelle |
| `bmrKcal` | `double` | Métabolisme de base (kcal/jour) |
| `impedanceOhm` | `int?` | Impédance brute mesurée par la balance |

> Les champs `fatPercent`/`fatMassKg`/`musclePercent`/`muscleMassKg` sont
> `null` si la pesée ne comporte ni impédance ni pourcentages manuels.
> Aucune valeur n'est inventée.

---

### 2.4 `ActivityEntry` — Entrée d'activité

**Fichier** : `lib/features/activity/domain/entities/activity_entry.dart`
**Table** : `activity_entries`

| Champ | Type | Description |
|---|---|---|
| `id` | `int?` | Identifiant |
| `day` | `int` | Minuit local en ms epoch (clé de journée) |
| `steps` | `int?` | Nombre de pas |
| `activeKcal` | `double?` | Calories actives dépensées (kcal) |
| `sessionMinutes` | `int?` | Durée de la séance (min) |
| `activityType` | `ActivityType?` | Type d'activité |
| `meetsGoal` | `int?` | 1 si l'objectif journalier est atteint |
| `note` | `String?` | Note libre |
| `createdAt` | `int` | Date de création en ms epoch |

**Enum `ActivityType`** (avec valeurs MET pour le calcul calorique) :

| Valeur | Label | MET |
|---|---|---|
| `walking` | Marche | 3.5 |
| `running` | Course | 8.0 |
| `cycling` | Vélo | 7.5 |
| `swimming` | Natation | 8.0 |
| `strengthTraining` | Musculation | 5.0 |
| `yoga` | Yoga | 3.0 |
| `hiking` | Randonnée | 6.0 |
| `dancing` | Danse | 5.0 |
| `steps` | Pas (auto) | 3.5 |

**Formule calorique** : `kcal = MET × poids(kg) × durée(h)`

---

### 2.5 `ActivityGoals` — Objectifs d'activité

**Fichier** : `lib/features/activity/domain/entities/activity_goals.dart`
**Stockage** : table `settings`, clé `activity_goals` (format `"steps;kcal;minutes"`)

| Champ | Type | Défaut | Description |
|---|---|---|---|
| `steps` | `int` | 10000 | Objectif de pas/jour |
| `kcal` | `int` | 300 | Objectif de kcal actives/jour |
| `minutes` | `int` | 30 | Objectif de minutes d'activité/jour |

---

## 3. Schéma de base de données SQLite

**Base** : `balance_cardio.db`

### Table `profiles`

```sql
CREATE TABLE profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 0,
  sex TEXT NOT NULL,                 -- 'male' | 'female'
  age INTEGER NOT NULL,
  height_cm REAL NOT NULL,
  activity_level INTEGER NOT NULL,   -- 0..4 (ActivityLevel.index)
  target_weight_kg REAL NOT NULL,
  manual_fat_percent REAL,
  manual_muscle_percent REAL,
  manual_water_percent REAL,
  updated_at INTEGER NOT NULL
);
```

### Table `measurements`

```sql
CREATE TABLE measurements (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  profile_id INTEGER REFERENCES profiles(id) ON DELETE CASCADE,
  timestamp INTEGER NOT NULL,        -- ms epoch
  weight_kg REAL NOT NULL,
  impedance_ohm INTEGER,
  fat_percent REAL,
  fat_kg REAL,
  muscle_percent REAL,
  muscle_kg REAL,
  water_percent REAL NOT NULL,
  water_kg REAL NOT NULL,
  bone_kg REAL NOT NULL,
  bmi REAL NOT NULL,
  bmr_kcal REAL NOT NULL,
  waist_cm REAL,
  source TEXT NOT NULL,              -- 'ble' | 'simulation' | 'manual'
  note TEXT
);
CREATE INDEX idx_measurements_timestamp ON measurements(timestamp DESC);
```

### Table `activity_entries`

```sql
CREATE TABLE activity_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  day INTEGER NOT NULL,              -- minuit local en ms epoch
  steps INTEGER,
  active_kcal REAL,
  session_minutes INTEGER,
  activity_type TEXT,                -- ActivityType.name
  meets_goal INTEGER,
  note TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX idx_activity_day ON activity_entries(day DESC);
```

### Table `settings` (clé/valeur)

```sql
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
```

**Clés utilisées :**

| Clé | Valeur | Description |
|---|---|---|
| `last_scale_id` | String | Identifiant BLE de la dernière balance |
| `last_scale_name` | String | Nom de la dernière balance |
| `auto_connect_enabled` | `'true'`/`'false'` | Reconnexion auto |
| `reminder_enabled` | `'true'`/`'false'` | Rappel de pesée actif |
| `reminder_time` | `'HH:MM'` | Heure du rappel |
| `reminder_day_of_week` | `'1'`..`'7'` | Jour du rappel (1=lundi) |
| `reminder_repeat` | `'weekly'`/`'biweekly'`/`'monthly'` | Fréquence |
| `activity_goals` | `'steps;kcal;minutes'` | Objectifs d'activité |
| `activity_baseline_day` | ms epoch | Référence minuit du pédomètre |
| `activity_baseline_steps` | int | Compteur de pas de référence |

---

## 4. Interfaces de repository (contrat d'accès aux données)

### `IMeasurementRepository`

```dart
Future<WeightMeasurement> insert(WeightMeasurement measurement);
Future<WeightMeasurement> update(WeightMeasurement measurement);
Future<List<WeightMeasurement>> all({int? limit, int? profileId});
Future<WeightMeasurement?> latest({int? profileId});
Future<List<WeightMeasurement>> range(DateTime from, DateTime to, {int? profileId});
Future<void> delete(int id);
Future<void> deleteAll({int? profileId});
```

### `IProfileRepository`

```dart
Future<List<UserProfile>> all();
Future<UserProfile?> loadActive();
Future<UserProfile> save(UserProfile profile);
Future<void> setActive(int id);
Future<void> delete(int id);
```

### `IActivityRepository`

```dart
Future<ActivityEntry> insert(ActivityEntry entry);
Future<void> update(ActivityEntry entry);
Future<void> delete(int id);
Future<List<ActivityEntry>> forDay(DateTime day);
Future<List<ActivityEntry>> between(DateTime from, DateTime to);
Future<ActivityEntry?> stepsEntryForDay(DateTime day);
Future<ActivityEntry> upsertStepsForDay({
  required DateTime day,
  required int steps,
  required double kcal,
  required int minutes,
});
```

### `ISettingsRepository`

```dart
Future<String?> read(String key);
Future<void> write(String key, String value);
```

---

## 5. Points d'injection (Riverpod)

Tous les providers sont déclarés dans `lib/core/providers.dart` :

| Provider | Type exposé | Implémentation injectée |
|---|---|---|
| `profileRepositoryProvider` | `IProfileRepository` | `ProfileRepository` (SQLite) |
| `measurementRepositoryProvider` | `IMeasurementRepository` | `MeasurementRepository` (SQLite) |
| `settingsRepositoryProvider` | `ISettingsRepository` | `SettingsRepository` (SQLite) |
| `activityRepositoryProvider` | `IActivityRepository` | `ActivityRepository` (SQLite) |

> Pour basculer vers une API distante, remplacer la factory de chaque provider
> par une instance pointant vers l'API du projet global.

---

## 6. Calculs clés à connaître

### BIA (Bioelectrical Impedance Analysis)
- **Graisse %** (Deurenberg) : `1.2 × BMI + 0.23 × âge - 10.8 × sex - 5.4`
- **Muscle %** (Lee) : `0.401 × poids(kg) + 3.825 × sex - 0.071 × âge - 5.415`
- **Coefficients correcteurs** (calibrés sur mesures pro) :
  - Graisse : `×0.879`
  - Muscle : `×0.546`
- Les pourcentages manuels (`manualFatPercent`, etc.) priment sur les formules.

### Calories d'activité
- `kcal = MET × poids(kg) × durée(heures)`
- Pour les pas : `kcal = 0.0005 × poids(kg) × pas`

### Indices dérivés
- `BMI = poids(kg) / taille(m)²`
- `BMR` (Mifflin-St Jeor) :
  - Homme : `10 × poids + 6.25 × taille - 5 × âge + 5`
  - Femme : `10 × poids + 6.25 × taille - 5 × âge - 161`
