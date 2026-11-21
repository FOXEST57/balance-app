# Diffusion & Historique — Balance App

Ce document décrit la chaîne de diffusion de l'application **Balance**
(Android), la procédure de publication d'une nouvelle version, ainsi que
l'historique des versions publiées.

---

## 1. Informations générales

| Élément | Valeur |
| --- | --- |
| Nom de l'application | Balance |
| Éditeur | KreaCode |
| Identifiant (package) | `com.kreacode.balance` |
| Plateforme cible | Android (iOS en préparation) |
| Version courante | `1.0.2+3` (voir `pubspec.yaml`) |
| Dépôt source | https://github.com/FOXEST57/balance-app (public) |
| Page de téléchargement | https://foxest57.github.io/balance-app/ |
| Release APK | https://github.com/FOXEST57/balance-app/releases/tag/v1.0.0 |

---

## 2. Chaîne de diffusion actuelle (test par QR code)

En attendant la publication sur le Google Play Store, l'application est
distribuée par lien direct :

```
.github (branche main)
   └── docs/index.html        →  GitHub Pages (page de téléchargement)
                                       │
                                       ▼
                          Bouton « Télécharger l'appli »
                                       │
                                       ▼
   GitHub Release v1.0.0  ──►  app-release.apk  (asset téléchargeable)
```

- **Page de téléchargement** : `docs/index.html` (déployée automatiquement
  par GitHub Pages depuis la branche `main`). Elle affiche le QR code, le
  bouton de téléchargement, les instructions d'installation et le SHA-256 de
  contrôle.
- **APK** : hébergée comme *asset* de la release `v1.0.0`. Le fichier local
  de travail est `download.html` (copie miroir de `docs/index.html`).
- **QR codes** générés à la racine du dépôt :
  - `download_balance_v1.png` → lien direct vers l'APK ;
  - `download_balance_page.png` → lien vers la page de téléchargement.

> **Important pour les testeurs** : l'APK doit être signée avec **le même
> keystore** entre deux versions pour permettre la mise à jour **sans
> désinstallation**. En cas de changement de keystore, l'ancienne version doit
> être désinstallée au préalable.

---

## 3. Signature (keystore de release)

| Élément | Valeur |
| --- | --- |
| Fichier keystore | `android/app/release.keystore` |
| Alias | `balance` |
| Mot de passe | `Balance@2026!Secure` |
| Configuration | `android/key.properties` (référencé dans `android/app/build.gradle.kts`) |

> ⚠️ **À conserver précieusement** : ce keystore et son mot de passe sont
> indispensables pour publier les futures mises à jour (Play Store inclus).
> La perte du keystore rend impossible la mise à jour d'une application déjà
> publiée.

---

## 4. Procédure de publication d'une nouvelle version

1. **Incrémenter la version** dans `pubspec.yaml`
   (ex. `version: 1.0.3+4` — le numéro après `+` est le `versionCode`).
2. **Recompiler l'APK release** :
   ```
   flutter build apk --release
   ```
   Sortie : `build/app/outputs/flutter-apk/app-release.apk`.
   En cas d'erreur de verrou `R.jar` : arrêter les processus Java/Gradle,
   supprimer le dossier `build/`, puis relancer.
3. **Calculer le SHA-256** de l'APK :
   ```
   Get-FileHash -Algorithm SHA256 build\app\outputs\flutter-apk\app-release.apk
   ```
4. **Remplacer l'APK sur la release GitHub** :
   ```
   gh release delete-asset v1.0.0 app-release.apk --repo FOXEST57/balance-app --yes
   gh release upload v1.0.0 build\app\outputs\flutter-apk\app-release.apk --repo FOXEST57/balance-app
   ```
5. **Mettre à jour `docs/index.html`** (et `download.html`) : version affichée
   et SHA-256.
6. **Publier la page** :
   ```
   git add docs/index.html download.html
   git commit -m "..."
   git push origin main
   ```

---

## 5. Historique des versions

### v1.0.2+3 — Section « Bientôt disponible » retirée
- **Pesée** : suppression du bloc « Bientôt disponible / Activité du jour »
  sur le tableau de bord. L'activité est déjà accessible via l'onglet
  « Activité » de la barre de navigation ; ce raccourci redondant a été retiré.
- Suppression du widget `activity_preview_card.dart` (devenu inutile) et du
  paramètre `onOpenActivity` de `DashboardPage`.
- SHA-256 de l'APK : `a99431be93e6aa7cd52228e52147321e7879b041e890fbc638b8f778f7fd676d`

### v1.0.1+2 — Correctif barre de navigation
- **Affichage** : correction du chevauchement de la barre de navigation
  (Pesée, Suivi, Historique, Activité, Profil) avec la barre système Android
  sur certains téléphones.
  - La barre de navigation est désormais protégée par un `SafeArea`.
  - Le bas de chaque page réserve la hauteur de la barre système
    (`MediaQuery.padding.bottom`) en plus de la marge de la barre d'appli.
- SHA-256 de l'APK : `186369488a1563d3addf8465929d3419d0f453e82534f5f9d42e5de17fb7ce35`

### v1.0.0+1 — Version initiale distribuée
- Première version diffusée aux testeurs par QR code.
- Nettoyage des données personnelles : la base de données démarre
  **vierge** (aucun profil ni mesure pré-remplis). Le profil par défaut est
  créé au premier lancement par `ProfilesNotifier` avec des valeurs génériques
  (voir §6).
- SHA-256 de l'APK : `a1e4c59d4627d39149ff7cd0552fa9ac3e8a4a011a70680834e4fd8d3cc87115`

---

## 6. Confidentialité : base de données vierge

Pour la diffusion publique, **aucune donnée personnelle n'est embarquée**
dans l'application :

- `AppDatabase._onCreate()` crée les tables **vides** (aucun profil, aucune
  mesure).
- Au premier lancement, `ProfilesNotifier` (`lib/core/providers.dart`) crée un
  profil générique à partir de `UserProfile.defaults` :

  | Champ | Valeur par défaut |
  | --- | --- |
  | Nom | « Mon profil » |
  | Sexe | Homme |
  | Âge | 30 ans |
  | Taille | 175 cm |
  | Objectif de poids | 70 kg |

  L'utilisateur renseigne ensuite ses propres valeurs dans l'écran Profil.

---

## 7. Préparation Google Play Store (à venir)

- Génération du bundle Android App Bundle :
  ```
  flutter build appbundle --release
  ```
  Sortie : `build/app/outputs/bundle/release/app-release.aab`.
- Éléments à préparer pour la fiche Play Store :
  - icône 512 × 512 px ;
  - captures d'écran ;
  - graphique de présentation (« feature graphic ») ;
  - description et texte de la fiche.
- Compte développeur Google Play : disponible.
- Compte Apple Developer : en attente (pour la version iOS).

---

## 8. État des lieux & suite

**Terminé**
- Signature de release (keystore + `build.gradle.kts`).
- APK release compilée et hébergée (release GitHub).
- Page de téléchargement + QR codes.
- Nettoyage des données personnelles (base vierge).
- Correctifs d'affichage (barre de navigation).

**En attente**
- Publication sur le Google Play Store (AAB + fiche).
- Version iOS (compte Apple Developer).
- Intégration éventuelle dans le projet global de perte de poids
  (voir `docs/data_contract.md`).
