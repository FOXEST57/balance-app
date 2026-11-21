/// Fonctions utilitaires de formatage.
///
/// Règle produit : tous les prix / mesures sont affichés avec exactement
/// 2 décimales, et le symbole d'unité reste collé à la valeur.
library;

/// Formate un nombre en kilogrammes avec 2 décimales, ex : « 72.50 kg ».
String fmtKg(double value) => '${value.toStringAsFixed(2)} kg';

/// Formate un poids facultatif : « 72.50 kg », ou « — » si la valeur est
/// inconnue (pesée sans impédance ni pourcentage manuel).
String fmtKgOpt(double? value) => value == null ? '—' : fmtKg(value);

/// Formate un pourcentage avec 2 décimales, ex : « 18.50 % ».
String fmtPct(double value) => '${value.toStringAsFixed(2)} %';

/// Formate une énergie en kcal (entier), ex : « 1 754 kcal ».
String fmtKcal(double value) => '${value.toStringAsFixed(0)} kcal';

/// Formate un IMC avec 1 décimale, ex : « 24.3 ».
String fmtBmi(double value) => value.toStringAsFixed(1);

/// Formate une longueur en centimètres, ex : « 146 cm ».
String fmtCm(double value) => '${value.toStringAsFixed(0)} cm';

/// Formate une variation signée en kg, ex : « +0.20 kg » / « -0.40 kg ».
String fmtDeltaKg(double value) {
  final String sign = value >= 0 ? '+' : '-';
  return '$sign${value.abs().toStringAsFixed(2)} kg';
}

/// Formate une date courte, ex : « 05/03/2026 ».
String fmtDate(DateTime d) =>
    '${_p(d.day)}/${_p(d.month)}/${d.year}';

/// Formate une date + heure, ex : « 05/03/2026 08:42 ».
String fmtDateTime(DateTime d) => '${fmtDate(d)} ${_p(d.hour)}:${_p(d.minute)}';

/// Formate une heure, ex : « 08:42 ».
String fmtTime(DateTime d) => '${_p(d.hour)}:${_p(d.minute)}';

/// Nom de jour abrégé en français.
String fmtWeekdayShort(DateTime d) {
  const List<String> days = <String>['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
  return days[d.weekday - 1];
}

/// Nom de mois abrégé en français.
String fmtMonthShort(DateTime d) {
  const List<String> months = <String>[
    'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
    'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
  ];
  return months[d.month - 1];
}

String _p(int v) => v.toString().padLeft(2, '0');
