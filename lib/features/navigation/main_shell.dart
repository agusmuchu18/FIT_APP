import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import '../groups/presentation/pages/groups_list_screen.dart';
import '../home/presentation/home_summary_screen.dart';
import '../habits/presentation/habits_tracker_screen.dart';
import '../profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  static const double _barHeight = 76;
  int _currentIndex = 0;
  bool _menuOpen = false;

  late final AnimationController _menuController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  final List<Widget> _pages = const [
    HomeSummaryScreen(),
    HabitsTrackerScreen(),
    GroupsListScreen(),
    ProfileScreen(),
  ];

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _menuOpen = false;
    });
    _menuController.reverse();
  }

  void _toggleMenu() {
    setState(() {
      _menuOpen = !_menuOpen;
    });
    if (_menuOpen) {
      _menuController.forward();
    } else {
      _menuController.reverse();
    }
  }

  Future<void> _navigateTo(String route) async {
    _toggleMenu();
    await Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final contentBottomPadding = _barHeight + bottomInset + 12;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: contentBottomPadding),
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.shrink(),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionMenu(
                    controller: _menuController,
                    onWorkout: () => _navigateTo('/workout'),
                    onMeal: () => _navigateTo('/nutrition'),
                    onSleep: () => _navigateTo('/sleep'),
                  ),
                  const SizedBox(height: 8),
                  _BottomBar(
                    currentIndex: _currentIndex,
                    onSelect: _selectTab,
                    onCenterTap: _toggleMenu,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onCenterTap,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCenterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Inicio',
            isActive: currentIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.check_circle_outline_rounded,
            label: 'Hábitos',
            isActive: currentIndex == 1,
            onTap: () => onSelect(1),
          ),
          _CenterActionButton(onTap: onCenterTap),
          _NavItem(
            icon: Icons.groups_rounded,
            label: 'Grupos',
            isActive: currentIndex == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Perfil',
            isActive: currentIndex == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 30),
      ),
    );
  }
}

class _ActionMenu extends StatelessWidget {
  const _ActionMenu({
    required this.controller,
    required this.onWorkout,
    required this.onMeal,
    required this.onSleep,
  });

  final AnimationController controller;
  final VoidCallback onWorkout;
  final VoidCallback onMeal;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) {
    final opacity = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final offsetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return IgnorePointer(
          ignoring: controller.value == 0,
          child: SizeTransition(
            sizeFactor: controller,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: opacity,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionMenuItem(
            label: 'Registrar Entrenamiento',
            icon: Icons.fitness_center_rounded,
            onTap: onWorkout,
          ),
          const SizedBox(height: 10),
          _ActionMenuItem(
            label: 'Registrar Comida',
            icon: Icons.restaurant_rounded,
            onTap: onMeal,
          ),
          const SizedBox(height: 10),
          _ActionMenuItem(
            label: 'Registrar Sueño',
            icon: Icons.nightlight_round,
            onTap: onSleep,
          ),
        ],
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  const _ActionMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accentSecondary, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
