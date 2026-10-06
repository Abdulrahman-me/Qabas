import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// Phase 10 about interface copy.
  ///
  /// In en, this message translates to:
  /// **'Questions are processed by AI services. For personal rulings, consult a qualified specialist.'**
  String get aboutAiNotice;

  /// Phase 10 about interface copy.
  ///
  /// In en, this message translates to:
  /// **'Read the full verse'**
  String get aboutFullVerse;

  /// Prototype interface copy: about / nameMeaning. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Qabas (قبس) is a small flame taken from a larger fire, carried to bring light and warmth. The word comes from the Quran, in the story of Prophet Musa (Moses), peace be upon him: travelling at night with his family, cold and unsure of the way, he saw a fire in the distance.'**
  String get aboutNameMeaning;

  /// Prototype interface copy: about / nameMeaningTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'The name'**
  String get aboutNameMeaningTitle;

  /// Prototype interface copy: about / ourPromises. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Our promises'**
  String get aboutOurPromises;

  /// Prototype interface copy: about / promise1. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Every lesson is reviewed by a specialist in Islamic studies'**
  String get aboutPromise1;

  /// Prototype interface copy: about / promise2. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Verses and hadiths are quoted exactly, with their sources'**
  String get aboutPromise2;

  /// Prototype interface copy: about / promise3. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Welcoming, never pressuring — safe to ask anything'**
  String get aboutPromise3;

  /// Prototype interface copy: about / promise4. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your journey is private unless you choose to share it'**
  String get aboutPromise4;

  /// Prototype interface copy: about / tahaReference. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Surah Taha, 20:10'**
  String get aboutTahaReference;

  /// Prototype interface copy: about / translationNote. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Translation: Saheeh International'**
  String get aboutTranslationNote;

  /// Phase 10 about interface copy.
  ///
  /// In en, this message translates to:
  /// **'“Perhaps I can bring you a torch or find at the fire some guidance.”'**
  String get aboutVerseTranslation;

  /// Prototype interface copy: about / whyItFits. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'This is our learner’s story: someone notices a light from afar, feels curious, walks toward it, and finds guidance. Qabas is that first flame — small, warm, inviting, and leading somewhere greater.'**
  String get aboutWhyItFits;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Join challenge'**
  String get challengeAccept;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Answer locked'**
  String get challengeAnswered;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Play now; your friend plays later'**
  String get challengeAsync;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Fill empty seats with practice bots'**
  String get challengeBotFill;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Choose up to three friends'**
  String get challengeChooseFriends;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Connection lost'**
  String get challengeConnectionLost;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get challengeDecline;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'{name} is reconnecting · {seconds}s'**
  String challengeDisconnected(String name, String seconds);

  /// Prototype interface copy: challenge / done. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get challengeDone;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'You lit the way together!'**
  String get challengeDraw;

  /// Prototype interface copy: challenge / fastest. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get challengeFastest;

  /// Prototype interface copy: challenge / getReady. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Get ready'**
  String get challengeGetReady;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Challenge friends'**
  String get challengeGroup;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get challengeInvitations;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Challenge from {name}'**
  String challengeInviteFrom(String name);

  /// Prototype interface copy: challenge / liveLobby. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Friends are joining…'**
  String get challengeLiveLobby;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'No invitations right now'**
  String get challengeNoInvitations;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'This challenge has already started or ended'**
  String get challengeNotJoinableTitle;

  /// Prototype interface copy: challenge / playAgain. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Play again'**
  String get challengePlayAgain;

  /// Prototype interface copy: challenge / points. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get challengePoints;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Practice with the bot'**
  String get challengePracticeBot;

  /// Prototype interface copy: challenge / questionOf. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String challengeQuestionOf(String current, String total);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get challengeReconnecting;

  /// Prototype interface copy: challenge / results. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get challengeResults;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String challengeSeconds(String value);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Review answers'**
  String get challengeSummary;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your friend'**
  String get challengeWaitingFriend;

  /// Prototype interface copy: challenge / wellPlayed. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Well played!'**
  String get challengeWellPlayed;

  /// Prototype interface copy: challenge / youWon. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You lit the way!'**
  String get challengeYouWon;

  /// Foundation component / characterGuideSemantics. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Your guide carrying a small light'**
  String get characterGuideSemantics;

  /// Foundation component / characterLanternSemantics. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Raqeeb’s lantern'**
  String get characterLanternSemantics;

  /// Prototype interface copy: common / appName. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Qabas'**
  String get commonAppName;

  /// Foundation component / commonArabic. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get commonArabic;

  /// Prototype interface copy: common / back. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Foundation component / commonBrandArabic. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'قبس'**
  String get commonBrandArabic;

  /// Foundation component / commonBrandLatin. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Qabas'**
  String get commonBrandLatin;

  /// Prototype interface copy: common / cancel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Prototype interface copy: common / check. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get commonCheck;

  /// Foundation component / commonChooseAnother. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get commonChooseAnother;

  /// Prototype interface copy: common / close. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Splash hint while a sleeping hosted server wakes up on the first request.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Qabas… The first visit can take up to a minute.'**
  String get commonConnectingSlow;

  /// Prototype interface copy: common / continue. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// Prototype interface copy: common / dayStreak. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{countText} day streak}}'**
  String commonDayStreak(num count, String countText);

  /// Prototype interface copy: common / days. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{countText} days}}'**
  String commonDays(num count, String countText);

  /// Prototype interface copy: common / done. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Foundation component / commonEdit. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Prototype interface copy: common / embers. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{value} embers'**
  String commonEmbers(String value);

  /// Prototype interface copy: common / embersName. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Embers'**
  String get commonEmbersName;

  /// Foundation component / commonEnglish. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get commonEnglish;

  /// Prototype interface copy: common / gotIt. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// Prototype interface copy: common / later. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get commonLater;

  /// Foundation component / commonLoading. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// Prototype interface copy: common / minutes. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String commonMinutes(String value);

  /// Prototype interface copy: common / minutesLong. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{value} min}}'**
  String commonMinutesLong(num count, String value);

  /// Prototype interface copy: common / new. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// Prototype interface copy: common / next. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Foundation component / commonOfflineBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. We’ll keep what you’ve done.'**
  String get commonOfflineBody;

  /// Prototype interface copy: common / pathExplorer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get commonPathExplorer;

  /// Prototype interface copy: common / pathExplorerLong. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Explorer path'**
  String get commonPathExplorerLong;

  /// Prototype interface copy: common / pathNewMuslim. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'New Muslim'**
  String get commonPathNewMuslim;

  /// Prototype interface copy: common / pathNewMuslimLong. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'New Muslim path'**
  String get commonPathNewMuslimLong;

  /// Prototype interface copy: common / percent. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String commonPercent(String value);

  /// Prototype interface copy: common / plusEmbers. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'+{value} embers'**
  String commonPlusEmbers(String value);

  /// Foundation component / commonRecordTooltip. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Record a question'**
  String get commonRecordTooltip;

  /// Foundation component / commonRemoveAttachmentTooltip. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Remove attachment'**
  String get commonRemoveAttachmentTooltip;

  /// Foundation component / commonRetry. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// Prototype interface copy: common / seeAll. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get commonSeeAll;

  /// Foundation component / commonSendTooltip. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get commonSendTooltip;

  /// Foundation component / commonSessionEndedBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Your guest session has ended. We’ll help you start a new journey.'**
  String get commonSessionEndedBody;

  /// Foundation component / commonSessionEndedTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Let’s begin again'**
  String get commonSessionEndedTitle;

  /// Prototype interface copy: common / skip. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// Prototype interface copy: common / start. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get commonStart;

  /// Prototype interface copy: common / tabCommunity. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get commonTabCommunity;

  /// Foundation component / commonTabDiscover. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get commonTabDiscover;

  /// Prototype interface copy: common / tabJourney. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get commonTabJourney;

  /// Prototype interface copy: common / tabProfile. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get commonTabProfile;

  /// Prototype interface copy: common / tabRaqeeb. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Raqeeb'**
  String get commonTabRaqeeb;

  /// Prototype interface copy: common / tabReview. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get commonTabReview;

  /// Prototype interface copy: common / tagline. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Learn Islam step by step, from your first question to real understanding.'**
  String get commonTagline;

  /// Foundation component / commonUpdate. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Update Qabas'**
  String get commonUpdate;

  /// Foundation component / commonUpdateBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Update Qabas to keep learning. Your journey will be waiting.'**
  String get commonUpdateBody;

  /// Foundation component / commonUpdateTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'A little update, a brighter path'**
  String get commonUpdateTitle;

  /// Prototype interface copy: community / communityTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityCommunityTitle;

  /// Prototype interface copy: community / dailyQuests. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Daily quests'**
  String get communityDailyQuests;

  /// Prototype interface copy: community / endsIn. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Ends in {days}d {hours}h'**
  String communityEndsIn(String days, String hours);

  /// Prototype interface copy: community / friends. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get communityFriends;

  /// Prototype interface copy: community / invite. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get communityInvite;

  /// Prototype interface copy: community / joinLeague. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Join the league'**
  String get communityJoinLeague;

  /// Prototype interface copy: community / learningPrivately. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You’re learning privately'**
  String get communityLearningPrivately;

  /// Prototype interface copy: community / learningPrivatelyBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your activity is hidden from leagues and friends. You can join any time.'**
  String get communityLearningPrivatelyBody;

  /// Prototype interface copy: community / liveChallenge. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Live challenge'**
  String get communityLiveChallenge;

  /// Prototype interface copy: community / liveChallengeBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Challenge friends to a live quiz — the fastest correct answer wins.'**
  String get communityLiveChallengeBody;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend to learn together'**
  String get communityNoFriends;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Earn embers to join this week’s league'**
  String get communityNoLeagueTitle;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'You’re all caught up for today'**
  String get communityNoQuests;

  /// Progress count with locale-formatted values
  ///
  /// In en, this message translates to:
  /// **'{current}/{target}'**
  String communityProgressCount(String current, String target);

  /// Prototype interface copy: community / promoteLine. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Top {countText} move up to {league}'**
  String communityPromoteLine(String countText, String league);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Top {count} move up'**
  String communityPromotionCount(String count);

  /// Prototype interface copy: community / promotionZone. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Promotion zone'**
  String get communityPromotionZone;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'+{count} embers'**
  String communityQuestReward(String count);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Resets in {hours}h'**
  String communityResetsIn(String hours);

  /// Prototype interface copy: community / startChallenge. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Start a challenge'**
  String get communityStartChallenge;

  /// Prototype interface copy: community / streakDays. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{countText}-day streak'**
  String communityStreakDays(String countText);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Keep your light shining'**
  String get communityTopTier;

  /// Prototype interface copy: community / you. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get communityYou;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get contentArticle;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'This audio isn’t available right now.'**
  String get contentAudioError;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get contentBook;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Fatwa'**
  String get contentFatwa;

  /// Prototype interface copy: content / hadithLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get contentHadithLabel;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get contentLearnMore;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get contentLevelBasic;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get contentLevelIntermediate;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Your level'**
  String get contentLevelUnknown;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Dorar'**
  String get contentProviderDorar;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'HadeethEnc'**
  String get contentProviderHadeethenc;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'IslamHouse'**
  String get contentProviderIslamhouse;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Quran.com'**
  String get contentProviderQuranCom;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'QuranEnc'**
  String get contentProviderQuranenc;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Tafsir Center'**
  String get contentProviderTafsirCenter;

  /// Prototype interface copy: content / quranLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get contentQuranLabel;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get contentSource;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Tafsir'**
  String get contentTafsir;

  /// Prototype interface copy: content / viewSource. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get contentViewSource;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'New lessons to explore will appear here.'**
  String get discoverEmptyBody;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'More to explore'**
  String get discoverEmptyTitle;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Some lessons normally come later on your path. Earlier units can make them easier to understand.'**
  String get discoverNotice;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Unit {number} · {title}'**
  String discoverUnitHeading(String number, String title);

  /// Foundation component / errorFileTypeBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'This file type isn’t supported.'**
  String get errorFileTypeBody;

  /// Foundation component / errorFileTypeTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Try another file'**
  String get errorFileTypeTitle;

  /// Foundation component / errorForbiddenBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'This isn’t available for your account.'**
  String get errorForbiddenBody;

  /// Foundation component / errorForbiddenTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'This isn’t available'**
  String get errorForbiddenTitle;

  /// Foundation component / errorGenericBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Let’s try that again.'**
  String get errorGenericBody;

  /// Foundation component / errorGenericTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Something unexpected happened'**
  String get errorGenericTitle;

  /// Foundation component / errorNetworkBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Check your internet and try again.'**
  String get errorNetworkBody;

  /// Foundation component / errorNetworkTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get errorNetworkTitle;

  /// Foundation component / errorNotFoundBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Go back and take another step.'**
  String get errorNotFoundBody;

  /// Foundation component / errorNotFoundTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t find this'**
  String get errorNotFoundTitle;

  /// Foundation component / errorRateLimitedBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'You can try again in {time}.'**
  String errorRateLimitedBody(String time);

  /// Foundation component / errorRateLimitedTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Let’s pause for a moment'**
  String get errorRateLimitedTitle;

  /// Foundation component / errorServerBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our side. Please try again.'**
  String get errorServerBody;

  /// Foundation component / errorServerTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'A small pause'**
  String get errorServerTitle;

  /// Foundation component / errorSourcesBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Sources are temporarily unavailable. Try again shortly.'**
  String get errorSourcesBody;

  /// Foundation component / errorSourcesTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Sources are taking a moment'**
  String get errorSourcesTitle;

  /// Foundation component / errorTooLargeBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Choose a smaller file and try again.'**
  String get errorTooLargeBody;

  /// Foundation component / errorTooLargeTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'This file is too large'**
  String get errorTooLargeTitle;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Accept invite'**
  String get friendsAccept;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code'**
  String get friendsAcceptCode;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'You’re now learning together'**
  String get friendsAccepted;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'You’re already friends.'**
  String get friendsAlreadyFriends;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get friendsCode;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'That code doesn’t work. Check it and try again.'**
  String get friendsInviteInvalid;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get friendsOffline;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get friendsOnline;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Remove friend'**
  String get friendsRemove;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from your friends?'**
  String friendsRemoveBody(String name);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get friendsShare;

  /// Foundation component / galleryBrand. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Brand and illustration'**
  String get galleryBrand;

  /// Foundation component / galleryButtons. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Buttons'**
  String get galleryButtons;

  /// Foundation component / galleryCardBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'A small light for a big journey'**
  String get galleryCardBody;

  /// Foundation component / galleryCelebrate. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Celebrate'**
  String get galleryCelebrate;

  /// Foundation component / galleryConfirm. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Confirmation sheet'**
  String get galleryConfirm;

  /// Foundation component / galleryDisabled. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get galleryDisabled;

  /// Foundation component / galleryEmptyBody. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'A little space for something new.'**
  String get galleryEmptyBody;

  /// Foundation component / galleryEmptyTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Your next step is on its way'**
  String get galleryEmptyTitle;

  /// Foundation component / galleryInputs. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Inputs and settings'**
  String get galleryInputs;

  /// Foundation component / galleryMotion. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get galleryMotion;

  /// Foundation component / galleryNudge. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Try a gentle nudge'**
  String get galleryNudge;

  /// Foundation component / galleryOpenSheet. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Open sheet'**
  String get galleryOpenSheet;

  /// Foundation component / gallerySheets. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Sheets and notices'**
  String get gallerySheets;

  /// Foundation component / galleryStates. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Loading, empty and error'**
  String get galleryStates;

  /// Foundation component / gallerySurfaces. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Cards and progress'**
  String get gallerySurfaces;

  /// Foundation component / galleryTitle. Short, warm interface wording.
  ///
  /// In en, this message translates to:
  /// **'Component gallery'**
  String get galleryTitle;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get glossaryAll;

  /// Prototype interface copy: glossary / askRaqeeb. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Ask Raqeeb'**
  String get glossaryAskRaqeeb;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Words you meet in lessons will appear here.'**
  String get glossaryEmpty;

  /// Prototype interface copy: glossary / iKnowThis. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I know this'**
  String get glossaryIKnowThis;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get glossaryLearning;

  /// Prototype interface copy: glossary / levelExplorer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Explained for explorers'**
  String get glossaryLevelExplorer;

  /// Prototype interface copy: glossary / levelNewMuslim. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Explained for new Muslims'**
  String get glossaryLevelNewMuslim;

  /// Prototype interface copy: glossary / listen. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get glossaryListen;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Show more words'**
  String get glossaryLoadMore;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Mastered'**
  String get glossaryMastered;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get glossaryNew;

  /// Prototype interface copy: glossary / underlineHint. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Once you’ve mastered a word, its underline disappears.'**
  String get glossaryUnderlineHint;

  /// Prototype interface copy: glossary / yourDictionary. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your dictionary'**
  String get glossaryYourDictionary;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get journeyAvailable;

  /// Prototype interface copy: journey / checkpoint. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Checkpoint'**
  String get journeyCheckpoint;

  /// Prototype interface copy: journey / comingSoonBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'This prototype includes one complete lesson: “Prayer: a river at your door”. The rest of the journey shows how the path unfolds.'**
  String get journeyComingSoonBody;

  /// Prototype interface copy: journey / comingSoonTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get journeyComingSoonTitle;

  /// Prototype interface copy: journey / dailyGoal. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get journeyDailyGoal;

  /// Prototype interface copy: journey / doneLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get journeyDoneLabel;

  /// Owner-requested web Android download banner; platform names describe design targets, only Android and web are currently distributed.
  ///
  /// In en, this message translates to:
  /// **'Download Android APK'**
  String get journeyDownloadAction;

  /// Owner-requested web Android download banner; platform names describe design targets, only Android and web are currently distributed.
  ///
  /// In en, this message translates to:
  /// **'Built for Android, iOS, Web, Windows, macOS and Linux. Try Qabas on Android today.'**
  String get journeyDownloadBody;

  /// Owner-requested web Android download banner; platform names describe design targets, only Android and web are currently distributed.
  ///
  /// In en, this message translates to:
  /// **'Dismiss Android download banner'**
  String get journeyDownloadDismiss;

  /// Owner-requested web Android download banner; platform names describe design targets, only Android and web are currently distributed.
  ///
  /// In en, this message translates to:
  /// **'BEYOND THE BROWSER'**
  String get journeyDownloadEyebrow;

  /// Owner-requested web Android download banner; platform names describe design targets, only Android and web are currently distributed.
  ///
  /// In en, this message translates to:
  /// **'The download could not open. Please try again.'**
  String get journeyDownloadFailed;

  /// Owner-requested web Android download banner; platform names describe design targets, only Android and web are currently distributed.
  ///
  /// In en, this message translates to:
  /// **'One journey. Across your devices.'**
  String get journeyDownloadTitle;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Your next steps will appear here. Try again in a moment.'**
  String get journeyEmptyBody;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Your path is being prepared'**
  String get journeyEmptyTitle;

  /// Prototype interface copy: journey / explorerPathHint. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'For the curious: big questions first'**
  String get journeyExplorerPathHint;

  /// Prototype interface copy: journey / goalProgress. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{done} / {goal} min'**
  String journeyGoalProgress(String done, String goal);

  /// Prototype interface copy: journey / greetingAfternoon. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get journeyGreetingAfternoon;

  /// Prototype interface copy: journey / greetingEvening. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get journeyGreetingEvening;

  /// Prototype interface copy: journey / greetingMorning. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get journeyGreetingMorning;

  /// Prototype interface copy: journey / guide. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get journeyGuide;

  /// Prototype interface copy: journey / jumpBack. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get journeyJumpBack;

  /// Prototype interface copy: journey / keepTheLight. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your path is lit. One small step today?'**
  String get journeyKeepTheLight;

  /// Prototype interface copy: journey / learnedTodayLine. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Today’s flame is lit. Beautiful work.'**
  String get journeyLearnedTodayLine;

  /// Prototype interface copy: journey / lesson. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get journeyLesson;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Start lesson  {reward}'**
  String journeyLessonAction(String reward);

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Lighting your path…'**
  String get journeyLoading;

  /// Prototype interface copy: journey / lockedBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Finish the steps before this one and the path will light up.'**
  String get journeyLockedBody;

  /// Prototype interface copy: journey / lockedTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get journeyLockedTitle;

  /// Prototype interface copy: journey / newMuslimPathHint. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'First steps in faith and practice'**
  String get journeyNewMuslimPathHint;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'{title} — {status}'**
  String journeyNodeSemantics(String title, String status);

  /// Prototype interface copy: journey / openPlayableLesson. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Try the sample lesson'**
  String get journeyOpenPlayableLesson;

  /// Prototype interface copy: journey / pathUnfolds. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'The path keeps unfolding as you grow'**
  String get journeyPathUnfolds;

  /// Prototype interface copy: journey / pillarNames1. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Testimony'**
  String get journeyPillarNames1;

  /// Prototype interface copy: journey / pillarNames2. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Prayer'**
  String get journeyPillarNames2;

  /// Prototype interface copy: journey / pillarNames3. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Zakah'**
  String get journeyPillarNames3;

  /// Prototype interface copy: journey / pillarNames4. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Pilgrimage'**
  String get journeyPillarNames4;

  /// Prototype interface copy: journey / pillarNames5. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get journeyPillarNames5;

  /// Prototype interface copy: journey / practice. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get journeyPractice;

  /// Prototype interface copy: journey / quickReview. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Quick review'**
  String get journeyQuickReview;

  /// Prototype interface copy: journey / reviewDue. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{countText} cards ready for a 60-second review'**
  String journeyReviewDue(String countText);

  /// Prototype interface copy: journey / reviewLesson. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Review lesson'**
  String get journeyReviewLesson;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Skip unit'**
  String get journeySkipUnit;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'You’re almost there. One earlier idea will make this lesson easier to understand.'**
  String get journeySoftLockBody;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'One idea first'**
  String get journeySoftLockTitle;

  /// Prototype interface copy: journey / startHere. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get journeyStartHere;

  /// Prototype interface copy: journey / startLesson. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Start lesson'**
  String get journeyStartLesson;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Start review'**
  String get journeyStartReview;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Start with: {title}'**
  String journeyStartWith(String title);

  /// Prototype interface copy: journey / story. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get journeyStory;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'Take the unit test'**
  String get journeyTakeUnitTest;

  /// Prototype interface copy: journey / unitComplete. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Unit complete'**
  String get journeyUnitComplete;

  /// Prototype interface copy: journey / unitN. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Unit {number}'**
  String journeyUnitN(String number);

  /// Prototype interface copy: journey / whatYoullLearn. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'In this unit'**
  String get journeyWhatYoullLearn;

  /// Prototype interface copy: journey / yourPath. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your path'**
  String get journeyYourPath;

  /// Phase 4 Journey/Discover interface copy; Arabic awaits owner wording review.
  ///
  /// In en, this message translates to:
  /// **'This part of your path is being prepared. Your progress is saved.'**
  String get learningEntryBody;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get mediaCamera;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t read that recording or file. Try again.'**
  String get mediaCaptureFailed;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'You can attach up to three images, one document and one voice recording.'**
  String get mediaCountLimit;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Documents can be up to 10 MB'**
  String get mediaDocumentLimit;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Images can be up to 8 MB'**
  String get mediaImageLimit;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to record. You can change this in settings.'**
  String get mediaMicrophoneDenied;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get mediaOpenSettings;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Recitations can be up to 30 seconds and 5 MB'**
  String get mediaRecitationLimit;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get mediaRecord;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Recording · {seconds} / {limit}s'**
  String mediaRecordingTime(String seconds, String limit);

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get mediaStopRecording;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Voice recordings can be up to 60 seconds and 10 MB'**
  String get mediaVoiceLimit;

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'أ'**
  String get onboardingArabicGlyph;

  /// Prototype interface copy: onboarding / chooseLanguage. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingChooseLanguage;

  /// Prototype interface copy: onboarding / companionHello. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Hello! I’ll carry the light while you find your way.'**
  String get onboardingCompanionHello;

  /// Prototype interface copy: onboarding / discreetBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'“Time for your daily lesson” — nothing more.'**
  String get onboardingDiscreetBody;

  /// Prototype interface copy: onboarding / discreetTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Discreet reminders'**
  String get onboardingDiscreetTitle;

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'Aa'**
  String get onboardingEnglishGlyph;

  /// Prototype interface copy: onboarding / explorerBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Big questions, clear answers, no pressure.'**
  String get onboardingExplorerBody;

  /// Prototype interface copy: onboarding / explorerTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I’m curious about Islam'**
  String get onboardingExplorerTitle;

  /// Prototype interface copy: onboarding / familiarBasics. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I know the basics'**
  String get onboardingFamiliarBasics;

  /// Prototype interface copy: onboarding / familiarNew. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Completely new to this'**
  String get onboardingFamiliarNew;

  /// Prototype interface copy: onboarding / familiarNote. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'We’ll start gently either way — a quick check later can skip what you know.'**
  String get onboardingFamiliarNote;

  /// Prototype interface copy: onboarding / familiarSome. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I know a little'**
  String get onboardingFamiliarSome;

  /// Prototype interface copy: onboarding / familiarTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'How familiar are you?'**
  String get onboardingFamiliarTitle;

  /// Prototype interface copy: onboarding / getStarted. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingGetStarted;

  /// Prototype interface copy: onboarding / goalBubble. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Small and steady beats big and rare.'**
  String get onboardingGoalBubble;

  /// Prototype interface copy: onboarding / goalDedicated. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Dedicated'**
  String get onboardingGoalDedicated;

  /// Prototype interface copy: onboarding / goalDeep. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Deep'**
  String get onboardingGoalDeep;

  /// Prototype interface copy: onboarding / goalGentle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Gentle'**
  String get onboardingGoalGentle;

  /// Prototype interface copy: onboarding / goalSteady. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Steady'**
  String get onboardingGoalSteady;

  /// Prototype interface copy: onboarding / goalTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'How much time feels right each day?'**
  String get onboardingGoalTitle;

  /// Prototype interface copy: onboarding / haveAccount. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get onboardingHaveAccount;

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'اختر لغتك'**
  String get onboardingLanguageArabicPrompt;

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get onboardingLanguageEnglishPrompt;

  /// Prototype interface copy: onboarding / languageHint. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You can change this any time in settings.'**
  String get onboardingLanguageHint;

  /// Prototype interface copy: onboarding / newMuslimBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'First steps in faith and practice, one at a time.'**
  String get onboardingNewMuslimBody;

  /// Prototype interface copy: onboarding / newMuslimTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I recently embraced Islam'**
  String get onboardingNewMuslimTitle;

  /// Prototype interface copy: onboarding / perDay. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{countText} min a day}}'**
  String onboardingPerDay(num count, String countText);

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get onboardingPreferNotToSay;

  /// Prototype interface copy: onboarding / privacyBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Learn privately if you prefer. Some people keep their journey to themselves — that’s completely fine.'**
  String get onboardingPrivacyBody;

  /// Prototype interface copy: onboarding / privacyTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your journey stays yours'**
  String get onboardingPrivacyTitle;

  /// Prototype interface copy: onboarding / privateBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Hide your activity from leagues and friends.'**
  String get onboardingPrivateBody;

  /// Prototype interface copy: onboarding / privateTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Private profile'**
  String get onboardingPrivateTitle;

  /// Prototype interface copy: onboarding / readyExplorer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'We’ll begin with the big questions, then see how Muslims live their faith day to day.'**
  String get onboardingReadyExplorer;

  /// Prototype interface copy: onboarding / readyNewMuslim. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'We’ll begin with your first steps — the testimony of faith, then prayer — gently, one at a time.'**
  String get onboardingReadyNewMuslim;

  /// Prototype interface copy: onboarding / readyTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your path is ready'**
  String get onboardingReadyTitle;

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'Reminder time: {time}'**
  String onboardingReminderTime(String time);

  /// Prototype interface copy: onboarding / reminderTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get onboardingReminderTitle;

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkipCuriosity;

  /// Prototype interface copy: onboarding / startMyJourney. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Start my journey'**
  String get onboardingStartMyJourney;

  /// Prototype interface copy: onboarding / stepOf. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepOf(String current, String total);

  /// Onboarding interface copy; Arabic new copy awaits owner review.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t start your journey. Your choices are kept.'**
  String get onboardingSubmitError;

  /// Prototype interface copy: onboarding / welcomeBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Short lessons, authentic sources and a friendly guide — at your own pace.'**
  String get onboardingWelcomeBody;

  /// Prototype interface copy: onboarding / welcomeExplorer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Welcome. Ask anything — you’re among friends here.'**
  String get onboardingWelcomeExplorer;

  /// Prototype interface copy: onboarding / welcomeNewMuslim. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Welcome, and congratulations. We’ll walk this together, one step at a time.'**
  String get onboardingWelcomeNewMuslim;

  /// Prototype interface copy: onboarding / welcomeTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A small light for a big journey'**
  String get onboardingWelcomeTitle;

  /// Prototype interface copy: onboarding / whoBubble. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'There are no wrong answers. I’ll shape the path around you.'**
  String get onboardingWhoBubble;

  /// Prototype interface copy: onboarding / whoTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'What brings you to Qabas?'**
  String get onboardingWhoTitle;

  /// Prototype interface copy: profile / achievementsTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get profileAchievementsTitle;

  /// Prototype interface copy: profile / editName. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get profileEditName;

  /// Prototype interface copy: profile / joined. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Joined {month}'**
  String profileJoined(String month);

  /// Phase 10 profile interface copy.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank}'**
  String profileLeagueRank(String rank);

  /// Prototype interface copy: profile / learnerName. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Learner'**
  String get profileLearnerName;

  /// Phase 10 profile interface copy.
  ///
  /// In en, this message translates to:
  /// **'Use 2–24 characters.'**
  String get profileNameValidation;

  /// Prototype interface copy: profile / newBadge. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'New badge!'**
  String get profileNewBadge;

  /// Phase 10 profile interface copy.
  ///
  /// In en, this message translates to:
  /// **'Your first badge is waiting ahead.'**
  String get profileNoAchievements;

  /// Phase 10 profile interface copy.
  ///
  /// In en, this message translates to:
  /// **'No league yet'**
  String get profileNoLeague;

  /// Phase 10 profile interface copy.
  ///
  /// In en, this message translates to:
  /// **'Your words will appear here as you learn.'**
  String get profileNoWords;

  /// Prototype interface copy: profile / privateBadge. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get profilePrivateBadge;

  /// Prototype interface copy: profile / profileTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileProfileTitle;

  /// Prototype interface copy: profile / save. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// Prototype interface copy: profile / settings. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// Prototype interface copy: profile / statBadges. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Badges'**
  String get profileStatBadges;

  /// Prototype interface copy: profile / statLeague. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'League'**
  String get profileStatLeague;

  /// Prototype interface copy: profile / statLessons. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get profileStatLessons;

  /// Prototype interface copy: profile / statStreak. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Day streak'**
  String get profileStatStreak;

  /// Prototype interface copy: profile / statTotal. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Total embers'**
  String get profileStatTotal;

  /// Prototype interface copy: profile / statWords. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Words mastered'**
  String get profileStatWords;

  /// Prototype interface copy: profile / statistics. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get profileStatistics;

  /// Prototype interface copy: profile / unlockedOf. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total} unlocked'**
  String profileUnlockedOf(String current, String total);

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Referred or left unanswered'**
  String get raqeebAbstained;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Acceptable'**
  String get raqeebAcceptable;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Related authentic text'**
  String get raqeebAlternative;

  /// Prototype interface copy: raqeeb / askAnything. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Ask anything…'**
  String get raqeebAskAnything;

  /// Prototype interface copy: raqeeb / askSpecialist. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Ask a specialist privately'**
  String get raqeebAskSpecialist;

  /// Prototype interface copy: raqeeb / attachDoc. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A document'**
  String get raqeebAttachDoc;

  /// Prototype interface copy: raqeeb / attachDocBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Raqeeb reads it and answers with sources'**
  String get raqeebAttachDocBody;

  /// Prototype interface copy: raqeeb / attachPhoto. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A photo'**
  String get raqeebAttachPhoto;

  /// Prototype interface copy: raqeeb / attachPhotoBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A sign, a page, a post you saw'**
  String get raqeebAttachPhotoBody;

  /// Prototype interface copy: raqeeb / attachTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Ask with…'**
  String get raqeebAttachTitle;

  /// Prototype interface copy: raqeeb / attachVoice. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your voice'**
  String get raqeebAttachVoice;

  /// Prototype interface copy: raqeeb / attachVoiceBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Just ask out loud'**
  String get raqeebAttachVoiceBody;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Authentic'**
  String get raqeebAuthentic;

  /// Prototype interface copy: raqeeb / authenticityCheck. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Authenticity check'**
  String get raqeebAuthenticityCheck;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Exact text'**
  String get raqeebExactText;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Fabricated'**
  String get raqeebFabricated;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'I couldn’t finish this answer. Let’s try again.'**
  String get raqeebFailed;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Found in'**
  String get raqeebFoundIn;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get raqeebGrade;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Other grading'**
  String get raqeebGradeOther;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Graded by'**
  String get raqeebGrader;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get raqeebHistory;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get raqeebLearnMore;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Needs a specialist'**
  String get raqeebNeedsSpecialist;

  /// Prototype interface copy: raqeeb / newChat. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'New question'**
  String get raqeebNewChat;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Your conversations will appear here'**
  String get raqeebNoHistory;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Not found in the available sources'**
  String get raqeebNotFound;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get raqeebNotSent;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get raqeebOpen;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Raqeeb is still answering…'**
  String get raqeebProcessing;

  /// Prototype interface copy: raqeeb / prototypeAnswer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'In this prototype I answer a few sample questions — try one of the suggestions. In the full app, I answer from reviewed sources and show where every answer comes from.'**
  String get raqeebPrototypeAnswer;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Matches the Quran'**
  String get raqeebQuranExact;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'The verse text is inexact'**
  String get raqeebQuranInexact;

  /// Prototype interface copy: raqeeb / raqeebName. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Raqeeb'**
  String get raqeebRaqeebName;

  /// Prototype interface copy: raqeeb / raqeebTagline. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your trusted guide to reliable answers'**
  String get raqeebRaqeebTagline;

  /// Prototype interface copy: raqeeb / raqeebThinking. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Checking the sources…'**
  String get raqeebRaqeebThinking;

  /// Prototype interface copy: raqeeb / raqeebTrust1. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Answers from reviewed, reliable sources'**
  String get raqeebRaqeebTrust1;

  /// Prototype interface copy: raqeeb / raqeebTrust2. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Shows where every answer comes from'**
  String get raqeebRaqeebTrust2;

  /// Prototype interface copy: raqeeb / raqeebTrust3. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Checks whether quotes and hadiths are authentic'**
  String get raqeebRaqeebTrust3;

  /// Prototype interface copy: raqeeb / raqeebTrust4. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Refers you to a specialist when needed'**
  String get raqeebRaqeebTrust4;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'This answer could be clearer'**
  String get raqeebRateDown;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save your rating. Try again.'**
  String get raqeebRateFailed;

  /// Raqeeb request rate limit; calm retry guidance.
  ///
  /// In en, this message translates to:
  /// **'You’ve asked a lot in a short time. Let’s pause before trying again.'**
  String get raqeebRateLimited;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'This answer helped'**
  String get raqeebRateUp;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get raqeebSending;

  /// Prototype interface copy: raqeeb / sources. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get raqeebSources;

  /// Prototype interface copy: raqeeb / specialistSent. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Sent privately — you’ll be notified when they reply.'**
  String get raqeebSpecialistSent;

  /// Prototype interface copy: raqeeb / specialistTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A specialist can help'**
  String get raqeebSpecialistTitle;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Making the answer clearer for you…'**
  String get raqeebStageAdapting;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Understanding your question…'**
  String get raqeebStageClassifying;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Reading what you sent…'**
  String get raqeebStageReading;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Receiving your question…'**
  String get raqeebStageReceived;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Looking through the sources…'**
  String get raqeebStageRetrieving;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Checking the sources…'**
  String get raqeebStageVerifying;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Writing your answer…'**
  String get raqeebStageWriting;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Can I pray before I know Arabic?'**
  String get raqeebSuggestionArabic;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Is this hadith authentic? “The five prayers are like a river at your door.”'**
  String get raqeebSuggestionHadith;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'What does the word “Islam” mean?'**
  String get raqeebSuggestionIslam;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Why do Muslims pray five times a day?'**
  String get raqeebSuggestionPrayer;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Keep your question within 2,000 characters.'**
  String get raqeebTextLimit;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Your text question'**
  String get raqeebTextOnly;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'You can ask a written question here. Voice, photos and documents will be available later.'**
  String get raqeebTextOnlyPhase;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'This answer is taking longer than expected. You can try again.'**
  String get raqeebTimeout;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Only part of the document was read'**
  String get raqeebTruncated;

  /// Prototype interface copy: raqeeb / tryAsking. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Try asking'**
  String get raqeebTryAsking;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'What I understood from your message'**
  String get raqeebUnderstood;

  /// Raqeeb text conversation interface; preserve the calm prototype wording.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get raqeebWeak;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Record again'**
  String get recitationAgain;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Recitation checking is busy. Try again or skip.'**
  String get recitationBusy;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get recitationChecking;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Continue with this reading'**
  String get recitationContinue;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get recitationCorrectWord;

  /// Developer-only synthetic fixture controls; Arabic pending review.
  ///
  /// In en, this message translates to:
  /// **'Missing and extra words'**
  String get recitationDeveloperMissingExtra;

  /// Developer-only synthetic fixture controls; Arabic pending review.
  ///
  /// In en, this message translates to:
  /// **'Synthetic recitation outcome (development only)'**
  String get recitationDeveloperOutcome;

  /// Developer-only synthetic fixture controls; Arabic pending review.
  ///
  /// In en, this message translates to:
  /// **'Unclear recording'**
  String get recitationDeveloperUnclear;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'An extra word'**
  String get recitationExtraWord;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get recitationMissingWord;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Try checking again'**
  String get recitationRetry;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Try this word again'**
  String get recitationSubstitutedWord;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'{word}: {result}'**
  String recitationWordFeedback(String word, String result);

  /// Prototype interface copy: review / again. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get reviewAgain;

  /// Prototype interface copy: review / cardsReady. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{countText} cards are ready'**
  String reviewCardsReady(String countText);

  /// Prototype interface copy: review / easy. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get reviewEasy;

  /// Prototype interface copy: review / good. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get reviewGood;

  /// Prototype interface copy: review / hard. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get reviewHard;

  /// Prototype interface copy: review / howWell. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'How well did you remember?'**
  String get reviewHowWell;

  /// Prototype interface copy: review / intervals1. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'1 min'**
  String get reviewIntervals1;

  /// Prototype interface copy: review / intervals2. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get reviewIntervals2;

  /// Prototype interface copy: review / intervals3. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'3 days'**
  String get reviewIntervals3;

  /// Prototype interface copy: review / intervals4. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get reviewIntervals4;

  /// Prototype interface copy: review / reviewDone. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Review complete'**
  String get reviewReviewDone;

  /// Prototype interface copy: review / reviewDoneBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'These will come back right before you’d forget them.'**
  String get reviewReviewDoneBody;

  /// Prototype interface copy: review / reviewSubtitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Small, well-timed reviews help what you learn stay with you.'**
  String get reviewReviewSubtitle;

  /// Prototype interface copy: review / reviewTiming. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Timed by how well you remember each one'**
  String get reviewReviewTiming;

  /// Prototype interface copy: review / reviewTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewReviewTitle;

  /// Prototype interface copy: review / startReview. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Start 60-second review'**
  String get reviewStartReview;

  /// Prototype interface copy: review / tapToFlip. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tap the card to see the answer'**
  String get reviewTapToFlip;

  /// Prototype interface copy: review / wordsMasteredOf. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{mastered} of {total} mastered'**
  String reviewWordsMasteredOf(String mastered, String total);

  /// Prototype interface copy: review / yourWords. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get reviewYourWords;

  /// Reviewer work tool: reviewerAbstention
  ///
  /// In en, this message translates to:
  /// **'Correct abstention (%)'**
  String get reviewerAbstention;

  /// Explain live reviewer sign-in and preserved learner progress.
  ///
  /// In en, this message translates to:
  /// **'Reviewers sign in with their account to review lesson plans and drafts, run blind comparisons and view metrics. Your learning progress on this device returns when you sign out.'**
  String get reviewerAccountDescription;

  /// Reviewer work tool: reviewerAccuracy
  ///
  /// In en, this message translates to:
  /// **'Accuracy (%)'**
  String get reviewerAccuracy;

  /// Reviewer work tool: reviewerAccurate
  ///
  /// In en, this message translates to:
  /// **'Which lesson is more accurate?'**
  String get reviewerAccurate;

  /// Reviewer work tool: reviewerActivated
  ///
  /// In en, this message translates to:
  /// **'Misconceptions activated'**
  String get reviewerActivated;

  /// Reviewer work tool: reviewerAdd
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get reviewerAdd;

  /// Reviewer work tool: reviewerAfter
  ///
  /// In en, this message translates to:
  /// **'After'**
  String get reviewerAfter;

  /// Reviewer work tool: reviewerAllStatuses
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get reviewerAllStatuses;

  /// Reviewer work tool: reviewerAnswerKey
  ///
  /// In en, this message translates to:
  /// **'Answer key'**
  String get reviewerAnswerKey;

  /// Reviewer work tool: reviewerApprove
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get reviewerApprove;

  /// Reviewer work tool: reviewerArc
  ///
  /// In en, this message translates to:
  /// **'Lesson arc'**
  String get reviewerArc;

  /// Reviewer work tool: reviewerArcMap
  ///
  /// In en, this message translates to:
  /// **'Arc map'**
  String get reviewerArcMap;

  /// Reviewer work tool: reviewerBasis
  ///
  /// In en, this message translates to:
  /// **'Claim basis'**
  String get reviewerBasis;

  /// Reviewer work tool: reviewerBefore
  ///
  /// In en, this message translates to:
  /// **'Before'**
  String get reviewerBefore;

  /// Reviewer work tool: reviewerBenchmark
  ///
  /// In en, this message translates to:
  /// **'Raqeeb benchmark'**
  String get reviewerBenchmark;

  /// Reviewer work tool: reviewerBlindEmpty
  ///
  /// In en, this message translates to:
  /// **'No blind-test pairs remain.'**
  String get reviewerBlindEmpty;

  /// Reviewer work tool: reviewerBlindTest
  ///
  /// In en, this message translates to:
  /// **'Blind test'**
  String get reviewerBlindTest;

  /// Reviewer work tool: reviewerBlockPosition
  ///
  /// In en, this message translates to:
  /// **'Block {current} of {total}'**
  String reviewerBlockPosition(int current, int total);

  /// Reviewer work tool: reviewerBlocker
  ///
  /// In en, this message translates to:
  /// **'Blocker'**
  String get reviewerBlocker;

  /// Reviewer work tool: reviewerBlockers
  ///
  /// In en, this message translates to:
  /// **'Approval is unavailable while blockers remain.'**
  String get reviewerBlockers;

  /// Reviewer work tool: reviewerBrief
  ///
  /// In en, this message translates to:
  /// **'Lesson brief'**
  String get reviewerBrief;

  /// Reviewer work tool: reviewerClearer
  ///
  /// In en, this message translates to:
  /// **'Which lesson is clearer?'**
  String get reviewerClearer;

  /// Reviewer work tool: reviewerCommaIds
  ///
  /// In en, this message translates to:
  /// **'Comma-separated identifiers'**
  String get reviewerCommaIds;

  /// Reviewer work tool: reviewerCompiled
  ///
  /// In en, this message translates to:
  /// **'Built-in · compiled'**
  String get reviewerCompiled;

  /// Reviewer work tool: reviewerConsole
  ///
  /// In en, this message translates to:
  /// **'Reviewer console'**
  String get reviewerConsole;

  /// Reviewer work tool: reviewerContentBudget
  ///
  /// In en, this message translates to:
  /// **'Content blocks'**
  String get reviewerContentBudget;

  /// Reviewer work tool: reviewerCreate
  ///
  /// In en, this message translates to:
  /// **'Create run'**
  String get reviewerCreate;

  /// Reviewer work tool: reviewerDepth
  ///
  /// In en, this message translates to:
  /// **'Depth profile'**
  String get reviewerDepth;

  /// Reviewer work tool: reviewerDone
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reviewerDone;

  /// Reviewer work tool: reviewerEditAr
  ///
  /// In en, this message translates to:
  /// **'Replacement Arabic text'**
  String get reviewerEditAr;

  /// Reviewer work tool: reviewerEditEn
  ///
  /// In en, this message translates to:
  /// **'Replacement English text'**
  String get reviewerEditEn;

  /// Reviewer work tool: reviewerEditPlan
  ///
  /// In en, this message translates to:
  /// **'Edit plan'**
  String get reviewerEditPlan;

  /// Reviewer work tool: reviewerEditSentence
  ///
  /// In en, this message translates to:
  /// **'Edit sentence'**
  String get reviewerEditSentence;

  /// Reviewer work tool: reviewerEditsSaved
  ///
  /// In en, this message translates to:
  /// **'Edits saved for approval.'**
  String get reviewerEditsSaved;

  /// Reviewer work tool: reviewerEmail
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get reviewerEmail;

  /// Reviewer work tool: reviewerEvidence
  ///
  /// In en, this message translates to:
  /// **'Sentences and evidence'**
  String get reviewerEvidence;

  /// Reviewer work tool: reviewerExerciseBudget
  ///
  /// In en, this message translates to:
  /// **'Graded exercises (2–6)'**
  String get reviewerExerciseBudget;

  /// Reviewer work tool: reviewerExercises
  ///
  /// In en, this message translates to:
  /// **'Exercises and answer keys'**
  String get reviewerExercises;

  /// Reviewer work tool: reviewerExperience
  ///
  /// In en, this message translates to:
  /// **'Learner experience'**
  String get reviewerExperience;

  /// Reviewer work tool: reviewerFactory
  ///
  /// In en, this message translates to:
  /// **'Lesson factory'**
  String get reviewerFactory;

  /// Reviewer work tool: reviewerGate1
  ///
  /// In en, this message translates to:
  /// **'Gate 1 · Plan review'**
  String get reviewerGate1;

  /// Reviewer work tool: reviewerGate2
  ///
  /// In en, this message translates to:
  /// **'Gate 2 · Draft review'**
  String get reviewerGate2;

  /// Reviewer work tool: reviewerGenerationMinutes
  ///
  /// In en, this message translates to:
  /// **'Average generation (minutes)'**
  String get reviewerGenerationMinutes;

  /// Reviewer work tool: reviewerHandwritten
  ///
  /// In en, this message translates to:
  /// **'Which lesson do you think was written by a person?'**
  String get reviewerHandwritten;

  /// Reviewer work tool: reviewerIdentified
  ///
  /// In en, this message translates to:
  /// **'Handwritten identified (%)'**
  String get reviewerIdentified;

  /// Reviewer work tool formatted value
  ///
  /// In en, this message translates to:
  /// **'{left} → {right}'**
  String reviewerIdsPair(String left, String right);

  /// Reviewer work tool: reviewerInfo
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get reviewerInfo;

  /// Reviewer work tool: reviewerInteractive
  ///
  /// In en, this message translates to:
  /// **'Learner acts'**
  String get reviewerInteractive;

  /// Reviewer work tool: reviewerIntroduced
  ///
  /// In en, this message translates to:
  /// **'Introduced concepts'**
  String get reviewerIntroduced;

  /// Reviewer sign-in rejected the email or password.
  ///
  /// In en, this message translates to:
  /// **'That email or password isn\'t right. Please try again.'**
  String get reviewerInvalidCredentials;

  /// Reviewer work tool: reviewerInvalidPlan
  ///
  /// In en, this message translates to:
  /// **'Check bilingual fields, objectives, concepts, arc and budgets before approval.'**
  String get reviewerInvalidPlan;

  /// Reviewer work tool: reviewerLearning
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get reviewerLearning;

  /// Reviewer work tool: reviewerLessonA
  ///
  /// In en, this message translates to:
  /// **'Lesson A'**
  String get reviewerLessonA;

  /// Reviewer work tool: reviewerLessonB
  ///
  /// In en, this message translates to:
  /// **'Lesson B'**
  String get reviewerLessonB;

  /// Reviewer work tool: reviewerLessonType
  ///
  /// In en, this message translates to:
  /// **'Lesson type'**
  String get reviewerLessonType;

  /// Reviewer work tool: reviewerLockout
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait before trying again.'**
  String get reviewerLockout;

  /// Reviewer work tool: reviewerMetrics
  ///
  /// In en, this message translates to:
  /// **'Metrics'**
  String get reviewerMetrics;

  /// Reviewer work tool: reviewerMinutes
  ///
  /// In en, this message translates to:
  /// **'Estimated minutes'**
  String get reviewerMinutes;

  /// Reviewer work tool: reviewerMisconceptions
  ///
  /// In en, this message translates to:
  /// **'Target misconceptions'**
  String get reviewerMisconceptions;

  /// Reviewer work tool: reviewerMore
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get reviewerMore;

  /// Reviewer work tool: reviewerNewRun
  ///
  /// In en, this message translates to:
  /// **'New run'**
  String get reviewerNewRun;

  /// Reviewer work tool: reviewerNoIssues
  ///
  /// In en, this message translates to:
  /// **'No QA findings.'**
  String get reviewerNoIssues;

  /// Reviewer work tool: reviewerNoKey
  ///
  /// In en, this message translates to:
  /// **'Self-rated or checked recitation; no stored answer key.'**
  String get reviewerNoKey;

  /// Reviewer work tool: reviewerNoMetrics
  ///
  /// In en, this message translates to:
  /// **'No measurements are available.'**
  String get reviewerNoMetrics;

  /// Reviewer work tool: reviewerNoRuns
  ///
  /// In en, this message translates to:
  /// **'No runs match this filter.'**
  String get reviewerNoRuns;

  /// Reviewer work tool: reviewerNotMeasured
  ///
  /// In en, this message translates to:
  /// **'Not measured yet'**
  String get reviewerNotMeasured;

  /// Reviewer work tool: reviewerNotSupporting
  ///
  /// In en, this message translates to:
  /// **'Does not support this claim'**
  String get reviewerNotSupporting;

  /// Reviewer work tool: reviewerNote
  ///
  /// In en, this message translates to:
  /// **'Review note'**
  String get reviewerNote;

  /// Reviewer work tool: reviewerObjectives
  ///
  /// In en, this message translates to:
  /// **'Objectives (1–3)'**
  String get reviewerObjectives;

  /// Reviewer work tool: reviewerOpenRun
  ///
  /// In en, this message translates to:
  /// **'Open run'**
  String get reviewerOpenRun;

  /// Reviewer work tool: reviewerOutcome
  ///
  /// In en, this message translates to:
  /// **'Primary learning outcome'**
  String get reviewerOutcome;

  /// Reviewer work tool: reviewerPairedEnglish
  ///
  /// In en, this message translates to:
  /// **'An Arabic edit requires the matching English edit for this sentence and track.'**
  String get reviewerPairedEnglish;

  /// Reviewer work tool: reviewerParticipants
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get reviewerParticipants;

  /// Reviewer work tool formatted value
  ///
  /// In en, this message translates to:
  /// **'Participants: {value}'**
  String reviewerParticipantsValue(String value);

  /// Reviewer work tool: reviewerPassword
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get reviewerPassword;

  /// Reviewer work tool: reviewerPending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get reviewerPending;

  /// Reviewer work tool formatted value
  ///
  /// In en, this message translates to:
  /// **'{label} · {value}%'**
  String reviewerPercentValue(String label, String value);

  /// Reviewer metric percentage, with localized digits.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String reviewerPercentageNumber(String value);

  /// Reviewer work tool: reviewerPlaceholder
  ///
  /// In en, this message translates to:
  /// **'Placeholder / requires review'**
  String get reviewerPlaceholder;

  /// Reviewer work tool: reviewerPlan
  ///
  /// In en, this message translates to:
  /// **'Lesson plan'**
  String get reviewerPlan;

  /// Reviewer work tool: reviewerPosition
  ///
  /// In en, this message translates to:
  /// **'Position in unit (from 0)'**
  String get reviewerPosition;

  /// Reviewer work tool: reviewerPrePost
  ///
  /// In en, this message translates to:
  /// **'Before / after assessment'**
  String get reviewerPrePost;

  /// Reviewer work tool: reviewerPreferred
  ///
  /// In en, this message translates to:
  /// **'Generated preferred or same (%)'**
  String get reviewerPreferred;

  /// Reviewer work tool: reviewerPrerequisites
  ///
  /// In en, this message translates to:
  /// **'Prerequisite concepts'**
  String get reviewerPrerequisites;

  /// Reviewer work tool: reviewerPreview
  ///
  /// In en, this message translates to:
  /// **'Learner preview'**
  String get reviewerPreview;

  /// Reviewer work tool: reviewerPreviewEmpty
  ///
  /// In en, this message translates to:
  /// **'No preview blocks are available.'**
  String get reviewerPreviewEmpty;

  /// Reviewer work tool: reviewerPublished
  ///
  /// In en, this message translates to:
  /// **'Lessons published'**
  String get reviewerPublished;

  /// Reviewer work tool: reviewerQA
  ///
  /// In en, this message translates to:
  /// **'QA report'**
  String get reviewerQA;

  /// Reviewer work tool: reviewerQuestion
  ///
  /// In en, this message translates to:
  /// **'Central learner question'**
  String get reviewerQuestion;

  /// Reviewer work tool: reviewerRationale
  ///
  /// In en, this message translates to:
  /// **'Rationale'**
  String get reviewerRationale;

  /// Reviewer work tool: reviewerReasonRequired
  ///
  /// In en, this message translates to:
  /// **'Add a review note explaining the requested changes.'**
  String get reviewerReasonRequired;

  /// Reviewer work tool: reviewerReasoning
  ///
  /// In en, this message translates to:
  /// **'Reasoning tools and justifications'**
  String get reviewerReasoning;

  /// Reviewer work tool: reviewerReconfirm
  ///
  /// In en, this message translates to:
  /// **'I have reviewed the latest version'**
  String get reviewerReconfirm;

  /// Reviewer work tool: reviewerReferral
  ///
  /// In en, this message translates to:
  /// **'Correct referral (%)'**
  String get reviewerReferral;

  /// Reviewer work tool: reviewerRegenerate
  ///
  /// In en, this message translates to:
  /// **'Regenerate image'**
  String get reviewerRegenerate;

  /// Reviewer work tool: reviewerRegenerationAccepted
  ///
  /// In en, this message translates to:
  /// **'Regeneration accepted. The placeholder remains until an audited asset is available.'**
  String get reviewerRegenerationAccepted;

  /// Reviewer work tool: reviewerReject
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reviewerReject;

  /// Reviewer work tool: reviewerRemove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get reviewerRemove;

  /// Reviewer work tool: reviewerRemoveExercise
  ///
  /// In en, this message translates to:
  /// **'Remove on approval'**
  String get reviewerRemoveExercise;

  /// Reviewer work tool: reviewerRequestChanges
  ///
  /// In en, this message translates to:
  /// **'Request changes'**
  String get reviewerRequestChanges;

  /// Reviewer work tool: reviewerResolutionRate
  ///
  /// In en, this message translates to:
  /// **'Resolution rate (%)'**
  String get reviewerResolutionRate;

  /// Reviewer work tool: reviewerResolved
  ///
  /// In en, this message translates to:
  /// **'Misconceptions resolved'**
  String get reviewerResolved;

  /// Reviewer work tool: reviewerResponses
  ///
  /// In en, this message translates to:
  /// **'Blind-test responses'**
  String get reviewerResponses;

  /// Reviewer work tool: reviewerReveal
  ///
  /// In en, this message translates to:
  /// **'Continue preview'**
  String get reviewerReveal;

  /// Reviewer work tool: reviewerReviewMinutes
  ///
  /// In en, this message translates to:
  /// **'Average review (minutes)'**
  String get reviewerReviewMinutes;

  /// Reviewer work tool: reviewerRole
  ///
  /// In en, this message translates to:
  /// **'Sentence role'**
  String get reviewerRole;

  /// Reviewer work tool: reviewerRuns
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get reviewerRuns;

  /// Reviewer work tool: reviewerSame
  ///
  /// In en, this message translates to:
  /// **'Same'**
  String get reviewerSame;

  /// Explain sample reviewer content and preserved learner progress.
  ///
  /// In en, this message translates to:
  /// **'Review lesson plans and drafts, compare lessons in a blind test, and explore sample metrics. This preview uses sample content; your learning progress is saved when you return.'**
  String get reviewerSampleDescription;

  /// Open the local competition reviewer preview.
  ///
  /// In en, this message translates to:
  /// **'Explore reviewer dashboard'**
  String get reviewerSampleOpen;

  /// Reviewer work tool: reviewerSaveEdits
  ///
  /// In en, this message translates to:
  /// **'Save paired edits'**
  String get reviewerSaveEdits;

  /// Reviewer work tool: reviewerSavePlan
  ///
  /// In en, this message translates to:
  /// **'Save plan'**
  String get reviewerSavePlan;

  /// Reviewer work tool: reviewerSelectRun
  ///
  /// In en, this message translates to:
  /// **'Select a run to review its plan or draft.'**
  String get reviewerSelectRun;

  /// Reviewer work tool: reviewerSignIn
  ///
  /// In en, this message translates to:
  /// **'Reviewer sign in'**
  String get reviewerSignIn;

  /// Reviewer work tool: reviewerSignOut
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get reviewerSignOut;

  /// Reviewer work tool: reviewerSkipped
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get reviewerSkipped;

  /// Reviewer work tool: reviewerStage
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get reviewerStage;

  /// Reviewer work tool: reviewerStale
  ///
  /// In en, this message translates to:
  /// **'This review changed. The latest run has been loaded. Review it again before submitting a decision.'**
  String get reviewerStale;

  /// Reviewer work tool: reviewerStandalone
  ///
  /// In en, this message translates to:
  /// **'Eligible for Discover'**
  String get reviewerStandalone;

  /// Reviewer work tool formatted value
  ///
  /// In en, this message translates to:
  /// **'{status} · {stage}'**
  String reviewerStatusStage(String status, String stage);

  /// Reviewer work tool: reviewerSubmit
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get reviewerSubmit;

  /// Reviewer work tool: reviewerSupports
  ///
  /// In en, this message translates to:
  /// **'Supporting evidence'**
  String get reviewerSupports;

  /// Reviewer work tool: reviewerTargets
  ///
  /// In en, this message translates to:
  /// **'Guidance: 6–10 minutes; foundational lessons about 8–10. Usually 3–5 exercises (story: 2–4). Completeness takes priority; never pad or split by duration alone.'**
  String get reviewerTargets;

  /// Reviewer work tool: reviewerTerms
  ///
  /// In en, this message translates to:
  /// **'New terms'**
  String get reviewerTerms;

  /// Reviewer work tool: reviewerTitle
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get reviewerTitle;

  /// Reviewer work tool: reviewerUnderstandings
  ///
  /// In en, this message translates to:
  /// **'Supporting understandings'**
  String get reviewerUnderstandings;

  /// Reviewer work tool: reviewerUnitId
  ///
  /// In en, this message translates to:
  /// **'Unit ID'**
  String get reviewerUnitId;

  /// Reviewer work tool: reviewerUnitsCompleted
  ///
  /// In en, this message translates to:
  /// **'Units completed'**
  String get reviewerUnitsCompleted;

  /// Reviewer work tool: reviewerUnitsStarted
  ///
  /// In en, this message translates to:
  /// **'Units started'**
  String get reviewerUnitsStarted;

  /// Reviewer work tool: reviewerUnsupported
  ///
  /// In en, this message translates to:
  /// **'Unsupported claims (%)'**
  String get reviewerUnsupported;

  /// Reviewer work tool: reviewerUnsure
  ///
  /// In en, this message translates to:
  /// **'Unsure'**
  String get reviewerUnsure;

  /// Reviewer work tool: reviewerValidation
  ///
  /// In en, this message translates to:
  /// **'Validation findings'**
  String get reviewerValidation;

  /// Reviewer work tool: reviewerValueAddresseeSpecific
  ///
  /// In en, this message translates to:
  /// **'Addressee specific'**
  String get reviewerValueAddresseeSpecific;

  /// Reviewer work tool: reviewerValueAwaitingGate1
  ///
  /// In en, this message translates to:
  /// **'Awaiting Gate 1'**
  String get reviewerValueAwaitingGate1;

  /// Reviewer work tool: reviewerValueAwaitingGate2
  ///
  /// In en, this message translates to:
  /// **'Awaiting Gate 2'**
  String get reviewerValueAwaitingGate2;

  /// Reviewer work tool: reviewerValueBaselineLlm
  ///
  /// In en, this message translates to:
  /// **'Baseline model'**
  String get reviewerValueBaselineLlm;

  /// Reviewer work tool: reviewerValueBeliefGrading
  ///
  /// In en, this message translates to:
  /// **'Belief grading'**
  String get reviewerValueBeliefGrading;

  /// Reviewer work tool: reviewerValueBeyondSource
  ///
  /// In en, this message translates to:
  /// **'Beyond the source'**
  String get reviewerValueBeyondSource;

  /// Reviewer work tool: reviewerValueCausalReasoning
  ///
  /// In en, this message translates to:
  /// **'Causal reasoning'**
  String get reviewerValueCausalReasoning;

  /// Reviewer work tool: reviewerValueCircularReasoning
  ///
  /// In en, this message translates to:
  /// **'Circular reasoning'**
  String get reviewerValueCircularReasoning;

  /// Reviewer work tool: reviewerValueClaim
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get reviewerValueClaim;

  /// Reviewer work tool: reviewerValueComparison
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get reviewerValueComparison;

  /// Reviewer work tool: reviewerValueConcept
  ///
  /// In en, this message translates to:
  /// **'Concept'**
  String get reviewerValueConcept;

  /// Reviewer work tool: reviewerValueConsistency
  ///
  /// In en, this message translates to:
  /// **'Consistency'**
  String get reviewerValueConsistency;

  /// Reviewer work tool: reviewerValueContextDependent
  ///
  /// In en, this message translates to:
  /// **'Context dependent'**
  String get reviewerValueContextDependent;

  /// Reviewer work tool: reviewerValueDecompose
  ///
  /// In en, this message translates to:
  /// **'Decompose'**
  String get reviewerValueDecompose;

  /// Reviewer work tool: reviewerValueDemonstration
  ///
  /// In en, this message translates to:
  /// **'Demonstration'**
  String get reviewerValueDemonstration;

  /// Reviewer work tool: reviewerValueDifferingOpinions
  ///
  /// In en, this message translates to:
  /// **'Differing opinions'**
  String get reviewerValueDifferingOpinions;

  /// Reviewer work tool: reviewerValueDone
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get reviewerValueDone;

  /// Reviewer work tool: reviewerValueDoubtOrDeepCreed
  ///
  /// In en, this message translates to:
  /// **'Doubt or deep creed'**
  String get reviewerValueDoubtOrDeepCreed;

  /// Reviewer work tool: reviewerValueDropped
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get reviewerValueDropped;

  /// Reviewer work tool: reviewerValueEvidence
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get reviewerValueEvidence;

  /// Reviewer work tool: reviewerValueExact
  ///
  /// In en, this message translates to:
  /// **'Exact fit'**
  String get reviewerValueExact;

  /// Reviewer work tool: reviewerValueExample
  ///
  /// In en, this message translates to:
  /// **'Example'**
  String get reviewerValueExample;

  /// Reviewer work tool: reviewerValueExercises
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get reviewerValueExercises;

  /// Reviewer work tool: reviewerValueExplanation
  ///
  /// In en, this message translates to:
  /// **'Explanation'**
  String get reviewerValueExplanation;

  /// Reviewer work tool: reviewerValueExplorer
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get reviewerValueExplorer;

  /// Reviewer work tool: reviewerValueFailed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get reviewerValueFailed;

  /// Reviewer work tool: reviewerValueFatwaLike
  ///
  /// In en, this message translates to:
  /// **'Fatwa-like'**
  String get reviewerValueFatwaLike;

  /// Reviewer work tool: reviewerValueFocused
  ///
  /// In en, this message translates to:
  /// **'Focused'**
  String get reviewerValueFocused;

  /// Reviewer work tool: reviewerValueFoundational
  ///
  /// In en, this message translates to:
  /// **'Foundational'**
  String get reviewerValueFoundational;

  /// Reviewer work tool: reviewerValueFraming
  ///
  /// In en, this message translates to:
  /// **'Framing'**
  String get reviewerValueFraming;

  /// Reviewer work tool: reviewerValueGeneralKnowledge
  ///
  /// In en, this message translates to:
  /// **'General knowledge'**
  String get reviewerValueGeneralKnowledge;

  /// Reviewer work tool: reviewerValueGeneralisedFromSpecific
  ///
  /// In en, this message translates to:
  /// **'Generalised from a specific case'**
  String get reviewerValueGeneralisedFromSpecific;

  /// Reviewer work tool: reviewerValueHistoricalEvidence
  ///
  /// In en, this message translates to:
  /// **'Historical evidence'**
  String get reviewerValueHistoricalEvidence;

  /// Reviewer work tool: reviewerValueHypothetical
  ///
  /// In en, this message translates to:
  /// **'Hypothetical'**
  String get reviewerValueHypothetical;

  /// Reviewer work tool: reviewerValueImagePolicy
  ///
  /// In en, this message translates to:
  /// **'Image policy'**
  String get reviewerValueImagePolicy;

  /// Reviewer work tool: reviewerValueInference
  ///
  /// In en, this message translates to:
  /// **'Inference'**
  String get reviewerValueInference;

  /// Reviewer work tool: reviewerValueInstruction
  ///
  /// In en, this message translates to:
  /// **'Instruction'**
  String get reviewerValueInstruction;

  /// Reviewer work tool: reviewerValueLocalization
  ///
  /// In en, this message translates to:
  /// **'Localization'**
  String get reviewerValueLocalization;

  /// Reviewer work tool: reviewerValueLocalize
  ///
  /// In en, this message translates to:
  /// **'Localize'**
  String get reviewerValueLocalize;

  /// Reviewer work tool: reviewerValueNeedsTafsir
  ///
  /// In en, this message translates to:
  /// **'Needs tafsir'**
  String get reviewerValueNeedsTafsir;

  /// Reviewer work tool: reviewerValueNewMuslim
  ///
  /// In en, this message translates to:
  /// **'New Muslim'**
  String get reviewerValueNewMuslim;

  /// Reviewer work tool: reviewerValueObservation
  ///
  /// In en, this message translates to:
  /// **'Observation'**
  String get reviewerValueObservation;

  /// Reviewer work tool: reviewerValueOutOfScope
  ///
  /// In en, this message translates to:
  /// **'Out of scope'**
  String get reviewerValueOutOfScope;

  /// Reviewer work tool: reviewerValueOversimplified
  ///
  /// In en, this message translates to:
  /// **'Oversimplified'**
  String get reviewerValueOversimplified;

  /// Reviewer work tool: reviewerValuePartial
  ///
  /// In en, this message translates to:
  /// **'Partial fit'**
  String get reviewerValuePartial;

  /// Reviewer work tool: reviewerValuePedagogy
  ///
  /// In en, this message translates to:
  /// **'Pedagogy'**
  String get reviewerValuePedagogy;

  /// Reviewer work tool: reviewerValuePending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get reviewerValuePending;

  /// Reviewer work tool: reviewerValuePersonalFatwa
  ///
  /// In en, this message translates to:
  /// **'Personal fatwa'**
  String get reviewerValuePersonalFatwa;

  /// Reviewer work tool: reviewerValuePlan
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get reviewerValuePlan;

  /// Reviewer work tool: reviewerValuePractice
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get reviewerValuePractice;

  /// Reviewer work tool: reviewerValuePrediction
  ///
  /// In en, this message translates to:
  /// **'Prediction'**
  String get reviewerValuePrediction;

  /// Reviewer work tool: reviewerValuePublish
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get reviewerValuePublish;

  /// Reviewer work tool: reviewerValuePublished
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get reviewerValuePublished;

  /// Reviewer work tool: reviewerValueQa
  ///
  /// In en, this message translates to:
  /// **'Quality assurance'**
  String get reviewerValueQa;

  /// Reviewer work tool: reviewerValueQuestion
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get reviewerValueQuestion;

  /// Reviewer work tool: reviewerValueRaqeeb
  ///
  /// In en, this message translates to:
  /// **'Raqeeb'**
  String get reviewerValueRaqeeb;

  /// Reviewer work tool: reviewerValueReadingLevel
  ///
  /// In en, this message translates to:
  /// **'Reading level'**
  String get reviewerValueReadingLevel;

  /// Reviewer work tool: reviewerValueReasoning
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get reviewerValueReasoning;

  /// Reviewer work tool: reviewerValueReflection
  ///
  /// In en, this message translates to:
  /// **'Reflection'**
  String get reviewerValueReflection;

  /// Reviewer work tool: reviewerValueRejected
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get reviewerValueRejected;

  /// Reviewer work tool: reviewerValueRetrieve
  ///
  /// In en, this message translates to:
  /// **'Retrieve'**
  String get reviewerValueRetrieve;

  /// Reviewer work tool: reviewerValueRunning
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get reviewerValueRunning;

  /// Reviewer work tool: reviewerValueScenario
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get reviewerValueScenario;

  /// Reviewer work tool: reviewerValueSceneAuthor
  ///
  /// In en, this message translates to:
  /// **'Scene authoring'**
  String get reviewerValueSceneAuthor;

  /// Reviewer work tool: reviewerValueSceneRender
  ///
  /// In en, this message translates to:
  /// **'Scene rendering'**
  String get reviewerValueSceneRender;

  /// Reviewer work tool: reviewerValueScholarlyDisagreement
  ///
  /// In en, this message translates to:
  /// **'Scholarly disagreement'**
  String get reviewerValueScholarlyDisagreement;

  /// Reviewer work tool: reviewerValueScholarlyReview
  ///
  /// In en, this message translates to:
  /// **'Scholarly review'**
  String get reviewerValueScholarlyReview;

  /// Reviewer work tool: reviewerValueSensitive
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get reviewerValueSensitive;

  /// Reviewer work tool: reviewerValueSensitiveHuman
  ///
  /// In en, this message translates to:
  /// **'Sensitive personal question'**
  String get reviewerValueSensitiveHuman;

  /// Reviewer work tool: reviewerValueSingleOpinionAsConsensus
  ///
  /// In en, this message translates to:
  /// **'One opinion presented as consensus'**
  String get reviewerValueSingleOpinionAsConsensus;

  /// Reviewer work tool: reviewerValueSkipped
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get reviewerValueSkipped;

  /// Reviewer work tool: reviewerValueSource
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get reviewerValueSource;

  /// Reviewer work tool: reviewerValueStandard
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get reviewerValueStandard;

  /// Reviewer work tool: reviewerValueStory
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get reviewerValueStory;

  /// Reviewer work tool: reviewerValueStretched
  ///
  /// In en, this message translates to:
  /// **'Stretched'**
  String get reviewerValueStretched;

  /// Reviewer work tool: reviewerValueSupported
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get reviewerValueSupported;

  /// Reviewer work tool: reviewerValueTakeaway
  ///
  /// In en, this message translates to:
  /// **'Takeaway'**
  String get reviewerValueTakeaway;

  /// Reviewer work tool: reviewerValueTestimony
  ///
  /// In en, this message translates to:
  /// **'Testimony'**
  String get reviewerValueTestimony;

  /// Reviewer work tool: reviewerValueTextExplanation
  ///
  /// In en, this message translates to:
  /// **'Text explanation'**
  String get reviewerValueTextExplanation;

  /// Reviewer work tool: reviewerValueTranslationSensitive
  ///
  /// In en, this message translates to:
  /// **'Translation sensitive'**
  String get reviewerValueTranslationSensitive;

  /// Reviewer work tool: reviewerValueUnknown
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get reviewerValueUnknown;

  /// Reviewer work tool: reviewerValueUnrelated
  ///
  /// In en, this message translates to:
  /// **'Unrelated'**
  String get reviewerValueUnrelated;

  /// Reviewer work tool: reviewerValueUnsupportedSentence
  ///
  /// In en, this message translates to:
  /// **'Unsupported sentence'**
  String get reviewerValueUnsupportedSentence;

  /// Reviewer work tool: reviewerValueValidation
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get reviewerValueValidation;

  /// Reviewer work tool: reviewerValueVerification
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get reviewerValueVerification;

  /// Reviewer work tool: reviewerValueVerify
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get reviewerValueVerify;

  /// Reviewer work tool: reviewerValueVisuals
  ///
  /// In en, this message translates to:
  /// **'Visuals'**
  String get reviewerValueVisuals;

  /// Reviewer work tool: reviewerValueWrite
  ///
  /// In en, this message translates to:
  /// **'Write'**
  String get reviewerValueWrite;

  /// Reviewer work tool: reviewerVisuals
  ///
  /// In en, this message translates to:
  /// **'Visuals'**
  String get reviewerVisuals;

  /// Reviewer work tool: reviewerWarning
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get reviewerWarning;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get sessionAllCaughtUp;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Your answers'**
  String get sessionAnswerReview;

  /// Prototype interface copy: session / applying. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Applying'**
  String get sessionApplying;

  /// Prototype interface copy: session / backToJourney. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Back to my journey'**
  String get sessionBackToJourney;

  /// Prototype interface copy: session / begin. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Begin'**
  String get sessionBegin;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Gap {number}'**
  String sessionBlank(String number);

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Choose the reason'**
  String get sessionChooseReason;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'{count} in a row'**
  String sessionCombo(String count);

  /// Prototype interface copy: session / comesBack. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Coming back in review'**
  String get sessionComesBack;

  /// Prototype interface copy: session / companionIntro. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I’ll walk with you. Tap any underlined word if it’s new.'**
  String get sessionCompanionIntro;

  /// Prototype interface copy: session / correctAnswerIs. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Correct answer:'**
  String get sessionCorrectAnswerIs;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Exercises will be interactive in the next phase. Continue to preview the lesson content.'**
  String get sessionExercisePlaceholderBody;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Exercise preview'**
  String get sessionExercisePlaceholderTitle;

  /// Prototype interface copy: session / exercisesCount. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{countText} activities'**
  String sessionExercisesCount(String countText);

  /// Prototype interface copy: session / falseLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'False'**
  String get sessionFalseLabel;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Fill the gaps'**
  String get sessionFillBlank;

  /// Default hook CTA when the server sends null.
  ///
  /// In en, this message translates to:
  /// **'Let’s find out'**
  String get sessionFindOut;

  /// Prototype interface copy: session / gentle1. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Not quite — and that’s okay'**
  String get sessionGentle1;

  /// Prototype interface copy: session / gentle2. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'So close'**
  String get sessionGentle2;

  /// Prototype interface copy: session / gentle3. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Good try'**
  String get sessionGentle3;

  /// Prototype interface copy: session / illTry. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I’ll try it'**
  String get sessionIllTry;

  /// Prototype interface copy: session / inTwoDays. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'In 2 days'**
  String get sessionInTwoDays;

  /// Prototype interface copy: session / keepLearning. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Keep learning'**
  String get sessionKeepLearning;

  /// Prototype interface copy: session / kindChoose. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get sessionKindChoose;

  /// Prototype interface copy: session / kindDay. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your day'**
  String get sessionKindDay;

  /// Prototype interface copy: session / kindDiscover. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get sessionKindDiscover;

  /// Prototype interface copy: session / kindFix. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Correct the idea'**
  String get sessionKindFix;

  /// Prototype interface copy: session / kindGuess. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your guess'**
  String get sessionKindGuess;

  /// Prototype interface copy: session / kindMatch. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get sessionKindMatch;

  /// Prototype interface copy: session / kindOrder. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Put in order'**
  String get sessionKindOrder;

  /// Prototype interface copy: session / kindRealLife. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Real life'**
  String get sessionKindRealLife;

  /// Prototype interface copy: session / kindRecite. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Recite'**
  String get sessionKindRecite;

  /// Prototype interface copy: session / kindSort. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sessionKindSort;

  /// Prototype interface copy: session / kindTrueFalse. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'True or false'**
  String get sessionKindTrueFalse;

  /// Prototype interface copy: session / leave. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get sessionLeave;

  /// Prototype interface copy: session / lessonComplete. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Lesson complete!'**
  String get sessionLessonComplete;

  /// Prototype interface copy: session / lessonCompleteSub. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Another step on your path — taken calmly and well.'**
  String get sessionLessonCompleteSub;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Unit {unit} · Lesson {lesson}'**
  String sessionLessonPosition(String unit, String lesson);

  /// Prototype interface copy: session / listenReciter. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Listen to the reciter'**
  String get sessionListenReciter;

  /// Prototype interface copy: session / listening. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get sessionListening;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Place {number}'**
  String sessionMapPin(String number);

  /// Prototype interface copy: session / masteryNote. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Progress in Qabas follows mastery, not just finishing. Remembering is measured in review sessions.'**
  String get sessionMasteryNote;

  /// Prototype interface copy: session / meaning. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Meaning'**
  String get sessionMeaning;

  /// Prototype interface copy: session / mistakenIdea. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A common misconception'**
  String get sessionMistakenIdea;

  /// Next-step title supplied verbatim by the stored server result.
  ///
  /// In en, this message translates to:
  /// **'Next on your path: {title}'**
  String sessionNextOnPath(String title);

  /// Prototype interface copy: session / nextUnlocked. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Next on your path: {title}'**
  String sessionNextUnlocked(String title);

  /// Prototype interface copy: session / niceThinking. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Nice thinking!'**
  String get sessionNiceThinking;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Where did this story come from?'**
  String get sessionOriginTitle;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Tap a word, then its meaning. Tap a pair to change it.'**
  String get sessionPairHint;

  /// Prototype interface copy: session / perfectBonus. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Perfect lesson bonus'**
  String get sessionPerfectBonus;

  /// Prototype interface copy: session / playing. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Playing…'**
  String get sessionPlaying;

  /// Prototype interface copy: session / praise1. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Well done!'**
  String get sessionPraise1;

  /// Prototype interface copy: session / praise2. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Exactly right'**
  String get sessionPraise2;

  /// Prototype interface copy: session / praise3. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Beautiful!'**
  String get sessionPraise3;

  /// Prototype interface copy: session / praise4. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'That’s it!'**
  String get sessionPraise4;

  /// Prototype interface copy: session / praise5. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Spot on'**
  String get sessionPraise5;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Thank you for sharing what you know'**
  String get sessionPretestThanks;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'You’ve reached the end of the content preview. Exercises and lesson completion are coming in the next phases.'**
  String get sessionPreviewEndBody;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Content preview complete'**
  String get sessionPreviewEndTitle;

  /// Accessible player progress label.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String sessionProgress(String percent);

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Quick review'**
  String get sessionQuickReview;

  /// Prototype interface copy: session / quitBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your progress in this lesson won’t be saved. You can come back any time.'**
  String get sessionQuitBody;

  /// Prototype interface copy: session / quitTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Leave this lesson?'**
  String get sessionQuitTitle;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Read lesson'**
  String get sessionReadLesson;

  /// Empty learning content or accessible review countdown, Phase 12.
  ///
  /// In en, this message translates to:
  /// **'This lesson has no reading content yet.'**
  String get sessionReaderEmpty;

  /// Prototype interface copy: session / reciteBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'The verse that tells us prayer has set times.'**
  String get sessionReciteBody;

  /// Prototype interface copy: session / reciteGreat. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Beautifully read'**
  String get sessionReciteGreat;

  /// Prototype interface copy: session / reciteTip. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'One gentle tip: blend the “-an” of kitāban into the m of mawqūtā — a soft nasal hum.'**
  String get sessionReciteTip;

  /// Prototype interface copy: session / reciteTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Listen, then read it aloud'**
  String get sessionReciteTitle;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Recording isn’t available yet'**
  String get sessionRecordingUnavailable;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Let’s clarify this idea'**
  String get sessionRemediation;

  /// Prototype interface copy: session / remembering. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Remembering'**
  String get sessionRemembering;

  /// Prototype interface copy: session / report. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get sessionReport;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'The celebration screen is coming soon. You can return to your journey.'**
  String get sessionResultPendingBody;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Your session is saved'**
  String get sessionResultPendingTitle;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Let’s revisit the ideas you’re still practising.'**
  String get sessionRetryBody;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'A chance to try again'**
  String get sessionRetryTitle;

  /// Prototype interface copy: session / reviewedBySpecialist. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Reviewed by an Islamic-studies specialist'**
  String get sessionReviewedBySpecialist;

  /// Developer launcher for the four authored Salah variants.
  ///
  /// In en, this message translates to:
  /// **'Salah preview'**
  String get sessionSalahPreview;

  /// Empty learning content or accessible review countdown, Phase 12.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds remaining'**
  String sessionSecondsRemaining(String seconds);

  /// Prototype interface copy: session / selectAnswer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Choose an answer'**
  String get sessionSelectAnswer;

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get sessionShowAll;

  /// Prototype interface copy: session / showMore. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Next idea'**
  String get sessionShowMore;

  /// Prototype interface copy: session / simulatedNote. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Prototype: audio and speech feedback are simulated.'**
  String get sessionSimulatedNote;

  /// Prototype interface copy: session / situation. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'A real moment'**
  String get sessionSituation;

  /// Prototype interface copy: session / skipRecite. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'I can’t speak now'**
  String get sessionSkipRecite;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get sessionSkipped;

  /// Prototype interface copy: session / soon. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'In review'**
  String get sessionSoon;

  /// Prototype interface copy: session / sourcesLine. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{countText} authenticated sources'**
  String sessionSourcesLine(String countText);

  /// Phase 5 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Sources for this lesson'**
  String get sessionSourcesTitle;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Find the mistaken part'**
  String get sessionSpotError;

  /// Prototype interface copy: session / statAccuracy. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get sessionStatAccuracy;

  /// Prototype interface copy: session / statEmbers. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Embers'**
  String get sessionStatEmbers;

  /// Prototype interface copy: session / statTime. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get sessionStatTime;

  /// Phase 6 answer failure with retained draft.
  ///
  /// In en, this message translates to:
  /// **'Your answer is kept. Please try again.'**
  String get sessionSubmitError;

  /// Prototype interface copy: session / tapInOrder. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tap them in order.'**
  String get sessionTapInOrder;

  /// Prototype interface copy: session / tapTheScene. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tap the right place in the picture.'**
  String get sessionTapTheScene;

  /// Prototype interface copy: session / tapThenPlace. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tap a phrase, then the group it belongs to.'**
  String get sessionTapThenPlace;

  /// Prototype interface copy: session / tapThenSlot. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tap a prayer, then its moment in the day.'**
  String get sessionTapThenSlot;

  /// Prototype interface copy: session / tapToContinue. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tap to continue'**
  String get sessionTapToContinue;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Unit test passed'**
  String get sessionTestPassed;

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Keep building your understanding'**
  String get sessionTestTryAgain;

  /// Prototype interface copy: session / theStory. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'The story'**
  String get sessionTheStory;

  /// Prototype interface copy: session / thenAWeek. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Then in a week'**
  String get sessionThenAWeek;

  /// Prototype interface copy: session / thinkFirst. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Think about it for a moment — there’s no wrong answer here.'**
  String get sessionThinkFirst;

  /// Prototype interface copy: session / todaysChallenge. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Today’s small challenge'**
  String get sessionTodaysChallenge;

  /// Prototype interface copy: session / tomorrowWeAsk. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow we’ll ask'**
  String get sessionTomorrowWeAsk;

  /// Toggle the server supplied pronunciation transliteration for a recitation segment.
  ///
  /// In en, this message translates to:
  /// **'Transliteration'**
  String get sessionTransliteration;

  /// Prototype interface copy: session / trueLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'True'**
  String get sessionTrueLabel;

  /// Prototype interface copy: session / understanding. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Understanding'**
  String get sessionUnderstanding;

  /// Developer picker for Unit 0 lessons; normal prerequisites apply.
  ///
  /// In en, this message translates to:
  /// **'Unit 0 content preview'**
  String get sessionUnit0ContentPreview;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Update the app to continue'**
  String get sessionUpdateRequired;

  /// Phase 6 interface copy; Arabic ready for owner review.
  ///
  /// In en, this message translates to:
  /// **'Surah {surah} · Ayah {ayah}'**
  String sessionVerseReference(String surah, String ayah);

  /// Phase 12 interface copy.
  ///
  /// In en, this message translates to:
  /// **'Choose the evidence'**
  String get sessionWhichEvidence;

  /// Prototype interface copy: session / whyLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Why'**
  String get sessionWhyLabel;

  /// Prototype interface copy: session / youWillLearn. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You’ll learn'**
  String get sessionYouWillLearn;

  /// Prototype interface copy: session / yourAnswer. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get sessionYourAnswer;

  /// Prototype interface copy: session / yourMastery. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your mastery'**
  String get sessionYourMastery;

  /// Prototype interface copy: session / yourTurn. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your turn — tap and read aloud'**
  String get sessionYourTurn;

  /// Prototype interface copy: settings / aboutQabas. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'About Qabas'**
  String get settingsAboutQabas;

  /// Phase 10 settings interface copy.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get settingsArabic;

  /// Phase 10 settings interface copy.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get settingsCharacters;

  /// Phase 10 settings interface copy.
  ///
  /// In en, this message translates to:
  /// **'About this content'**
  String get settingsContentNote;

  /// Phase 10 settings interface copy.
  ///
  /// In en, this message translates to:
  /// **'Qabas content is drawn from verified sources. It is pending review by a specialist in Islamic studies before publication.'**
  String get settingsContentNoteBody;

  /// Prototype interface copy: settings / dailyGoalSetting. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Daily goal'**
  String get settingsDailyGoalSetting;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Phase 13 interface copy; Arabic pending owner review.
  ///
  /// In en, this message translates to:
  /// **'Delete your account and learning progress? This cannot be undone. Your data will be removed within 30 days.'**
  String get settingsDeleteAccountBody;

  /// Prototype interface copy: settings / demoReset. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Demo progress reset'**
  String get settingsDemoReset;

  /// Prototype interface copy: settings / discreetReminders. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Discreet reminders'**
  String get settingsDiscreetReminders;

  /// Phase 10 settings interface copy.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsEnglish;

  /// Prototype interface copy: settings / hapticsLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get settingsHapticsLabel;

  /// Prototype interface copy: settings / language. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Prototype interface copy: settings / learnerPath. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Learning path'**
  String get settingsLearnerPath;

  /// Prototype interface copy: settings / privateProfileSetting. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Private profile'**
  String get settingsPrivateProfileSetting;

  /// Prototype interface copy: settings / reduceMotion. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// Prototype interface copy: settings / reduceMotionBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Calmer screens, no jumps or particles'**
  String get settingsReduceMotionBody;

  /// Prototype interface copy: settings / reminders. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get settingsReminders;

  /// Prototype interface copy: settings / replayOnboarding. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Replay onboarding'**
  String get settingsReplayOnboarding;

  /// Prototype interface copy: settings / resetDemo. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Reset demo progress'**
  String get settingsResetDemo;

  /// Prototype interface copy: settings / resetDemoBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Back to a 3-day streak with the Prayer lesson waiting'**
  String get settingsResetDemoBody;

  /// Phase 10 settings interface copy.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t save that change. Please try again.'**
  String get settingsSaveFailed;

  /// Prototype interface copy: settings / sectionAbout. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Prototype interface copy: settings / sectionAccount. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get settingsSectionAccount;

  /// Prototype interface copy: settings / sectionDemo. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Prototype'**
  String get settingsSectionDemo;

  /// Prototype interface copy: settings / sectionExperience. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get settingsSectionExperience;

  /// Prototype interface copy: settings / sectionLearning. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Learning'**
  String get settingsSectionLearning;

  /// Prototype interface copy: settings / sectionPrivacy. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsSectionPrivacy;

  /// Prototype interface copy: settings / soundEffects. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Sound effects'**
  String get settingsSoundEffects;

  /// Prototype interface copy: streak / dayStreakLabel. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'day streak'**
  String get streakDayStreakLabel;

  /// Prototype interface copy: streak / keepFlameWarm. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Learn a little today to keep your flame warm.'**
  String get streakKeepFlameWarm;

  /// Prototype interface copy: streak / lastFiveWeeks. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Your last five weeks'**
  String get streakLastFiveWeeks;

  /// Prototype interface copy: streak / restDays. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Rest days'**
  String get streakRestDays;

  /// Prototype interface copy: streak / restDaysBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Life happens. One rest day a week keeps your flame warm — no guilt, no lost progress.'**
  String get streakRestDaysBody;

  /// Prototype interface copy: streak / streakBody. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'You lit today’s flame. A little light every day becomes a path.'**
  String get streakStreakBody;

  /// Prototype interface copy: streak / streakKeep. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'Keep the flame'**
  String get streakStreakKeep;

  /// Prototype interface copy: streak / streakTitle. Preserve the original warm wording.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{countText}-day streak!}}'**
  String streakStreakTitle(num count, String countText);

  /// Accessible label for the current day in the streak week.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get streakToday;

  /// Empty learning content or accessible review countdown, Phase 12.
  ///
  /// In en, this message translates to:
  /// **'There is no guide content yet.'**
  String get unitGuideEmpty;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
