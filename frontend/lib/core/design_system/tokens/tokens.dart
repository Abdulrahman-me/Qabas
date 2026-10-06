import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Qabas design tokens.
///
/// The palette comes straight from the brand brief (§6.1). The colour story is
/// "a warm light in a deep, calm space": Deep Night Emerald and Emerald carry
/// depth, Flame Gold and Soft Ember carry light. Everything else is derived.
abstract final class QColors {
  // Brand core
  static const nightEmerald = Color(0xFF073C37);
  static const emerald = Color(0xFF0B5A52);
  static const flameGold = Color(0xFFE0A526);
  static const softEmber = Color(0xFFF6E3B4);
  static const morningMint = Color(0xFFEEF5F2);
  static const deepInk = Color(0xFF16233A);
  static const slate = Color(0xFF566476);

  // Night (dark surfaces)
  static const night950 = Color(0xFF032624);
  static const night900 = Color(0xFF052F2C);
  static const night800 = Color(0xFF0A4741);
  static const night700 = Color(0xFF0E5650);
  static const nightLine = Color(0xFF1C6159);

  // Emerald ramp
  static const emerald700 = Color(0xFF084A43);
  static const emerald500 = Color(0xFF13786B);
  static const emerald400 = Color(0xFF1E9180);
  static const emerald200 = Color(0xFFA9D6CB);
  static const emerald100 = Color(0xFFD5EDE6);
  static const emerald50 = Color(0xFFE7F4F0);

  // Gold ramp
  static const gold800 = Color(0xFF9A6A0E);
  static const gold700 = Color(0xFFB98318);
  static const gold400 = Color(0xFFEDBB45);
  static const gold300 = Color(0xFFF3CD6E);
  static const gold100 = Color(0xFFFBEFD2);
  static const gold50 = Color(0xFFFDF7E8);

  // Neutrals (light surfaces)
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSunk = Color(0xFFF5F9F7);
  static const line = Color(0xFFDCE7E3);
  static const lineStrong = Color(0xFFC5D6D0);
  static const muted = Color(0xFF8A97A6);

  // Feedback. "Correct" is emerald; "not quite" is a warm clay — gentle,
  // never an alarming red (brief §9, exercise illustrations).
  static const correct = Color(0xFF128070);
  static const correctEdge = Color(0xFF0B6457);
  static const correctSoft = Color(0xFFDDF2EB);
  static const retry = Color(0xFFC0743A);
  static const retryEdge = Color(0xFF9C5A27);
  static const retrySoft = Color(0xFFFBEBDD);
  static const retryInk = Color(0xFF8A4B1F);

  // Accents used sparingly for categories, avatars and charts
  static const dusk = Color(0xFF4E6A9E);
  static const duskSoft = Color(0xFFE3E9F5);
  static const rose = Color(0xFFB4637A);
  static const sky = Color(0xFF3D8EA8);

  static const statusVerified = correct;
  static const statusVerifiedSoft = correctSoft;
  static const statusCaution = gold800;
  static const statusCautionSoft = gold50;
  static const statusFabricated = retryEdge;
  static const statusFabricatedSoft = retrySoft;
  static const statusUnknown = slate;
  static const statusUnknownSoft = surfaceSunk;
  static const statusSpecialist = dusk;
  static const statusSpecialistSoft = duskSoft;

  // Exact authored accents from the prototype's brand widgets and badges.
  static const emberGold = Color(0xFFEDB12F);
  static const badgeMuted = Color(0xFF9AA8A5);
  static const badgeSteady = Color(0xFFD4834A);
}

abstract final class QSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 56;

  /// Horizontal page gutter.
  static const double page = 20;

  /// Comfortable reading width for lesson content on tablets / web.
  static const double readingWidth = 560;
}

abstract final class QRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 26;
  static const double xxl = 32;
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius button = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(999));
  static const BorderRadius sheet = BorderRadius.vertical(top: Radius.circular(xxl));
}

