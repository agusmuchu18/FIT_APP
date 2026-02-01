import 'package:flutter/material.dart';

import '../common/theme/app_colors.dart';
import '../groups/presentation/pages/groups_list_screen.dart';
import '../habits/presentation/habits_tracker_screen.dart';
import '../home/presentation/home_summary_screen.dart';
import '../profile/profile_screen.dart';
import '../../ui/motion/controllers/motion_durations.dart';
import '../../ui/motion/widgets/animated_plus_x_button.dart';
import '../../ui/motion/widgets/speed_dial_menu.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const double _barHeight = 76;
  int _currentIndex = 0;
  bool _menuOpen = false;

  final List<Widget> _pages = const [
    HomeSummaryScreen(),
    HabitsTrackerScreen(),
    GroupsListScreen(),
    ProfileScreen(),
  ];

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _menuOpen = false;
    });
  }

  void _toggleMenu() {
    setState(() {
      _menuOpen = !_menuOpen;
    });
  }

  Future<void> _navigateTo(String route) async {
    if (_menuOpen) {
      setState(() => _menuOpen = false);
      await Future.delayed(MotionDurations.menu);
    }
    if (!mounted) return;
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
          SpeedDialMenu(
            isOpen: _menuOpen,
            bottomOffset: _barHeight + bottomInset + 12,
            onClose: () => setState(() => _menuOpen = false),
            onWorkout: () => _navigateTo('/workout'),
            onMeal: () => _navigateTo('/nutrition'),
            onSleep: () => _navigateTo('/sleep'),
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
                  _BottomBar(
                    currentIndex: _currentIndex,
                    onSelect: _selectTab,
                    onCenterTap: _toggleMenu,
                    isMenuOpen: _menuOpen,
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
    required this.isMenuOpen,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCenterTap;
  final bool isMenuOpen;

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
            isActive: currentIndex == 0,
            onTap: () => onSelect(0),
          ),
          _NavItem(
            icon: Icons.check_circle_outline_rounded,
            isActive: currentIndex == 1,
            onTap: () => onSelect(1),
          ),
          _CenterActionButton(
            onTap: onCenterTap,
            isMenuOpen: isMenuOpen,
          ),
          _NavItem(
            icon: Icons.groups_rounded,
            isActive: currentIndex == 2,
            onTap: () => onSelect(2),
          ),
          _NavItem(
            icon: Icons.person_rounded,
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
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.accent : AppColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        child: Center(
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _CenterActionButton extends StatelessWidget {
  const _CenterActionButton({required this.onTap, required this.isMenuOpen});

  final VoidCallback onTap;
  final bool isMenuOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedPlusXButton(
      isOpen: isMenuOpen,
      onTap: onTap,
      size: 54,
      color: const Color(0xFFF59E0B),
      iconColor: Colors.black,
    );
  }
}
