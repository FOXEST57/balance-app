import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/navigation/home_shell.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../weighing/domain/entities/user_profile.dart';
import '../../weighing/application/notification_service.dart';
import '../../weighing/presentation/widgets/ble_scan_sheet.dart';

/// Écran « Profil & Connexion » : gestion du profil BIA, de l'objectif de poids,
/// de l'appairage de la balance et des rappels de pesée.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<UserProfile>> async = ref.watch(profilesProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace s) => Center(
        child: Text(
          'Erreur : $e',
          style: const TextStyle(color: AppColors.danger),
        ),
      ),
      data: (List<UserProfile> profiles) {
        if (profiles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final UserProfile active = profiles.firstWhere(
          (UserProfile p) => p.isActive,
          orElse: () => profiles.first,
        );
        return _ProfileContent(profiles: profiles, active: active);
      },
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profiles, required this.active});

  final List<UserProfile> profiles;
  final UserProfile active;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, kHomeNavBarClearance),
      children: <Widget>[
        Text(
          'Profil & Connexion',
          style: AppTheme.numeric(22, weight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'Paramètres indispensables au calcul impédancemétrique',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        const SectionHeader(
          title: 'Profils',
          subtitle: 'Sélectionnez, créez ou supprimez un profil',
          accent: AppColors.violet,
        ),
        const SizedBox(height: 12),
        _ProfileSelector(profiles: profiles, active: active),

        const SizedBox(height: 22),
        const SectionHeader(title: 'Balance', accent: AppColors.cyan),
        SizedBox(height: 12),
        const _ScaleSection(),

        const SizedBox(height: 22),
        const SectionHeader(
          title: 'Profil corporel',
          subtitle: 'Sexe, âge, taille et objectif',
          accent: AppColors.emerald,
        ),
        SizedBox(height: 12),
        _ProfileForm(key: ValueKey<int?>(active.id), profile: active),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Sélecteur de profils
// -----------------------------------------------------------------------------

class _ProfileSelector extends ConsumerWidget {
  const _ProfileSelector({required this.profiles, required this.active});

  final List<UserProfile> profiles;
  final UserProfile active;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final String? name = await _promptName(
      context,
      title: 'Nouveau profil',
      initial: '',
      hint: 'Prénom du profil',
    );
    if (name == null || name.trim().isEmpty) return;
    final UserProfile created = await ref
        .read(profilesProvider.notifier)
        .save(
          UserProfile.defaults.copyWith(name: name.trim(), isActive: false),
        );
    if (created.id != null) {
      await ref.read(profilesProvider.notifier).setActive(created.id!);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil « ${created.name} » créé.')),
      );
    }
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final String? name = await _promptName(
      context,
      title: 'Renommer le profil',
      initial: profile.name,
      hint: 'Prénom du profil',
    );
    if (name == null || name.trim().isEmpty) return;
    await ref
        .read(profilesProvider.notifier)
        .save(profile.copyWith(name: name.trim()));
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: const Text('Supprimer ce profil ?'),
        content: Text(
          'Le profil « ${profile.name} » et toutes ses pesées seront définitivement supprimés.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (profile.id != null) {
      await ref.read(profilesProvider.notifier).remove(profile.id!);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      accent: AppColors.violet,
      child: Column(
        children: <Widget>[
          for (final UserProfile p in profiles)
            _ProfileTile(
              profile: p,
              isActive: p.id == active.id,
              onActivate: p.id == null
                  ? null
                  : () =>
                        ref.read(profilesProvider.notifier).setActive(p.id!),
              onRename: () => _rename(context, ref, p),
              onDelete: profiles.length > 1
                  ? () => _delete(context, ref, p)
                  : null,
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.violet,
                side: BorderSide(
                  color: AppColors.violet.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _create(context, ref),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Ajouter un profil'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
  });

  final UserProfile profile;
  final bool isActive;
  final VoidCallback? onActivate;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isActive ? null : onActivate,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(
              isActive
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isActive ? AppColors.violet : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? 'Profil actif'
                        : '${profile.sex.label} • ${profile.age} ans • ${profile.heightCm.toStringAsFixed(0)} cm',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Renommer',
              onPressed: onRename,
              icon: const Icon(
                Icons.edit_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Supprimer',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Boîte de dialogue de saisie d'un nom de profil.
Future<String?> _promptName(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
}) {
  final TextEditingController controller = TextEditingController(
    text: initial,
  );
  return showDialog<String>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceAlt,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (String v) => Navigator.of(ctx).pop(v),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: const Text('Valider'),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// Section balance (connexion + rappels de pesée)
// -----------------------------------------------------------------------------

class _ScaleSection extends ConsumerWidget {
  const _ScaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WeighingState w = ref.watch(weighingProvider);
    final WeighingNotifier notifier = ref.read(weighingProvider.notifier);

    return Column(
      children: <Widget>[
        GlassCard(
          accent: AppColors.cyan,
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.monitor_weight_rounded,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      w.connected?.name ??
                          w.savedScaleName ??
                          'Aucune balance appairée',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      w.connected != null
                          ? '${w.connected!.remoteId}  •  RSSI ${w.connected!.rssi} dBm'
                          : (w.savedScaleName != null
                                ? 'Balance mémorisée — reconnexion auto'
                                : 'Appairez votre Little Balance 8661'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => showBleScanSheet(context),
                icon: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
        ),
        if (w.isConnected) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: notifier.disconnect,
              icon: const Icon(Icons.bluetooth_disabled_rounded, size: 18),
              label: const Text('Déconnecter'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        GlassCard(
          accent: AppColors.violet,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: w.reminderEnabled,
                activeThumbColor: AppColors.violet,
                title: const Text(
                  'Rappel de pesée',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text(
                  'Recevoir une notification pour ne pas oublier de se peser.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                onChanged: (bool v) => notifier.setReminder(enabled: v),
              ),
              if (w.reminderEnabled) ...<Widget>[
                const SizedBox(height: 6),
                // --- Fréquence -------------------------------------------------
                const _FieldLabel('Fréquence'),
                const SizedBox(height: 8),
                SegmentedButton<ReminderRepeat>(
                  segments: ReminderRepeat.values
                      .map(
                        (ReminderRepeat r) => ButtonSegment<ReminderRepeat>(
                          value: r,
                          label: Text(r.label),
                        ),
                      )
                      .toList(),
                  selected: <ReminderRepeat>{w.reminderRepeat},
                  onSelectionChanged: (Set<ReminderRepeat> s) =>
                      notifier.setReminder(
                    enabled: true,
                    repeat: s.first,
                  ),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppColors.glassFill,
                    selectedBackgroundColor:
                        AppColors.violet.withValues(alpha: 0.18),
                    selectedForegroundColor: AppColors.violet,
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.glassBorder),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 14),
                // --- Jour de la semaine --------------------------------------
                const _FieldLabel('Jour'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List<Widget>.generate(7, (int i) {
                    final int day = i + 1; // 1 = lundi
                    const List<String> labels = <String>[
                      'Lun',
                      'Mar',
                      'Mer',
                      'Jeu',
                      'Ven',
                      'Sam',
                      'Dim',
                    ];
                    final bool selected = w.reminderDayOfWeek == day;
                    return ChoiceChip(
                      label: Text(labels[i]),
                      selected: selected,
                      onSelected: (_) => notifier.setReminder(
                        enabled: true,
                        dayOfWeek: day,
                      ),
                      selectedColor: AppColors.violet.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.violet
                            : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),
                // --- Heure ----------------------------------------------------
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.violet,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'À ${w.reminderHour.toString().padLeft(2, '0')}:${w.reminderMinute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: w.reminderHour,
                            minute: w.reminderMinute,
                          ),
                          builder: (BuildContext ctx, Widget? child) {
                            return Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.violet,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          await notifier.setReminder(
                            enabled: true,
                            hour: picked.hour,
                            minute: picked.minute,
                          );
                        }
                      },
                      child: const Text('Modifier l\'heure'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        GlassCard(
          accent: AppColors.cyan,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: w.autoConnect,
            activeThumbColor: AppColors.cyan,
            title: const Text(
              'Reconnexion automatique',
              style: TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              w.savedScaleName == null
                  ? 'Se connecter automatiquement à la dernière balance appairée.'
                  : 'Dernière balance : ${w.savedScaleName}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            onChanged: notifier.setAutoConnect,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Formulaire de profil
// -----------------------------------------------------------------------------

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile, super.key});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late Sex _sex;
  late ActivityLevel _activity;
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _target;
  late final TextEditingController _fat;
  late final TextEditingController _muscle;
  late final TextEditingController _water;

  @override
  void initState() {
    super.initState();
    final UserProfile p = widget.profile;
    _sex = p.sex;
    _activity = p.activityLevel;
    _name = TextEditingController(text: p.name);
    _age = TextEditingController(text: p.age.toString());
    _height = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    _target = TextEditingController(text: p.targetWeightKg.toStringAsFixed(2));
    _fat = TextEditingController(
      text: p.manualFatPercent == null
          ? ''
          : p.manualFatPercent!.toStringAsFixed(2),
    );
    _muscle = TextEditingController(
      text: p.manualMusclePercent == null
          ? ''
          : p.manualMusclePercent!.toStringAsFixed(2),
    );
    _water = TextEditingController(
      text: p.manualWaterPercent == null
          ? ''
          : p.manualWaterPercent!.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _height.dispose();
    _target.dispose();
    _fat.dispose();
    _muscle.dispose();
    _water.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final String t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    final int? age = int.tryParse(_age.text.trim());
    final double? height = _parse(_height);
    final double? target = _parse(_target);

    if (age == null || age < 5 || age > 120) {
      _error('Âge invalide (5 à 120).');
      return;
    }
    if (height == null || height < 80 || height > 250) {
      _error('Taille invalide (80 à 250 cm).');
      return;
    }
    if (target == null || target < 20 || target > 300) {
      _error('Poids cible invalide (20 à 300 kg).');
      return;
    }

    final String name = _name.text.trim().isEmpty
        ? widget.profile.name
        : _name.text.trim();
    final UserProfile updated = UserProfile(
      id: widget.profile.id,
      name: name,
      isActive: widget.profile.isActive,
      sex: _sex,
      age: age,
      heightCm: height,
      activityLevel: _activity,
      targetWeightKg: target,
      manualFatPercent: _parse(_fat),
      manualMusclePercent: _parse(_muscle),
      manualWaterPercent: _parse(_water),
    );

    await ref.read(profilesProvider.notifier).save(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
  }

  void _error(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Nom du profil
              const _FieldLabel('Nom du profil'),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                style: AppTheme.numeric(16, weight: FontWeight.w600),
                decoration: const InputDecoration(labelText: 'Nom du profil'),
              ),
              const SizedBox(height: 18),

              // Sexe
              const _FieldLabel('Sexe'),
              const SizedBox(height: 8),
              SegmentedButton<Sex>(
                segments: const <ButtonSegment<Sex>>[
                  ButtonSegment<Sex>(
                    value: Sex.male,
                    label: Text('Homme'),
                    icon: Icon(Icons.male),
                  ),
                  ButtonSegment<Sex>(
                    value: Sex.female,
                    label: Text('Femme'),
                    icon: Icon(Icons.female),
                  ),
                ],
                selected: <Sex>{_sex},
                onSelectionChanged: (Set<Sex> s) =>
                    setState(() => _sex = s.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppColors.glassFill,
                  selectedBackgroundColor: AppColors.cyan.withValues(
                    alpha: 0.18,
                  ),
                  selectedForegroundColor: AppColors.cyan,
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.glassBorder),
                ),
              ),
              const SizedBox(height: 18),

              // Âge + taille
              Row(
                children: <Widget>[
                  Expanded(
                    child: _NumberField(
                      label: 'Âge',
                      suffix: 'ans',
                      controller: _age,
                      integer: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      label: 'Taille',
                      suffix: 'cm',
                      controller: _height,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Objectif
              _NumberField(
                label: 'Poids cible (objectif)',
                suffix: 'kg',
                controller: _target,
              ),
              const SizedBox(height: 18),

              // Niveau d'activité
              const _FieldLabel('Niveau d\'activité'),
              const SizedBox(height: 8),
              DropdownButtonFormField<ActivityLevel>(
                initialValue: _activity,
                isExpanded: true,
                dropdownColor: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                items: ActivityLevel.values
                    .map(
                      (ActivityLevel a) => DropdownMenuItem<ActivityLevel>(
                        value: a,
                        child: Text(
                          '${a.label} — ${a.description}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (ActivityLevel? v) {
                  if (v != null) setState(() => _activity = v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // --- Ajustement manuel des pourcentages ------------------------------
        GlassCard(
          accent: AppColors.amber,
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 4,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              iconColor: AppColors.amber,
              collapsedIconColor: AppColors.textMuted,
              title: const Text(
                'Ajustement manuel des pourcentages',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Prioritaire sur les formules si renseigné (facultatif).',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              children: <Widget>[
                _NumberField(
                  label: 'Masse grasse',
                  suffix: '%',
                  controller: _fat,
                ),
                const SizedBox(height: 14),
                _NumberField(
                  label: 'Masse musculaire',
                  suffix: '%',
                  controller: _muscle,
                ),
                const SizedBox(height: 14),
                _NumberField(
                  label: 'Eau corporelle',
                  suffix: '%',
                  controller: _water,
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _fat.clear();
                      _muscle.clear();
                      _water.clear();
                    }),
                    child: const Text(
                      'Utiliser les formules automatiques',
                      style: TextStyle(fontSize: 12, color: AppColors.amber),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _save,
            icon: const Icon(Icons.check_rounded),
            label: const Text(
              'Enregistrer le profil',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.controller,
    this.suffix,
    this.integer = false,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;
  final bool integer;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          RegExp(integer ? r'[0-9]' : r'[0-9.,]'),
        ),
      ],
      style: AppTheme.numeric(16, weight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}