abstract final class QMotion {
  static const fast = Duration(milliseconds: 140);
  static const normal = Duration(milliseconds: 240);
  static const medium = Duration(milliseconds: 360);
  static const slow = Duration(milliseconds: 520);
  static const page = Duration(milliseconds: 460);
  static const pageReverse = Duration(milliseconds: 320);
  static const buttonPress = Duration(milliseconds: 70);
  static const pressScale = Duration(milliseconds: 110);
  static const countUp = Duration(milliseconds: 1100);
  static const rollingNumber = Duration(milliseconds: 900);
  static const flame = Duration(milliseconds: 2600);
  static const nightSky = Duration(seconds: 9);
  static const badgeBreathe = Duration(milliseconds: 3200);
  static const loadingDelay = Duration(milliseconds: 200);
  static const loadingLabelDelay = Duration(seconds: 1);
  static const skeletonPulse = Duration(milliseconds: 1200);
  static const characterSettle = Duration(milliseconds: 260);
  static const splash = Duration(milliseconds: 2600);
  static const splashMinimum = Duration(milliseconds: 2900);
  static const splashAssetTimeout = Duration(seconds: 4);

  /// After this long without a session, splash explains that the server may be waking up.
  static const splashSlowConnection = Duration(seconds: 5);
  static const languageChoice = Duration(milliseconds: 380);
  static const onboardingChoiceReveal = Duration(milliseconds: 80);
  static const onboardingReadyReveal = Duration(milliseconds: 260);
  static const onboardingReadyStagger = Duration(milliseconds: 140);
  static const reveal120 = Duration(milliseconds: 120);
  static const reveal150 = Duration(milliseconds: 150);
  static const reveal200 = Duration(milliseconds: 200);
  static const reveal300 = Duration(milliseconds: 300);
  static const reveal320 = Duration(milliseconds: 320);
  static const reveal420 = Duration(milliseconds: 420);

  /// Material 3 emphasized curve: confident start, soft landing.
  static const emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);
  static const gentle = Cubic(0.4, 0.0, 0.2, 1.0);

  /// A small, friendly overshoot for things that "arrive".
  static const settle = Cubic(0.34, 1.32, 0.64, 1.0);
}

abstract final class QShadows {
  static const soft = [
    BoxShadow(color: Color(0x14073C37), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x0A073C37), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const lifted = [
    BoxShadow(color: Color(0x22073C37), blurRadius: 30, offset: Offset(0, 14)),
    BoxShadow(color: Color(0x0F073C37), blurRadius: 6, offset: Offset(0, 2)),
  ];

  static List<BoxShadow> glow(Color c, {double strength = 1}) => [
    BoxShadow(
      color: c.withValues(alpha: 0.38 * strength),
      blurRadius: 26 * strength,
      spreadRadius: 1,
    ),
    BoxShadow(
      color: c.withValues(alpha: 0.18 * strength),
      blurRadius: 60 * strength,
      spreadRadius: 6,
    ),
  ];
}

abstract final class QGradients {
  static const night = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [QColors.night950, QColors.nightEmerald, QColors.night800],
    stops: [0, 0.55, 1],
  );

