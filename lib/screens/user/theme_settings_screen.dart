import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/theme_provider.dart';
import '../../models/theme_settings.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Personalização Visual'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha o seu padrão de cores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildThemeOption(
              context,
              AppTheme.midnight,
              'Midnight Premium',
              'Uma interface luxuosa em tons de roxo e ardósia.',
              const [Color(0xFF7B61FF), Color(0xFF0F172A)],
              themeProvider,
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              context,
              AppTheme.ocean,
              'Ocean Deep',
              'Azul cristalino para uma experiência limpa e refrescante.',
              const [Color(0xFF0EA5E9), Color(0xFF082F49)],
              themeProvider,
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              context,
              AppTheme.forest,
              'Forest Zen',
              'Tons verdes e terrosos focados no bem-estar e saúde.',
              const [Color(0xFF10B981), Color(0xFF064E3B)],
              themeProvider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    AppTheme theme,
    String name,
    String description,
    List<Color> colors,
    ThemeProvider provider,
  ) {
    final isSelected = provider.currentTheme == theme;

    return GestureDetector(
      onTap: () => provider.setTheme(theme),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colors[1] : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? colors[0] : Colors.white.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.greenAccent),
          ],
        ),
      ),
    );
  }
}
