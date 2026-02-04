import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/debug/debug_flags.dart';
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

  final List<Widget> _basePages = const [
    HomeSummaryScreen(),
    HabitsTrackerScreen(),
    GroupsListScreen(),
    ProfileScreen(),
  ];

  static const List<String> _tabLabels = [
    'home',
    'habits',
    'groups',
    'profile',
  ];

  static const List<Color> _debugColors = [
    Color(0xFF1E3A8A),
    Color(0xFF5B21B6),
    Color(0xFF15803D),
    Color(0xFFFACC15),
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

  Widget _wrapDebugLayer({
    required Widget child,
    required String label,
    required Color color,
  }) {
    if (!DEBUG_UI) return child;
    return Stack(
      children: [
        ColoredBox(color: color),
        Positioned.fill(
          child: Opacity(
            opacity: 0.15,
            child: child,
          ),
        ),
        Center(
          child: Text(
            '$label LAYER OK',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> get _pages {
    if (!DEBUG_UI) return _basePages;
    return List<Widget>.generate(
      _basePages.length,
      (index) => _wrapDebugLayer(
        child: _basePages[index],
        label: _tabLabels[index].toUpperCase(),
        color: _debugColors[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final contentBottomPadding = _barHeight + bottomInset + 12;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: contentBottomPadding),
              child: IndexedStack(
                index: _currentIndex,
                children: _pages,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_menuOpen,
              child: SpeedDialMenu(
                isOpen: _menuOpen,
                bottomOffset: _barHeight + bottomInset + 12,
                onClose: () => setState(() => _menuOpen = false),
                onWorkout: () => _navigateTo('/workout'),
                onMeal: () => _navigateTo('/nutrition'),
                onSleep: () => _navigateTo('/sleep'),
              ),
            ),
          ),
          if (DEBUG_UI)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: Colors.black.withOpacity(0.75),
                  child: Text(
                    'DEBUG_UI ON | tab=${_tabLabels[_currentIndex]} | menuOpen=$_menuOpen',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _BottomBar(
                currentIndex: _currentIndex,
                onSelect: _selectTab,
                onCenterTap: _toggleMenu,
                isMenuOpen: _menuOpen,
              ),
            ),
          ),
        ),
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
    const borderRadius = BorderRadius.all(Radius.circular(30));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card.withOpacity(0.88),
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withOpacity(0.08)),
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
          ),
        ),
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
        width: 64,
        height: 52,
        child: Center(
          child: Icon(icon, color: color, size: 28),
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
      size: 60,
      color: const Color(0xFFF59E0B),
      iconColor: Colors.black,
    );
  }
}