  static const gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [QColors.gold400, QColors.flameGold, Color(0xFFD58F1A)],
  );

  static const emeraldButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [QColors.emerald400, QColors.emerald500],
  );
  static const communityLeague = LinearGradient(
    colors: [QColors.night800, QColors.nightEmerald],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const communityChallenge = LinearGradient(
    colors: [QColors.emerald500, QColors.emerald],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class QBreakpoints {
  static const double phoneMax = 600;
  static const double rail = 840;
  static const double readingWidth = 560;
  static const double composerMax = 640;
}

abstract final class QSizes {
  static const double buttonHeight = 54;
  static const double buttonDepth = 4;
  static const double tapTarget = 44;
  static const double iconButton = 44;
  static const double buttonIcon = 21;
  static const double optionBadge = 30;
  static const double sheetHandleWidth = 44;
  static const double sheetHandleHeight = 5;
  static const double feedbackCompanionWidth = 92;
  static const double feedbackCompanionHeight = 104;
}

/// Authored geometry of the prototype navigation and companion placeholders.
abstract final class QNavigation {
  static const railWidth = 112.0;
  static const borderWidth = 1.5;
  static const barTop = 6.0;
  static const iconPadding = 5.0;
  static const labelGap = 3.0;
  static const labelSize = 11.5;
  static const labelTracking = 0.2;
  static const pressScale = 0.92;
  static const iconLarge = 27.0;
  static const icon = 26.0;
  static const railMark = 30.0;
  static const companion = 200.0;
}

/// Exact geometry of the prototype splash and onboarding screens.
abstract final class QOnboarding {
  static const compactHeight = 720.0;
  static const minimumHeight = 660.0;
  static const hero = 270.0, heroCompact = 210.0;
  static const small = 138.0, smallCompact = 120.0;
  static const smallWidthRatio = 0.86, bubbleStartRatio = 0.82;
  static const heroGlowBottom = 0.12, heroGlowSize = 0.9;
  static const heroZoom = 1.0, smallZoom = 1.4;
  static const progressHeight = 10.0, optionArt = 58.0, previewArt = 48.0;
  static const selectedBorder = 2.5, border = 1.5, optionCheck = 26.0;
  static const optionPadding = 14.0, bodyGap = 2.0;
  static const optionTitle = 17.0, bigTitle = 18.0;
  static const welcomeArabic = 36.0, welcomeLatin = 34.0, readyTitle = 32.0;
  static const barsWidth = 30.0, barsHeight = 24.0, barWidth = 7.0, barUnit = 8.0, barRadius = 3.0;
  static const logoScale = 0.7, pressScale = 0.98, bubbleScale = 0.92, heroGlowOpacity = 0.22;
  static const bubbleHorizontalPadding = 36.0, bubbleVerticalPadding = 28.0;
  static const readyEmbers = 28;
}

abstract final class QSplash {
  static const minimumHeight = 610.0;
  static const flameY = 0.36, pathEnd = 250.0;
  static const glowOffset = 150.0, glowSize = 300.0, flameOffset = 44.0, flameSize = 64.0;
  static const brandOffset = 52.0, wordOffset = 14.0;
}

/// Authored Journey dimensions; reading/sheet limits still use QBreakpoints.
abstract final class QJourney {
  static const pathWidth = 520.0, nodeSize = 72.0, checkpointSize = 84.0;
  static const spacing = 112.0, top = 92.0, bottom = 110.0, horizontalClearance = 120.0;
  static const nodeWidth = 100.0, nodeTop = 44.0, companion = 150.0;
  static const companionSide = 52.0, companionOpposite = 196.0, companionTop = 104.0;
  static const sceneryNear = 18.0, sceneryFar = 52.0, sceneryTop = 18.0;
  static const sceneryOpacity = 0.55, sheetZoom = 1.3;
  static const waveScale = 0.8, currentAlignment = 0.42, cacheExtent = 8000.0;
  static const oddUnitShift = 4, sceneryInterval = 3, unitSeedRange = 10;
  static const wave = [0.0, 0.42, 0.66, 0.42, 0.0, -0.42, -0.66, -0.42];
  static const nodePress = Duration(milliseconds: 80), bubbleMotion = Duration(milliseconds: 1400);
  static const lockedFlame = Color(0xFF6E8A85);
  static const compactBarWidth = 370.0, barHeight = 64.0, compactBarHeight = 128.0;
  static const horizonHeight = 260.0, hillHeight = 130.0;
  static LinearGradient sky(double progress) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(QColors.night950, QColors.nightEmerald, progress * 0.15)!,
      QColors.nightEmerald,
      const Color(0xFF0E4D4A),
      const Color(0xFF2D5560),
    ],
    stops: const [0, 0.35, 0.75, 1],
  );
}

