import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _NavTile(
        title: 'Workout Lite',
        subtitle: 'Registros rápidos',
        route: '/workout/lite',
        icon: Icons.flash_on,
      ),
      _NavTile(
        title: 'Workout Pro',
        subtitle: 'Plantillas detalladas',
        route: '/workout/pro',
        icon: Icons.fitness_center,
      ),
      _NavTile(
        title: 'Nutrición Lite',
        subtitle: 'Formularios simples',
        route: '/nutrition/lite',
        icon: Icons.local_dining,
      ),
      _NavTile(
        title: 'Nutrición Pro',
        subtitle: 'Macros y planes',
        route: '/nutrition/pro',
        icon: Icons.restaurant_menu,
      ),
      _NavTile(
        title: 'Sueño Lite',
        subtitle: 'Registro de horas',
        route: '/sleep/lite',
        icon: Icons.bedtime,
      ),
      _NavTile(
        title: 'Sueño Pro',
        subtitle: 'Control avanzado',
        route: '/sleep/pro',
        icon: Icons.night_shelter,
      ),
      _NavTile(
        title: 'Estadísticas',
        subtitle: 'Resumen de salud y rendimiento',
        route: '/analytics/overview',
        icon: Icons.bar_chart_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FIT App')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) => tiles[index],
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: tiles.length,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String route;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed(route),
      ),
    );
  }
}
