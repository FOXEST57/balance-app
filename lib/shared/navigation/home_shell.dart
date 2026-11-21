import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/activity/presentation/activity_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/tracking/presentation/tracking_page.dart';

/// Espace à réserver en bas de chaque page défilante.
///
/// La barre de navigation néon est dessinée **par-dessus** le contenu
/// (`Scaffold.extendBody`) sans lui réserver de place. Sans cette marge, le
/// dernier élément d'une liste — par exemple le bouton « Enregistrer le
/// profil » — se retrouve sous la barre : il est alors invisible et
/// impossible à toucher (le tap est capté par la barre).
const double kHomeNavBarClearance = 104;

/// Coquille principale avec barre de navigation inférieure néon.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const DashboardPage(),
      const TrackingPage(),
      const HistoryPage(),
      const ActivityPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _NeonNavBar(
          index: _index,
          onChanged: (int i) => setState(() => _index = i),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NeonNavBar extends StatelessWidget {
  const _NeonNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const List<_NavItem> _items = <_NavItem>[
    _NavItem(Icons.monitor_weight_outlined, Icons.monitor_weight_rounded, 'Pesée'),
    _NavItem(Icons.show_chart_rounded, Icons.show_chart_rounded, 'Suivi'),
    _NavItem(Icons.history_rounded, Icons.history_rounded, 'Historique'),
    _NavItem(Icons.directions_run_outlined, Icons.directions_run_rounded, 'Activité'),
    _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: List<Widget>.generate(_items.length, (int i) {
          final bool selected = i == index;
          final _NavItem item = _items[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.cyan.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.cyan.withValues(alpha: 0.45) : Colors.transparent,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 21,
                      color: selected ? AppColors.cyan : AppColors.textMuted,
                      shadows: selected
                          ? <Shadow>[Shadow(color: AppColors.cyan.withValues(alpha: 0.7), blurRadius: 10)]
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.cyan : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