/// Frozen geometry from the authored lesson screens.
abstract final class QLesson {
  static const feedbackMaxFraction = 0.55;
  static const border = 1.5, interfaceIcon = 20.0, introHintFlame = 18.0;
  static const feedbackEnterDy = 0.4, storyEnterDy = 0.06;
  static const feedbackAspect = 0.88, feedbackInkAlpha = 0.85;
  static const feedbackArabicHeight = 1.7, feedbackLatinHeight = 1.45, questionHeight = 1.4;
  static const quoteMeaningAlpha = 0.8, earlierFlameAlpha = 0.45, earlierTextAlpha = 0.62;
  static const introSkyDensity = 0.7, introSubtitleAlpha = 0.75;
  static const introGlowBottom = 10.0, introGlowAlpha = 0.28;
  static const objectiveVerticalExtra = 2.0;
  static const linkGap = 3.0;
  static const stepEnterDx = 0.12, stepExitDx = -0.08;
  static const compactContent = 330.0, compactCompanion = 100.0;
  static const optionPadding = 14.0, optionBadgeRadius = 9.0;
  static const pointArabicTop = 9.0, pointLatinTop = 5.0;
  static const tilePress = Duration(milliseconds: 90),
      reveal60 = Duration(milliseconds: 60),
      reveal100 = Duration(milliseconds: 100),
      optionStagger = Duration(milliseconds: 70);
  static const introCompanion = 150.0, introAspect = 0.78, introZoom = 1.25;
  static const hookCompanion = 132.0, hookAspect = 0.82, hookZoom = 1.35;
  static const introLatin = 30.0, introArabic = 32.0, body = 18.5;
  static const termArabic = 34.0, objectiveBadge = 32.0, objectiveRadius = 10.0;
  static const summaryIcon = 40.0, pointFlame = 13.0, quoteBorder = 2.0;
  static const dots = 8.0, activeDot = 22.0, dotGap = 3.0;
  static const smallGap = 6.0, sourcesStripe = 5.0, progressHeight = 16.0;
  static const topEnd = 20.0, topBottom = 4.0, companionZoom = 1.45;
  static const hookRatio = 1.75, storyRatio = 1.5, teachRatio = 1.9, dayTeachRatio = 2.1;
  static const hotspotRatio = 1.15, dayExerciseRatio = 2.8;
  static const reveal80 = Duration(milliseconds: 80), reveal160 = Duration(milliseconds: 160);
  static const reveal180 = Duration(milliseconds: 180), reveal260 = Duration(milliseconds: 260);
  static const reveal560 = Duration(milliseconds: 560), reveal640 = Duration(milliseconds: 640);
  static const pointStagger = Duration(milliseconds: 140), objectiveStagger = Duration(milliseconds: 90);
}

/// Authored exercise-kit dimensions from the prototype.
abstract final class QExercise {
  static const scenarioHue = 0.58, compactBucketWidth = 130.0;
  static const border = 2.0,
      bucketHotBorder = 2.5,
      depth = 3.0,
      bucketMinHeight = 190.0,
      art = 34.0,
      tokenHorizontal = 14.0,
      tokenVertical = 9.0,
      tokenCompactHorizontal = 10.0,
      tokenCompactVertical = 7.0;
  static const bankGhostAlpha = 0.45, secondaryAlpha = 0.6, tokenHeight = 1.25, tokenRotation = -0.04, tokenDragScale = 1.08;
  static const orderMinHeight = 132.0, orderLineOffset = 50.0, orderLineWidth = 1.5, orderRevealDy = 20.0;
  static const pinIcon = 16.0,
      pinWidth = 112.0,
      pinTop = 20.0,
      pinRadius = 30.0,
      pinHorizontal = 12.0,
      pinVertical = 7.0,
      pinScale = 1.12,
      pinAlpha = 0.82;
  static const reciteWord = 30.0,
      reciteWordHeight = 1.9,
      reciteRadius = 10.0,
      reciteScale = 1.06,
      listenSize = 68.0,
      micSize = 84.0,
      roundIconFraction = 0.42,
      roundGlow = 0.2;
  static const optionArabicHeight = 1.55,
      optionLatinHeight = 1.35,
      scenarioAvatar = 46.0,
      scenarioBody = 17.0,
      smallIcon = 18.0,
      phaseSmall = 26.0;
  static const matchMinHeight = 52.0, slotMinHeight = 48.0, emptySlotWidth = 104.0, emptySlotHeight = 40.0;
  static const tokenRevealScale = 0.8, inkAlpha = 0.75, mythBorderAlpha = 0.35, disabledPinAlpha = 0.5;
}

