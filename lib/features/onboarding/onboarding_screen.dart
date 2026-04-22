import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/providers/app_providers.dart';

/// Onboarding carousel shown on first launch.
///
/// Introduces the app, features, permissions, and quick settings.
/// Can be re-shown from Settings > Reset Onboarding.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return IntroductionScreen(
      globalBackgroundColor: theme.scaffoldBackgroundColor,
      pages: [
        // 1. Welcome
        PageViewModel(
          title: l10n.onboardingWelcomeTitle,
          body: l10n.onboardingWelcomeBody,
          image: Center(
            child: ClipOval(
              child: Image.asset(
                'assets/images/app-icon.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ),
          decoration: _pageDecoration(theme),
        ),
        // 2. How It Works
        PageViewModel(
          title: l10n.onboardingHowItWorksTitle,
          body: l10n.onboardingHowItWorksBody,
          image: _buildIcon(Icons.mic_rounded, theme),
          decoration: _pageDecoration(theme),
        ),
        // 3. Features
        PageViewModel(
          title: l10n.onboardingFeaturesTitle,
          body: l10n.onboardingFeaturesBody,
          image: _buildIcon(Icons.grid_view_rounded, theme),
          decoration: _pageDecoration(theme),
        ),
        // 4. Permissions
        PageViewModel(
          title: l10n.onboardingPermissionsTitle,
          body: l10n.onboardingPermissionsBody,
          image: _buildIcon(Icons.security, theme),
          decoration: _pageDecoration(theme),
        ),
        // 5. Terms & Privacy
        PageViewModel(
          title: l10n.onboardingTermsTitle,
          bodyWidget: _TermsBody(l10n: l10n, theme: theme),
          image: _buildIcon(Icons.gavel_rounded, theme),
          decoration: _pageDecoration(theme),
        ),
        // 6. Ready
        PageViewModel(
          title: l10n.onboardingReadyTitle,
          body: l10n.onboardingReadyBody,
          image: _buildIcon(Icons.check_circle_outline, theme),
          decoration: _pageDecoration(theme),
        ),
      ],
      showSkipButton: true,
      skip: Text(l10n.skip),
      next: Text(l10n.next),
      done: Text(
        l10n.getStarted,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onDone: () {
        ref.read(onboardingCompleteProvider.notifier).complete();
      },
      onSkip: () {
        ref.read(onboardingCompleteProvider.notifier).complete();
      },
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(16, 8),
        spacing: const EdgeInsets.symmetric(horizontal: 3),
        activeColor: theme.colorScheme.primary,
        color: theme.colorScheme.outline,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      controlsPadding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
    );
  }

  Widget _buildIcon(IconData icon, ThemeData theme) {
    return Center(
      child: Icon(
        icon,
        size: 80,
        color: theme.colorScheme.primary,
      ),
    );
  }

  PageDecoration _pageDecoration(ThemeData theme) {
    return PageDecoration(
      titleTextStyle: theme.textTheme.headlineMedium!.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
      bodyTextStyle: theme.textTheme.bodyLarge!.copyWith(
        color: theme.colorScheme.onSurface.withAlpha(200),
      ),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 24),
      imagePadding: const EdgeInsets.only(top: 32),
    );
  }
}

/// Body for the Terms & Privacy onboarding page.
///
/// Shows a condensed summary plus tappable links to the full Terms of Use
/// and Privacy Policy hosted in the documentation site.
class _TermsBody extends StatelessWidget {
  const _TermsBody({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final ThemeData theme;

  Future<void> _open(String path) async {
    final uri = Uri.parse('${AppConstants.docsUrl}$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(200),
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(l10n.onboardingTermsBody, style: bodyStyle),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 4,
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
      ],
    );
  }
}
