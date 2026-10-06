import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qabas/app/router/routes.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/shared/content/bundled_scripture.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

/// The story behind the name (brief §2): Musa sees a fire on a cold night and
/// hopes to bring back a qabas — a small flame — or find guidance there.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: QColors.night950,
        body: NightSky(
          density: 1.1,
          child: ListView(
            padding: EdgeInsets.fromLTRB(QSpace.page, top + QSpace.xxs, QSpace.page, QSpace.xxl),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: QIconButton(
                  icon: Icons.arrow_back_rounded,
                  color: QColors.softEmber,
                  tooltip: s.commonBack,
                  onTap: () => context.canPop() ? context.pop() : context.go(Routes.settings),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: QSpace.md),
                      const Center(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Glow(size: QProfile.aboutGlow, opacity: QProfile.aboutGlowOpacity),
                            QabasLogo(size: QProfile.aboutLogo),
                          ],
                        ),
                      ),
                      const SizedBox(height: QSpace.xl),
                      Reveal(
                        child: Text(s.aboutNameMeaningTitle.toUpperCase(), style: context.qText.eyebrow.copyWith(color: QColors.flameGold)),
                      ),
                      const SizedBox(height: QSpace.xs),
                      Reveal(
                        delay: QProfile.aboutFirstReveal,
                        child: Text(
                          s.aboutNameMeaning,
                          style: context.text.bodyLarge?.copyWith(color: QColors.softEmber.withValues(alpha: 0.9)),
                        ),
                      ),
                      const SizedBox(height: QSpace.lg),
                      Reveal(
                        delay: QMotion.reveal200,
                        child: Semantics(
                          button: true,
                          label: s.aboutFullVerse,
                          child: GestureDetector(
                            key: const ValueKey('about-verse'),
                            onTap: () => showQSheet(
                              context,
                              builder: (ctx) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(ctx.l10n.aboutTahaReference, style: ctx.text.headlineSmall),
                                  const SizedBox(height: QSpace.md),
                                  Text(Scripture.taha10, textDirection: TextDirection.rtl, style: ctx.qText.quran),
                                ],
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(QSpace.lg),
                              decoration: BoxDecoration(
                                color: QColors.night800.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(QRadius.xl),
                                border: Border.all(color: QColors.flameGold.withValues(alpha: 0.4), width: QProfile.aboutBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Quran text: exact, in the Uthmani script, never stylised
                                  Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      '﴿${Scripture.taha10Segment}﴾',
                                      textAlign: TextAlign.center,
                                      style: context.qText.quran.copyWith(color: QColors.softEmber, fontSize: QProfile.aboutVerse),
                                    ),
                                  ),
                                  const SizedBox(height: QSpace.sm),
                                  if (!context.isArabic)
                                    Text(
                                      s.aboutVerseTranslation,
                                      textAlign: TextAlign.center,
                                      style: context.text.bodyMedium?.copyWith(
                                        color: QColors.softEmber.withValues(alpha: 0.8),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  const SizedBox(height: QSpace.xs),
                                  Text(
                                    '${s.aboutTahaReference} · ${s.aboutTranslationNote}',
                                    textAlign: TextAlign.center,
                                    style: context.text.labelSmall?.copyWith(
                                      color: QColors.flameGold,
                                      letterSpacing: QProfile.referenceTracking,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: QSpace.lg),
                      Reveal(
                        delay: QMotion.reveal300,
                        child: Text(
                          s.aboutWhyItFits,
                          style: context.text.bodyLarge?.copyWith(color: QColors.softEmber.withValues(alpha: 0.9)),
                        ),
                      ),
                      const SizedBox(height: QSpace.xl),
                      Text(s.aboutOurPromises.toUpperCase(), style: context.qText.eyebrow.copyWith(color: QColors.flameGold)),
                      const SizedBox(height: QSpace.sm),
                      for (final (icon, text) in [
                        (Icons.verified_user_rounded, s.aboutPromise1),
                        (Icons.menu_book_rounded, s.aboutPromise2),
                        (Icons.favorite_rounded, s.aboutPromise3),
                        (Icons.lock_rounded, s.aboutPromise4),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: QSpace.sm),
                          child: Row(
                            children: [
                              Icon(icon, color: QColors.flameGold, size: QProfile.aboutIcon),
                              const SizedBox(width: QSpace.sm),
                              Expanded(
                                child: Text(text, style: context.text.titleSmall?.copyWith(color: QColors.softEmber)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: QSpace.lg),
                      Text(
                        s.settingsContentNoteBody,
                        style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.9)),
                      ),
                      const SizedBox(height: QSpace.sm),
                      Text(s.aboutAiNotice, style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.9))),
                      const SizedBox(height: QSpace.lg),
                      const DottedLine(color: QColors.nightLine),
                      const SizedBox(height: QSpace.md),
                      Text(
                        s.commonTagline,
                        textAlign: TextAlign.center,
                        style: context.text.bodySmall?.copyWith(color: QColors.softEmber.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