/// Frozen completion/streak geometry and staggers from the prototype.
abstract final class QCompletion {
  static const hero = 230.0, heroGlow = 260.0, heroGlowBottom = 20.0;
  static const glowOpacity = 0.3, subtitleAlpha = 0.72, nextAlpha = 0.85;
  static const icon = 18.0, challengeIcon = 20.0, statLabel = 10.5, statValue = 20.0;
  static const statInset = 2.0, labelPadding = 4.0, statPadding = 12.0, gap = 6.0;
  static const masteryLabel = 108.0, masteryValue = 72.0, bar = 12.0, border = 1.5;
  static const bulletTop = 6.0, bullet = 6.0, bubbleGap = 2.0;
  static const burst = 46;
  static const perfectAlpha = 0.15;
  static const soundDelay = Duration(milliseconds: 250);
  static const reveal400 = Duration(milliseconds: 400), reveal640 = Duration(milliseconds: 640);
  static const reveal700 = Duration(milliseconds: 700), reveal820 = Duration(milliseconds: 820);
  static const reveal900 = Duration(milliseconds: 900), barMotion = Duration(milliseconds: 1200);
}

abstract final class QStreak {
  static const hero = 250.0, glow = 280.0, glowOpacity = 0.38;
  static const flame = 120.0, flameTop = 30.0, flameGlow = 1.6;
  static const day = 36.0, dayFlame = 16.0, dotAlpha = 0.18, emptyAlpha = 0.05;
  static const rowAlpha = 0.8, otherAlpha = 0.55, bodyAlpha = 0.8;
  static const todayBorder = 2.5, border = 1.5, glowStrength = 0.5, letterSpacing = 1.0;
  static const burst = 40;
  static const soundDelay = Duration(milliseconds: 500), burstMotion = Duration(milliseconds: 3200);
  static const todayReveal = Duration(milliseconds: 1300), dayStagger = Duration(milliseconds: 80);
  static const dayScale = 0.4;
}

/// Authored Raqeeb screen geometry and stagger timings from the prototype.
abstract final class QRaqeeb {
  static const shortHeight = 240.0;
  static const border = 1.5, headerAvatar = 44.0, headerGlyph = 26.0, headerIcon = 14.0;
  static const heroHeight = 200.0, heroGlow = 220.0, heroGlyph = 78.0, heroTitle = 28.0, skyDensity = 0.8, glowOpacity = 0.4;
  static const trustBadge = 36.0, trustIcon = 19.0, suggestionIcon = 17.0, suggestionHorizontal = 14.0, suggestionVertical = 11.0;
  static const userIndent = 48.0, tail = 6.0, userFont = 16.0, answerFont = 16.5;
  static const answerAvatar = 34.0, answerGlyph = 20.0, sourceBadge = 22.0, sourceIcon = 16.0;
  static const verificationIcon = 20.0, verificationFont = 17.0, quoteHeight = 1.9, fieldLabel = 92.0;
  static const fieldStackWidth = fieldLabel * 2 + QSpace.page;
  static const verdictHorizontal = 10.0, verdictVertical = 4.0, verdictIcon = 14.0, verdictGap = 3.0;
  static const dot = 8.0, dotMargin = 2.5, dotMinAlpha = 0.3, dotAmplitude = 0.7, thinkingGap = 10.0;
  static const trustStart = Duration(milliseconds: 100),
      stagger = Duration(milliseconds: 70),
      suggestionsStart = Duration(milliseconds: 380);
  static const dotsMotion = Duration(milliseconds: 1100), speak = Duration(milliseconds: 1400);
  static const smallGap = 6.0,
      sourceGap = 4.0,
      citationRadius = 6.0,
      citationHorizontal = 6.0,
      citationVertical = 1.0,
      citationMargin = 2.0;
}

