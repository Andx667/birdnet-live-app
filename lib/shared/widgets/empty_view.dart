// =============================================================================
// EmptyView — shared centered empty-state placeholder
// =============================================================================
//
// Use whenever a screen has nothing to display and wants to invite the user
// to take an action (or simply explain why nothing is here).
//
// Design rationale (see dev/STYLE_GUIDE.md → "Empty States"):
//   • Icon size 64 dp, color `onSurface.withAlpha(77–80)`.
//   • Title `bodyLarge`, body `bodySmall`, both faded.
//   • Optional action button uses `FilledButton.tonal` so the empty state
//     does not compete visually with primary actions.
// =============================================================================

import 'package:flutter/material.dart';

/// Centered empty-state placeholder.
///
/// Example:
/// ```dart
/// EmptyView(
///   icon: Icons.library_music_outlined,
///   title: l10n.sessionLibraryEmptyTitle,
///   body: l10n.sessionLibraryEmptyBody,
/// )
/// ```
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  /// Icon shown at 64 dp.
  final IconData icon;

  /// Primary line. Should be a short sentence (≤ 60 chars).
  final String title;

  /// Optional supporting text. Shown beneath the title at smaller size.
  final String? body;

  /// Optional label for an action button. Required when [onAction] is set.
  final String? actionLabel;

  /// Optional callback for the action button. Pass `null` for a
  /// non-actionable empty state.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAction = onAction != null && actionLabel != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withAlpha(77),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(128),
                ),
              ),
            ],
            if (hasAction) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
