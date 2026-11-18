import 'package:material_ui/material_ui.dart';

/// The app mark: a purple rounded square with a checklist glyph.
/// Used on the splash screen and in the app bar.
class AppLogo extends StatelessWidget {
  const AppLogo({this.size = 40, this.icon = Icons.checklist_rounded, super.key});

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.32),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(icon, color: scheme.onPrimary, size: size * 0.55),
    );
  }
}
