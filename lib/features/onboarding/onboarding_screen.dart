// =====================================================================
// Onboarding flow
//
// First-run experience and Terms-of-Use gate, combined into a single
// PageView-based wizard. The previous version used the
// `introduction_screen` package plus a separate `TermsGateScreen` that
// re-prompted for ToU acceptance after onboarding finished â€” meaning
// users were shown the terms twice and the layout wasted vertical space
// on oversized centered icons.
//
// This rewrite:
//   * Custom PageView with a compact bottom controls bar so body text
//     gets the screen real estate it deserves.
//   * Interactive Permissions page that actually triggers the OS
//     microphone and location prompts via `record` + `geolocator`
//     (instead of just describing the permissions in prose).
//   * Terms & Privacy page with an "I agree" checkbox; the Get Started
//     button is disabled until the box is checked. On finish we mark
//     both `onboardingComplete` and `termsAccepted` in one shot, so
//     there is no follow-up gate screen.
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  bool _termsAgreed = false;
  bool _micGranted = false;
  bool _locGranted = false;
  bool _requestingMic = false;
  bool _requestingLoc = false;

  static const int _totalPages = 5;
  static const int _termsPageIndex = 4;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissionStatus() async {
    try {
      final loc = await Geolocator.checkPermission();
      if (!mounted) return;
      setState(() {
        _locGranted = loc == LocationPermission.whileInUse ||
            loc == LocationPermission.always;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _requestMic() async {
    if (_requestingMic) return;
    setState(() => _requestingMic = true);
    try {
      final granted = await AudioRecorder().hasPermission();
      if (!mounted) return;
      setState(() => _micGranted = granted);
    } catch (_) {
      if (!mounted) return;
      setState(() => _micGranted = false);
    } finally {
      if (mounted) setState(() => _requestingMic = false);
    }
  }

  Future<void> _requestLocation() async {
    if (_requestingLoc) return;
    setState(() => _requestingLoc = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      setState(() {
        _locGranted = perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locGranted = false);
    } finally {
      if (mounted) setState(() => _requestingLoc = false);
    }
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToTerms() {
    _controller.animateToPage(
      _termsPageIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    await ref.read(termsAcceptedProvider.notifier).accept();
    await ref.read(onboardingCompleteProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _page < _termsPageIndex ? 1 : 0,
                    child: TextButton(
                      onPressed: _page < _termsPageIndex ? _skipToTerms : null,
                      child: Text(l10n.skip),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i == 3) _refreshPermissionStatus();
                },
                children: [
                  _WelcomePage(l10n: l10n, theme: theme),
                  _InfoPage(
                    icon: Icons.graphic_eq_rounded,
                    title: l10n.onboardingHowItWorksTitle,
                    body: l10n.onboardingHowItWorksBody,
                    theme: theme,
                  ),
                  _InfoPage(
                    icon: Icons.grid_view_rounded,
                    title: l10n.onboardingFeaturesTitle,
                    body: l10n.onboardingFeaturesBody,
                    theme: theme,
                  ),
                  _PermissionsPage(
                    l10n: l10n,
                    theme: theme,
                    micGranted: _micGranted,
                    locGranted: _locGranted,
                    requestingMic: _requestingMic,
                    requestingLoc: _requestingLoc,
                    onRequestMic: _requestMic,
                    onRequestLocation: _requestLocation,
                  ),
                  _TermsPage(
                    l10n: l10n,
                    theme: theme,
                    agreed: _termsAgreed,
                    onAgreedChanged: (v) =>
                        setState(() => _termsAgreed = v ?? false),
                  ),
                ],
              ),
            ),
            _ControlsBar(
              page: _page,
              total: _totalPages,
              isFinalPage: _page == _termsPageIndex,
              canFinish: _termsAgreed,
              onNext: _next,
              onFinish: _finish,
              theme: theme,
              l10n: l10n,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom controls bar
// ---------------------------------------------------------------------------

class _ControlsBar extends StatelessWidget {
  const _ControlsBar({
    required this.page,
    required this.total,
    required this.isFinalPage,
    required this.canFinish,
    required this.onNext,
    required this.onFinish,
    required this.theme,
    required this.l10n,
  });

  final int page;
  final int total;
  final bool isFinalPage;
  final bool canFinish;
  final VoidCallback onNext;
  final Future<void> Function() onFinish;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        8 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 16 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: isFinalPage ? (canFinish ? onFinish : null) : onNext,
              child: Text(
                isFinalPage ? l10n.getStarted : l10n.next,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Welcome
// ---------------------------------------------------------------------------

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/app-icon.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.onboardingWelcomeTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                l10n.onboardingWelcomeBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(210),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: generic info (icon + title + body)
// ---------------------------------------------------------------------------

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.theme,
  });

  final IconData icon;
  final String title;
  final String body;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(210),
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Permissions (interactive)
// ---------------------------------------------------------------------------

class _PermissionsPage extends StatelessWidget {
  const _PermissionsPage({
    required this.l10n,
    required this.theme,
    required this.micGranted,
    required this.locGranted,
    required this.requestingMic,
    required this.requestingLoc,
    required this.onRequestMic,
    required this.onRequestLocation,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool micGranted;
  final bool locGranted;
  final bool requestingMic;
  final bool requestingLoc;
  final Future<void> Function() onRequestMic;
  final Future<void> Function() onRequestLocation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.security_rounded,
              size: 24,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.onboardingPermissionsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingPermissionsBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(200),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _PermissionTile(
                  icon: Icons.mic_rounded,
                  title: l10n.permissionMicrophoneTitle,
                  description: l10n.permissionMicrophoneDescription,
                  granted: micGranted,
                  busy: requestingMic,
                  onGrant: onRequestMic,
                  theme: theme,
                  l10n: l10n,
                ),
                const SizedBox(height: 12),
                _PermissionTile(
                  icon: Icons.location_on_rounded,
                  title: l10n.permissionLocationTitle,
                  description: l10n.permissionLocationDescription,
                  granted: locGranted,
                  busy: requestingLoc,
                  onGrant: onRequestLocation,
                  theme: theme,
                  l10n: l10n,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.busy,
    required this.onGrant,
    required this.theme,
    required this.l10n,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final bool busy;
  final Future<void> Function() onGrant;
  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 22, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(170),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (granted)
            Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade600,
              size: 28,
            )
          else
            SizedBox(
              height: 36,
              child: FilledButton.tonal(
                onPressed: busy ? null : onGrant,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.permissionRequest),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page: Terms & Privacy (with required checkbox)
// ---------------------------------------------------------------------------

class _TermsPage extends StatelessWidget {
  const _TermsPage({
    required this.l10n,
    required this.theme,
    required this.agreed,
    required this.onAgreedChanged,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final bool agreed;
  final ValueChanged<bool?> onAgreedChanged;

  Future<void> _open(String path) async {
    final uri = Uri.parse('${AppConstants.docsUrl}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.gavel_rounded,
              size: 24,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.onboardingTermsTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                l10n.onboardingTermsBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(210),
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => _open('/terms/'),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: Text(l10n.onboardingTermsLink),
              ),
              TextButton.icon(
                onPressed: () => _open('/privacy/'),
                icon: const Icon(Icons.privacy_tip_outlined, size: 18),
                label: Text(l10n.onboardingPrivacyLink),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => onAgreedChanged(!agreed),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: agreed,
                    onChanged: onAgreedChanged,
                  ),
                  Expanded(
                    child: Text(
                      l10n.onboardingTermsAccept,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