/// Frozen Profile/About geometry from the prototype.
abstract final class QProfile {
  static const hero = 170.0, skyDensity = 0.6, editIcon = 18.0, gap = 6.0;
  static const statIcon = 22.0, statIconBox = 28.0, statValue = 19.0, statLabel = 12.5, statAspect = 2.2;
  static const statMinHeight = 78.0, scaledStatHeight = 112.0;
  static const badge = 54.0, wordRing = 40.0, ringStroke = 4.0, wordArabic = 22.0;
  static const scaledRowWidth = 320.0, wordInlineMinimum = 190.0, wordArabicFraction = 0.32;
  static const statStagger = Duration(milliseconds: 50);
  static const aboutGlow = 240.0, aboutGlowOpacity = 0.3, aboutLogo = 0.9, aboutVerse = 28.0;
  static const aboutBorder = 1.5, aboutIcon = 20.0, referenceTracking = 0.4;
  static const aboutFirstReveal = Duration(milliseconds: 100);
}

/// Frozen review-card geometry from review_session_screen.dart.
abstract final class QReview {
  static const clockTick = Duration(milliseconds: 100);
  static const timerWarning = Duration(seconds: 5);
  static const guideArt = 52.0;
  static const guideBullet = 14.0, guideBulletTop = 3.0;
  static const cardHeight = 300.0;
  static const perspective = 0.0012;
  static const ratingHeight = 48.0;
  static const ratingFooterHeight = 18.0;
  static const gap = 6.0;
  static const companion = 220.0;
  static const displaySize = 30.0;
  static const border = 2.0;
  static const minimumContentHeight = 560.0;
}

/// Authored community/challenge geometry from the prototype.
abstract final class QCommunity {
  static const previewWidth = 92.0, previewAvatar = 36.0, previewStride = 26.0;
  static const badgeWidth = 70.0, badgeHeight = 76.0, badgeGlyph = 34.0, rank = 30.0;
  static const avatar = 40.0, friendAvatar = 44.0, questIcon = 42.0, flame = 20.0;
  static const gap = 6.0, rowInset = 8.0, rowMargin = 2.0, border = 1.5;
  static const medal = 24.0, promotionIcon = 16.0, bar = 12.0;
  static const silver = Color(0xFFA9B5BF), bronze = Color(0xFFC98A5C);
  static const stagger = Duration(milliseconds: 40);
}

abstract final class QChallenge {
  static const countdownSize = 120.0, lobbyFlame = 70.0, lobbyAvatar = 58.0;
  static const avatar = 44.0, resultAvatar = 36.0, hero = 190.0, title = 30.0;
  static const timer = 18.0, bar = 8.0, marker = 20.0, markerIcon = 12.0;
  static const dim = 0.35, waiting = 0.25, answeredAlpha = 0.7, gap = 6.0;
  static const minQuestionHeight = 600.0, minLobbyHeight = 560.0, minResultHeight = 710.0;
  static const tick = Duration(milliseconds: 100), ping = Duration(seconds: 10);
  static const reconnect = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 2),
    Duration(seconds: 2),
  ];
  static const lobbyPoll = Duration(seconds: 2), asyncWait = Duration(seconds: 60);
}

abstract final class QAchievements {
  static const badge = 66.0, aspect = 0.82, minHeight = 250.0, gap = 2.0, progress = 9.0, check = 20.0;
  static const stagger = Duration(milliseconds: 50);
}

abstract final class QMedia {
  static const tick = Duration(milliseconds: 100),
      voiceLimit = Duration(seconds: 60),
      recitationLimit = Duration(seconds: 30),
      checkTimeout = Duration(seconds: 15);
  static const preview = 80.0;
}

/// Dense, calm reviewer workspace geometry and polling cadence.
abstract final class QReviewer {
  static const previewHeight = 620.0;
  static const shortPreviewHeight = 420.0;
  static const listWidth = 336.0;
  static const metricMinWidth = 160.0;
  static const dashboardMaxWidth = QBreakpoints.readingWidth * 2 + QSpace.xl;
  static const chartHeight = 12.0;
  static const pollInterval = Duration(seconds: 3);
}
