import 'package:flutter/material.dart';

/// Composant de repli élégant et rassurant en cas d'erreur de rendu UI (Anti-Crash).
/// Éradique tout écran rouge Flutter en production et respecte le standard Senior UI/UX.
class ShieldNetErrorBoundary extends StatelessWidget {
  final FlutterErrorDetails? details;
  final VoidCallback? onRetry;

  const ShieldNetErrorBoundary({
    super.key,
    this.details,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFBFDBFE),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Affichage temporairement indisponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Votre protection anti-spam et vos données restent 100% actives et sécurisées en arrière-plan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onRetry ?? () {},
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Recharger l\'écran'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
