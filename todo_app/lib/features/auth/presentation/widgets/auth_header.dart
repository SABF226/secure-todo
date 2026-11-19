import 'package:material_ui/material_ui.dart';

/// The header shared by the sign-in and sign-up pages.
///
/// A light lavender wash rather than a saturated purple block: the brand
/// stays visible through the badge and the wordmark, without darkening the
/// top half of the screen.
///
/// Pure presentation: two strings in, pixels out. No bloc, no navigation.
class AuthHeader extends StatelessWidget {
  const AuthHeader({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 32),
      decoration: BoxDecoration(
        // Fades into the page background: no hard edge under the header.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.75),
            scheme.surface,
          ],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.done_all_rounded,
                  color: scheme.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Secure Todo',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
