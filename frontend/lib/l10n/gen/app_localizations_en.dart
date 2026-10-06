// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutAiNotice => 'Questions are processed by AI services. For personal rulings, consult a qualified specialist.';

  @override
  String get aboutFullVerse => 'Read the full verse';

  @override
  String get aboutNameMeaning =>
      'Qabas (قبس) is a small flame taken from a larger fire, carried to bring light and warmth. The word comes from the Quran, in the story of Prophet Musa (Moses), peace be upon him: travelling at night with his family, cold and unsure of the way, he saw a fire in the distance.';

  @override
  String get aboutNameMeaningTitle => 'The name';

  @override
  String get aboutOurPromises => 'Our promises';

  @override
  String get aboutPromise1 => 'Every lesson is reviewed by a specialist in Islamic studies';

  @override
  String get aboutPromise2 => 'Verses and hadiths are quoted exactly, with their sources';

  @override
  String get aboutPromise3 => 'Welcoming, never pressuring — safe to ask anything';

  @override
  String get aboutPromise4 => 'Your journey is private unless you choose to share it';

  @override
  String get aboutTahaReference => 'Surah Taha, 20:10';

  @override
  String get aboutTranslationNote => 'Translation: Saheeh International';

  @override
  String get aboutVerseTranslation => '“Perhaps I can bring you a torch or find at the fire some guidance.”';

  @override
  String get aboutWhyItFits =>
      'This is our learner’s story: someone notices a light from afar, feels curious, walks toward it, and finds guidance. Qabas is that first flame — small, warm, inviting, and leading somewhere greater.';

  @override
  String get challengeAccept => 'Join challenge';

  @override
  String get challengeAnswered => 'Answer locked';

  @override
  String get challengeAsync => 'Play now; your friend plays later';

  @override
  String get challengeBotFill => 'Fill empty seats with practice bots';

  @override
  String get challengeChooseFriends => 'Choose up to three friends';

  @override
  String get challengeConnectionLost => 'Connection lost';

  @override
  String get challengeDecline => 'Decline';

  @override
  String challengeDisconnected(String name, String seconds) {
    return '$name is reconnecting · ${seconds}s';
  }

  @override
  String get challengeDone => 'Done';

  @override
  String get challengeDraw => 'You lit the way together!';

  @override
  String get challengeFastest => 'Fastest';

  @override
  String get challengeGetReady => 'Get ready';

  @override
  String get challengeGroup => 'Challenge friends';

  @override
  String get challengeInvitations => 'Invitations';

  @override
  String challengeInviteFrom(String name) {
    return 'Challenge from $name';
  }

  @override
  String get challengeLiveLobby => 'Friends are joining…';

  @override
  String get challengeNoInvitations => 'No invitations right now';

  @override
  String get challengeNotJoinableTitle => 'This challenge has already started or ended';

  @override
  String get challengePlayAgain => 'Play again';

  @override
  String get challengePoints => 'pts';

  @override
  String get challengePracticeBot => 'Practice with the bot';

  @override
  String challengeQuestionOf(String current, String total) {
    return 'Question $current of $total';
  }

  @override
  String get challengeReconnecting => 'Reconnecting…';

  @override
  String get challengeResults => 'Results';

  @override
  String challengeSeconds(String value) {
    return '${value}s';
  }

  @override
  String get challengeSummary => 'Review answers';

  @override
  String get challengeWaitingFriend => 'Waiting for your friend';

  @override
  String get challengeWellPlayed => 'Well played!';

  @override
  String get challengeYouWon => 'You lit the way!';

  @override
  String get characterGuideSemantics => 'Your guide carrying a small light';

  @override
  String get characterLanternSemantics => 'Raqeeb’s lantern';

  @override
  String get commonAppName => 'Qabas';

  @override
  String get commonArabic => 'العربية';

  @override
  String get commonBack => 'Back';

  @override
  String get commonBrandArabic => 'قبس';

  @override
  String get commonBrandLatin => 'Qabas';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonCheck => 'Check';

  @override
  String get commonChooseAnother => 'Choose another';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String commonDayStreak(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countText day streak');
    return '$_temp0';
  }

  @override
  String commonDays(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countText days', one: '1 day');
    return '$_temp0';
  }

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String commonEmbers(String value) {
    return '$value embers';
  }

  @override
  String get commonEmbersName => 'Embers';

  @override
  String get commonEnglish => 'English';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonLater => 'Later';

  @override
  String get commonLoading => 'Loading…';

  @override
  String commonMinutes(String value) {
    return '$value min';
  }

  @override
  String commonMinutesLong(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$value min');
    return '$_temp0';
  }

  @override
  String get commonNew => 'New';

  @override
  String get commonNext => 'Next';

  @override
  String get commonOfflineBody => 'You’re offline. We’ll keep what you’ve done.';

  @override
  String get commonPathExplorer => 'Explorer';

  @override
  String get commonPathExplorerLong => 'Explorer path';

  @override
  String get commonPathNewMuslim => 'New Muslim';

  @override
  String get commonPathNewMuslimLong => 'New Muslim path';

  @override
  String commonPercent(String value) {
    return '$value%';
  }

  @override
  String commonPlusEmbers(String value) {
    return '+$value embers';
  }

  @override
  String get commonRecordTooltip => 'Record a question';

  @override
  String get commonRemoveAttachmentTooltip => 'Remove attachment';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSeeAll => 'See all';

  @override
  String get commonSendTooltip => 'Send';

  @override
  String get commonSessionEndedBody => 'Your guest session has ended. We’ll help you start a new journey.';

  @override
  String get commonSessionEndedTitle => 'Let’s begin again';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonStart => 'Start';

  @override
  String get commonTabCommunity => 'Community';

  @override
  String get commonTabDiscover => 'Discover';

  @override
  String get commonTabJourney => 'Journey';

  @override
  String get commonTabProfile => 'Profile';

  @override
  String get commonTabRaqeeb => 'Raqeeb';

  @override
  String get commonTabReview => 'Review';

  @override
  String get commonTagline => 'Learn Islam step by step, from your first question to real understanding.';

  @override
  String get commonUpdate => 'Update Qabas';

  @override
  String get commonUpdateBody => 'Update Qabas to keep learning. Your journey will be waiting.';

  @override
  String get commonUpdateTitle => 'A little update, a brighter path';

  @override
  String get communityCommunityTitle => 'Community';

  @override
  String get communityDailyQuests => 'Daily quests';

  @override
  String communityEndsIn(String days, String hours) {
    return 'Ends in ${days}d ${hours}h';
  }

  @override
  String get communityFriends => 'Friends';

  @override
  String get communityInvite => 'Invite';

  @override
  String get communityJoinLeague => 'Join the league';

  @override
  String get communityLearningPrivately => 'You’re learning privately';

  @override
  String get communityLearningPrivatelyBody => 'Your activity is hidden from leagues and friends. You can join any time.';

  @override
  String get communityLiveChallenge => 'Live challenge';

  @override
  String get communityLiveChallengeBody => 'Challenge friends to a live quiz — the fastest correct answer wins.';

  @override
  String get communityNoFriends => 'Invite a friend to learn together';

  @override
  String get communityNoLeagueTitle => 'Earn embers to join this week’s league';

  @override
  String get communityNoQuests => 'You’re all caught up for today';

  @override
  String communityProgressCount(String current, String target) {
    return '$current/$target';
  }

  @override
  String communityPromoteLine(String countText, String league) {
    return 'Top $countText move up to $league';
  }

  @override
  String communityPromotionCount(String count) {
    return 'Top $count move up';
  }

  @override
  String get communityPromotionZone => 'Promotion zone';

  @override
  String communityQuestReward(String count) {
    return '+$count embers';
  }

  @override
  String communityResetsIn(String hours) {
    return 'Resets in ${hours}h';
  }

  @override
  String get communityStartChallenge => 'Start a challenge';

  @override
  String communityStreakDays(String countText) {
    return '$countText-day streak';
  }

  @override
  String get communityTopTier => 'Keep your light shining';

  @override
  String get communityYou => 'You';

  @override
  String get contentArticle => 'Article';

  @override
  String get contentAudioError => 'This audio isn’t available right now.';

  @override
  String get contentBook => 'Book';

  @override
  String get contentFatwa => 'Fatwa';

  @override
  String get contentHadithLabel => 'Hadith';

  @override
  String get contentLearnMore => 'Learn more';

  @override
  String get contentLevelBasic => 'Basic';

  @override
  String get contentLevelIntermediate => 'Intermediate';

  @override
  String get contentLevelUnknown => 'Your level';

  @override
  String get contentProviderDorar => 'Dorar';

  @override
  String get contentProviderHadeethenc => 'HadeethEnc';

  @override
  String get contentProviderIslamhouse => 'IslamHouse';

  @override
  String get contentProviderQuranCom => 'Quran.com';

  @override
  String get contentProviderQuranenc => 'QuranEnc';

  @override
  String get contentProviderTafsirCenter => 'Tafsir Center';

  @override
  String get contentQuranLabel => 'Quran';

  @override
  String get contentSource => 'Source';

  @override
  String get contentTafsir => 'Tafsir';

  @override
  String get contentViewSource => 'View source';

  @override
  String get discoverEmptyBody => 'New lessons to explore will appear here.';

  @override
  String get discoverEmptyTitle => 'More to explore';

  @override
  String get discoverNotice => 'Some lessons normally come later on your path. Earlier units can make them easier to understand.';

  @override
  String discoverUnitHeading(String number, String title) {
    return 'Unit $number · $title';
  }

  @override
  String get errorFileTypeBody => 'This file type isn’t supported.';

  @override
  String get errorFileTypeTitle => 'Try another file';

  @override
  String get errorForbiddenBody => 'This isn’t available for your account.';

  @override
  String get errorForbiddenTitle => 'This isn’t available';

  @override
  String get errorGenericBody => 'Let’s try that again.';

  @override
  String get errorGenericTitle => 'Something unexpected happened';

  @override
  String get errorNetworkBody => 'Check your internet and try again.';

  @override
  String get errorNetworkTitle => 'No connection';

  @override
  String get errorNotFoundBody => 'Go back and take another step.';

  @override
  String get errorNotFoundTitle => 'We couldn’t find this';

  @override
  String errorRateLimitedBody(String time) {
    return 'You can try again in $time.';
  }

  @override
  String get errorRateLimitedTitle => 'Let’s pause for a moment';

  @override
  String get errorServerBody => 'Something went wrong on our side. Please try again.';

  @override
  String get errorServerTitle => 'A small pause';

  @override
  String get errorSourcesBody => 'Sources are temporarily unavailable. Try again shortly.';

  @override
  String get errorSourcesTitle => 'Sources are taking a moment';

  @override
  String get errorTooLargeBody => 'Choose a smaller file and try again.';

  @override
  String get errorTooLargeTitle => 'This file is too large';

  @override
  String get friendsAccept => 'Accept invite';

  @override
  String get friendsAcceptCode => 'Enter an invite code';

  @override
  String get friendsAccepted => 'You’re now learning together';

  @override
  String get friendsAlreadyFriends => 'You’re already friends.';

  @override
  String get friendsCode => 'Invite code';

  @override
  String get friendsInviteInvalid => 'That code doesn’t work. Check it and try again.';

  @override
  String get friendsOffline => 'Offline';

  @override
  String get friendsOnline => 'Online';

  @override
  String get friendsRemove => 'Remove friend';

  @override
  String friendsRemoveBody(String name) {
    return 'Remove $name from your friends?';
  }

  @override
  String get friendsShare => 'Share invite';

  @override
  String get galleryBrand => 'Brand and illustration';

  @override
  String get galleryButtons => 'Buttons';

  @override
  String get galleryCardBody => 'A small light for a big journey';

  @override
  String get galleryCelebrate => 'Celebrate';

  @override
  String get galleryConfirm => 'Confirmation sheet';

  @override
  String get galleryDisabled => 'Disabled';

  @override
  String get galleryEmptyBody => 'A little space for something new.';

  @override
  String get galleryEmptyTitle => 'Your next step is on its way';

  @override
  String get galleryInputs => 'Inputs and settings';

  @override
  String get galleryMotion => 'Motion';

  @override
  String get galleryNudge => 'Try a gentle nudge';

  @override
  String get galleryOpenSheet => 'Open sheet';

  @override
  String get gallerySheets => 'Sheets and notices';

  @override
  String get galleryStates => 'Loading, empty and error';

  @override
  String get gallerySurfaces => 'Cards and progress';

  @override
  String get galleryTitle => 'Component gallery';

  @override
  String get glossaryAll => 'All';

  @override
  String get glossaryAskRaqeeb => 'Ask Raqeeb';

  @override
  String get glossaryEmpty => 'Words you meet in lessons will appear here.';

  @override
  String get glossaryIKnowThis => 'I know this';

  @override
  String get glossaryLearning => 'Learning';

  @override
  String get glossaryLevelExplorer => 'Explained for explorers';

  @override
  String get glossaryLevelNewMuslim => 'Explained for new Muslims';

  @override
  String get glossaryListen => 'Listen';

  @override
  String get glossaryLoadMore => 'Show more words';

  @override
  String get glossaryMastered => 'Mastered';

  @override
  String get glossaryNew => 'New';

  @override
  String get glossaryUnderlineHint => 'Once you’ve mastered a word, its underline disappears.';

  @override
  String get glossaryYourDictionary => 'Your dictionary';

  @override
  String get journeyAvailable => 'Available';

  @override
  String get journeyCheckpoint => 'Checkpoint';

  @override
  String get journeyComingSoonBody =>
      'This prototype includes one complete lesson: “Prayer: a river at your door”. The rest of the journey shows how the path unfolds.';

  @override
  String get journeyComingSoonTitle => 'Coming soon';

  @override
  String get journeyDailyGoal => 'Daily goal';

  @override
  String get journeyDoneLabel => 'Completed';

  @override
  String get journeyEmptyBody => 'Your next steps will appear here. Try again in a moment.';

  @override
  String get journeyEmptyTitle => 'Your path is being prepared';

  @override
  String get journeyExplorerPathHint => 'For the curious: big questions first';

  @override
  String journeyGoalProgress(String done, String goal) {
    return '$done / $goal min';
  }

  @override
  String get journeyGreetingAfternoon => 'Good afternoon';

  @override
  String get journeyGreetingEvening => 'Good evening';

  @override
  String get journeyGreetingMorning => 'Good morning';

  @override
  String get journeyGuide => 'Guide';

  @override
  String get journeyJumpBack => 'Continue';

  @override
  String get journeyKeepTheLight => 'Your path is lit. One small step today?';

  @override
  String get journeyLearnedTodayLine => 'Today’s flame is lit. Beautiful work.';

  @override
  String get journeyLesson => 'Lesson';

  @override
  String journeyLessonAction(String reward) {
    return 'Start lesson  $reward';
  }

  @override
  String get journeyLoading => 'Lighting your path…';

  @override
  String get journeyLockedBody => 'Finish the steps before this one and the path will light up.';

  @override
  String get journeyLockedTitle => 'Not yet';

  @override
  String get journeyNewMuslimPathHint => 'First steps in faith and practice';

  @override
  String journeyNodeSemantics(String title, String status) {
    return '$title — $status';
  }

  @override
  String get journeyOpenPlayableLesson => 'Try the sample lesson';

  @override
  String get journeyPathUnfolds => 'The path keeps unfolding as you grow';

  @override
  String get journeyPillarNames1 => 'Testimony';

  @override
  String get journeyPillarNames2 => 'Prayer';

  @override
  String get journeyPillarNames3 => 'Zakah';

  @override
  String get journeyPillarNames4 => 'Pilgrimage';

  @override
  String get journeyPillarNames5 => 'Fasting';

  @override
  String get journeyPractice => 'Practice';

  @override
  String get journeyQuickReview => 'Quick review';

  @override
  String journeyReviewDue(String countText) {
    return '$countText cards ready for a 60-second review';
  }

  @override
  String get journeyReviewLesson => 'Review lesson';

  @override
  String get journeySkipUnit => 'Skip unit';

  @override
  String get journeySoftLockBody => 'You’re almost there. One earlier idea will make this lesson easier to understand.';

  @override
  String get journeySoftLockTitle => 'One idea first';

  @override
  String get journeyStartHere => 'Start';

  @override
  String get journeyStartLesson => 'Start lesson';

  @override
  String get journeyStartReview => 'Start review';

  @override
  String journeyStartWith(String title) {
    return 'Start with: $title';
  }

  @override
  String get journeyStory => 'Story';

  @override
  String get journeyTakeUnitTest => 'Take the unit test';

  @override
  String get journeyUnitComplete => 'Unit complete';

  @override
  String journeyUnitN(String number) {
    return 'Unit $number';
  }

  @override
  String get journeyWhatYoullLearn => 'In this unit';

  @override
  String get journeyYourPath => 'Your path';

  @override
  String get learningEntryBody => 'This part of your path is being prepared. Your progress is saved.';

  @override
  String get mediaCamera => 'Take a photo';

  @override
  String get mediaCaptureFailed => 'We couldn’t read that recording or file. Try again.';

  @override
  String get mediaCountLimit => 'You can attach up to three images, one document and one voice recording.';

  @override
  String get mediaDocumentLimit => 'Documents can be up to 10 MB';

  @override
  String get mediaImageLimit => 'Images can be up to 8 MB';

  @override
  String get mediaMicrophoneDenied => 'Allow microphone access to record. You can change this in settings.';

  @override
  String get mediaOpenSettings => 'Open settings';

  @override
  String get mediaRecitationLimit => 'Recitations can be up to 30 seconds and 5 MB';

  @override
  String get mediaRecord => 'Your turn';

  @override
  String mediaRecordingTime(String seconds, String limit) {
    return 'Recording · $seconds / ${limit}s';
  }

  @override
  String get mediaStopRecording => 'Stop recording';

  @override
  String get mediaVoiceLimit => 'Voice recordings can be up to 60 seconds and 10 MB';

  @override
  String get onboardingArabicGlyph => 'أ';

  @override
  String get onboardingChooseLanguage => 'Choose your language';

  @override
  String get onboardingCompanionHello => 'Hello! I’ll carry the light while you find your way.';

  @override
  String get onboardingDiscreetBody => '“Time for your daily lesson” — nothing more.';

  @override
  String get onboardingDiscreetTitle => 'Discreet reminders';

  @override
  String get onboardingEnglishGlyph => 'Aa';

  @override
  String get onboardingExplorerBody => 'Big questions, clear answers, no pressure.';

  @override
  String get onboardingExplorerTitle => 'I’m curious about Islam';

  @override
  String get onboardingFamiliarBasics => 'I know the basics';

  @override
  String get onboardingFamiliarNew => 'Completely new to this';

  @override
  String get onboardingFamiliarNote => 'We’ll start gently either way — a quick check later can skip what you know.';

  @override
  String get onboardingFamiliarSome => 'I know a little';

  @override
  String get onboardingFamiliarTitle => 'How familiar are you?';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get onboardingGoalBubble => 'Small and steady beats big and rare.';

  @override
  String get onboardingGoalDedicated => 'Dedicated';

  @override
  String get onboardingGoalDeep => 'Deep';

  @override
  String get onboardingGoalGentle => 'Gentle';

  @override
  String get onboardingGoalSteady => 'Steady';

  @override
  String get onboardingGoalTitle => 'How much time feels right each day?';

  @override
  String get onboardingHaveAccount => 'I already have an account';

  @override
  String get onboardingLanguageArabicPrompt => 'اختر لغتك';

  @override
  String get onboardingLanguageEnglishPrompt => 'Choose your language';

  @override
  String get onboardingLanguageHint => 'You can change this any time in settings.';

  @override
  String get onboardingNewMuslimBody => 'First steps in faith and practice, one at a time.';

  @override
  String get onboardingNewMuslimTitle => 'I recently embraced Islam';

  @override
  String onboardingPerDay(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countText min a day');
    return '$_temp0';
  }

  @override
  String get onboardingPreferNotToSay => 'Prefer not to say';

  @override
  String get onboardingPrivacyBody =>
      'Learn privately if you prefer. Some people keep their journey to themselves — that’s completely fine.';

  @override
  String get onboardingPrivacyTitle => 'Your journey stays yours';

  @override
  String get onboardingPrivateBody => 'Hide your activity from leagues and friends.';

  @override
  String get onboardingPrivateTitle => 'Private profile';

  @override
  String get onboardingReadyExplorer => 'We’ll begin with the big questions, then see how Muslims live their faith day to day.';

  @override
  String get onboardingReadyNewMuslim => 'We’ll begin with your first steps — the testimony of faith, then prayer — gently, one at a time.';

  @override
  String get onboardingReadyTitle => 'Your path is ready';

  @override
  String onboardingReminderTime(String time) {
    return 'Reminder time: $time';
  }

  @override
  String get onboardingReminderTitle => 'Reminder time';

  @override
  String get onboardingSkipCuriosity => 'Skip for now';

  @override
  String get onboardingStartMyJourney => 'Start my journey';

  @override
  String onboardingStepOf(String current, String total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingSubmitError => 'We couldn’t start your journey. Your choices are kept.';

  @override
  String get onboardingWelcomeBody => 'Short lessons, authentic sources and a friendly guide — at your own pace.';

  @override
  String get onboardingWelcomeExplorer => 'Welcome. Ask anything — you’re among friends here.';

  @override
  String get onboardingWelcomeNewMuslim => 'Welcome, and congratulations. We’ll walk this together, one step at a time.';

  @override
  String get onboardingWelcomeTitle => 'A small light for a big journey';

  @override
  String get onboardingWhoBubble => 'There are no wrong answers. I’ll shape the path around you.';

  @override
  String get onboardingWhoTitle => 'What brings you to Qabas?';

  @override
  String get profileAchievementsTitle => 'Achievements';

  @override
  String get profileEditName => 'Your name';

  @override
  String profileJoined(String month) {
    return 'Joined $month';
  }

  @override
  String profileLeagueRank(String rank) {
    return 'Rank $rank';
  }

  @override
  String get profileLearnerName => 'Learner';

  @override
  String get profileNameValidation => 'Use 2–24 characters.';

  @override
  String get profileNewBadge => 'New badge!';

  @override
  String get profileNoAchievements => 'Your first badge is waiting ahead.';

  @override
  String get profileNoLeague => 'No league yet';

  @override
  String get profileNoWords => 'Your words will appear here as you learn.';

  @override
  String get profilePrivateBadge => 'Private';

  @override
  String get profileProfileTitle => 'Profile';

  @override
  String get profileSave => 'Save';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileStatBadges => 'Badges';

  @override
  String get profileStatLeague => 'League';

  @override
  String get profileStatLessons => 'Lessons';

  @override
  String get profileStatStreak => 'Day streak';

  @override
  String get profileStatTotal => 'Total embers';

  @override
  String get profileStatWords => 'Words mastered';

  @override
  String get profileStatistics => 'Statistics';

  @override
  String profileUnlockedOf(String current, String total) {
    return '$current of $total unlocked';
  }

  @override
  String get raqeebAbstained => 'Referred or left unanswered';

  @override
  String get raqeebAcceptable => 'Acceptable';

  @override
  String get raqeebAlternative => 'Related authentic text';

  @override
  String get raqeebAskAnything => 'Ask anything…';

  @override
  String get raqeebAskSpecialist => 'Ask a specialist privately';

  @override
  String get raqeebAttachDoc => 'A document';

  @override
  String get raqeebAttachDocBody => 'Raqeeb reads it and answers with sources';

  @override
  String get raqeebAttachPhoto => 'A photo';

  @override
  String get raqeebAttachPhotoBody => 'A sign, a page, a post you saw';

  @override
  String get raqeebAttachTitle => 'Ask with…';

  @override
  String get raqeebAttachVoice => 'Your voice';

  @override
  String get raqeebAttachVoiceBody => 'Just ask out loud';

  @override
  String get raqeebAuthentic => 'Authentic';

  @override
  String get raqeebAuthenticityCheck => 'Authenticity check';

  @override
  String get raqeebExactText => 'Exact text';

  @override
  String get raqeebFabricated => 'Fabricated';

  @override
  String get raqeebFailed => 'I couldn’t finish this answer. Let’s try again.';

  @override
  String get raqeebFoundIn => 'Found in';

  @override
  String get raqeebGrade => 'Grade';

  @override
  String get raqeebGradeOther => 'Other grading';

  @override
  String get raqeebGrader => 'Graded by';

  @override
  String get raqeebHistory => 'Conversations';

  @override
  String get raqeebLearnMore => 'Learn more';

  @override
  String get raqeebNeedsSpecialist => 'Needs a specialist';

  @override
  String get raqeebNewChat => 'New question';

  @override
  String get raqeebNoHistory => 'Your conversations will appear here';

  @override
  String get raqeebNotFound => 'Not found in the available sources';

  @override
  String get raqeebNotSent => 'Not sent';

  @override
  String get raqeebOpen => 'Open';

  @override
  String get raqeebProcessing => 'Raqeeb is still answering…';

  @override
  String get raqeebPrototypeAnswer =>
      'In this prototype I answer a few sample questions — try one of the suggestions. In the full app, I answer from reviewed sources and show where every answer comes from.';

  @override
  String get raqeebQuranExact => 'Matches the Quran';

  @override
  String get raqeebQuranInexact => 'The verse text is inexact';

  @override
  String get raqeebRaqeebName => 'Raqeeb';

  @override
  String get raqeebRaqeebTagline => 'Your trusted guide to reliable answers';

  @override
  String get raqeebRaqeebThinking => 'Checking the sources…';

  @override
  String get raqeebRaqeebTrust1 => 'Answers from reviewed, reliable sources';

  @override
  String get raqeebRaqeebTrust2 => 'Shows where every answer comes from';

  @override
  String get raqeebRaqeebTrust3 => 'Checks whether quotes and hadiths are authentic';

  @override
  String get raqeebRaqeebTrust4 => 'Refers you to a specialist when needed';

  @override
  String get raqeebRateDown => 'This answer could be clearer';

  @override
  String get raqeebRateFailed => 'We couldn’t save your rating. Try again.';

  @override
  String get raqeebRateLimited => 'You’ve asked a lot in a short time. Let’s pause before trying again.';

  @override
  String get raqeebRateUp => 'This answer helped';

  @override
  String get raqeebSending => 'Sending…';

  @override
  String get raqeebSources => 'Sources';

  @override
  String get raqeebSpecialistSent => 'Sent privately — you’ll be notified when they reply.';

  @override
  String get raqeebSpecialistTitle => 'A specialist can help';

  @override
  String get raqeebStageAdapting => 'Making the answer clearer for you…';

  @override
  String get raqeebStageClassifying => 'Understanding your question…';

  @override
  String get raqeebStageReading => 'Reading what you sent…';

  @override
  String get raqeebStageReceived => 'Receiving your question…';

  @override
  String get raqeebStageRetrieving => 'Looking through the sources…';

  @override
  String get raqeebStageVerifying => 'Checking the sources…';

  @override
  String get raqeebStageWriting => 'Writing your answer…';

  @override
  String get raqeebSuggestionArabic => 'Can I pray before I know Arabic?';

  @override
  String get raqeebSuggestionHadith => 'Is this hadith authentic? “The five prayers are like a river at your door.”';

  @override
  String get raqeebSuggestionIslam => 'What does the word “Islam” mean?';

  @override
  String get raqeebSuggestionPrayer => 'Why do Muslims pray five times a day?';

  @override
  String get raqeebTextLimit => 'Keep your question within 2,000 characters.';

  @override
  String get raqeebTextOnly => 'Your text question';

  @override
  String get raqeebTextOnlyPhase => 'You can ask a written question here. Voice, photos and documents will be available later.';

  @override
  String get raqeebTimeout => 'This answer is taking longer than expected. You can try again.';

  @override
  String get raqeebTruncated => 'Only part of the document was read';

  @override
  String get raqeebTryAsking => 'Try asking';

  @override
  String get raqeebUnderstood => 'What I understood from your message';

  @override
  String get raqeebWeak => 'Weak';

  @override
  String get recitationAgain => 'Record again';

  @override
  String get recitationBusy => 'Recitation checking is busy. Try again or skip.';

  @override
  String get recitationChecking => 'Checking…';

  @override
  String get recitationContinue => 'Continue with this reading';

  @override
  String get recitationCorrectWord => 'Correct';

  @override
  String get recitationDeveloperMissingExtra => 'Missing and extra words';

  @override
  String get recitationDeveloperOutcome => 'Synthetic recitation outcome (development only)';

  @override
  String get recitationDeveloperUnclear => 'Unclear recording';

  @override
  String get recitationExtraWord => 'An extra word';

  @override
  String get recitationMissingWord => 'Missing';

  @override
  String get recitationRetry => 'Try checking again';

  @override
  String get recitationSubstitutedWord => 'Try this word again';

  @override
  String recitationWordFeedback(String word, String result) {
    return '$word: $result';
  }

  @override
  String get reviewAgain => 'Again';

  @override
  String reviewCardsReady(String countText) {
    return '$countText cards are ready';
  }

  @override
  String get reviewEasy => 'Easy';

  @override
  String get reviewGood => 'Good';

  @override
  String get reviewHard => 'Hard';

  @override
  String get reviewHowWell => 'How well did you remember?';

  @override
  String get reviewIntervals1 => '1 min';

  @override
  String get reviewIntervals2 => '1 day';

  @override
  String get reviewIntervals3 => '3 days';

  @override
  String get reviewIntervals4 => '1 week';

  @override
  String get reviewReviewDone => 'Review complete';

  @override
  String get reviewReviewDoneBody => 'These will come back right before you’d forget them.';

  @override
  String get reviewReviewSubtitle => 'Small, well-timed reviews help what you learn stay with you.';

  @override
  String get reviewReviewTiming => 'Timed by how well you remember each one';

  @override
  String get reviewReviewTitle => 'Review';

  @override
  String get reviewStartReview => 'Start 60-second review';

  @override
  String get reviewTapToFlip => 'Tap the card to see the answer';

  @override
  String reviewWordsMasteredOf(String mastered, String total) {
    return '$mastered of $total mastered';
  }

  @override
  String get reviewYourWords => 'Your words';

  @override
  String get reviewerAbstention => 'Correct abstention (%)';

  @override
  String get reviewerAccuracy => 'Accuracy (%)';

  @override
  String get reviewerAccurate => 'Which lesson is more accurate?';

  @override
  String get reviewerActivated => 'Misconceptions activated';

  @override
  String get reviewerAdd => 'Add';

  @override
  String get reviewerAfter => 'After';

  @override
  String get reviewerAllStatuses => 'All statuses';

  @override
  String get reviewerAnswerKey => 'Answer key';

  @override
  String get reviewerApprove => 'Approve';

  @override
  String get reviewerArc => 'Lesson arc';

  @override
  String get reviewerArcMap => 'Arc map';

  @override
  String get reviewerBasis => 'Claim basis';

  @override
  String get reviewerBefore => 'Before';

  @override
  String get reviewerBenchmark => 'Raqeeb benchmark';

  @override
  String get reviewerBlindEmpty => 'No blind-test pairs remain.';

  @override
  String get reviewerBlindTest => 'Blind test';

  @override
  String reviewerBlockPosition(int current, int total) {
    return 'Block $current of $total';
  }

  @override
  String get reviewerBlocker => 'Blocker';

  @override
  String get reviewerBlockers => 'Approval is unavailable while blockers remain.';

  @override
  String get reviewerBrief => 'Lesson brief';

  @override
  String get reviewerClearer => 'Which lesson is clearer?';

  @override
  String get reviewerCommaIds => 'Comma-separated identifiers';

  @override
  String get reviewerCompiled => 'Built-in · compiled';

  @override
  String get reviewerConsole => 'Reviewer console';

  @override
  String get reviewerContentBudget => 'Content blocks';

  @override
  String get reviewerCreate => 'Create run';

  @override
  String get reviewerDepth => 'Depth profile';

  @override
  String get reviewerDone => 'Done';

  @override
  String get reviewerEditAr => 'Replacement Arabic text';

  @override
  String get reviewerEditEn => 'Replacement English text';

  @override
  String get reviewerEditPlan => 'Edit plan';

  @override
  String get reviewerEditSentence => 'Edit sentence';

  @override
  String get reviewerEditsSaved => 'Edits saved for approval.';

  @override
  String get reviewerEmail => 'Email';

  @override
  String get reviewerEvidence => 'Sentences and evidence';

  @override
  String get reviewerExerciseBudget => 'Graded exercises (2–6)';

  @override
  String get reviewerExercises => 'Exercises and answer keys';

  @override
  String get reviewerExperience => 'Learner experience';

  @override
  String get reviewerFactory => 'Lesson factory';

  @override
  String get reviewerGate1 => 'Gate 1 · Plan review';

  @override
  String get reviewerGate2 => 'Gate 2 · Draft review';

  @override
  String get reviewerGenerationMinutes => 'Average generation (minutes)';

  @override
  String get reviewerHandwritten => 'Which lesson do you think was written by a person?';

  @override
  String get reviewerIdentified => 'Handwritten identified (%)';

  @override
  String reviewerIdsPair(String left, String right) {
    return '$left → $right';
  }

  @override
  String get reviewerInfo => 'Information';

  @override
  String get reviewerInteractive => 'Learner acts';

  @override
  String get reviewerIntroduced => 'Introduced concepts';

  @override
  String get reviewerInvalidPlan => 'Check bilingual fields, objectives, concepts, arc and budgets before approval.';

  @override
  String get reviewerLearning => 'Learning';

  @override
  String get reviewerLessonA => 'Lesson A';

  @override
  String get reviewerLessonB => 'Lesson B';

  @override
  String get reviewerLessonType => 'Lesson type';

  @override
  String get reviewerLockout => 'Too many attempts. Please wait before trying again.';

  @override
  String get reviewerMetrics => 'Metrics';

  @override
  String get reviewerMinutes => 'Estimated minutes';

  @override
  String get reviewerMisconceptions => 'Target misconceptions';

  @override
  String get reviewerMore => 'Load more';

  @override
  String get reviewerNewRun => 'New run';

  @override
  String get reviewerNoIssues => 'No QA findings.';

  @override
  String get reviewerNoKey => 'Self-rated or checked recitation; no stored answer key.';

  @override
  String get reviewerNoMetrics => 'No measurements are available.';

  @override
  String get reviewerNoRuns => 'No runs match this filter.';

  @override
  String get reviewerNotMeasured => 'Not measured yet';

  @override
  String get reviewerNotSupporting => 'Does not support this claim';

  @override
  String get reviewerNote => 'Review note';

  @override
  String get reviewerObjectives => 'Objectives (1–3)';

  @override
  String get reviewerOpenRun => 'Open run';

  @override
  String get reviewerOutcome => 'Primary learning outcome';

  @override
  String get reviewerPairedEnglish => 'An Arabic edit requires the matching English edit for this sentence and track.';

  @override
  String get reviewerParticipants => 'Participants';

  @override
  String reviewerParticipantsValue(String value) {
    return 'Participants: $value';
  }

  @override
  String get reviewerPassword => 'Password';

  @override
  String get reviewerPending => 'Pending';

  @override
  String reviewerPercentValue(String label, String value) {
    return '$label · $value%';
  }

  @override
  String reviewerPercentageNumber(String value) {
    return '$value%';
  }

  @override
  String get reviewerPlaceholder => 'Placeholder / requires review';

  @override
  String get reviewerPlan => 'Lesson plan';

  @override
  String get reviewerPosition => 'Position in unit (from 0)';

  @override
  String get reviewerPrePost => 'Before / after assessment';

  @override
  String get reviewerPreferred => 'Generated preferred or same (%)';

  @override
  String get reviewerPrerequisites => 'Prerequisite concepts';

  @override
  String get reviewerPreview => 'Learner preview';

  @override
  String get reviewerPreviewEmpty => 'No preview blocks are available.';

  @override
  String get reviewerPublished => 'Lessons published';

  @override
  String get reviewerQA => 'QA report';

  @override
  String get reviewerQuestion => 'Central learner question';

  @override
  String get reviewerRationale => 'Rationale';

  @override
  String get reviewerReasonRequired => 'Add a review note explaining the requested changes.';

  @override
  String get reviewerReasoning => 'Reasoning tools and justifications';

  @override
  String get reviewerReconfirm => 'I have reviewed the latest version';

  @override
  String get reviewerReferral => 'Correct referral (%)';

  @override
  String get reviewerRegenerate => 'Regenerate image';

  @override
  String get reviewerRegenerationAccepted => 'Regeneration accepted. The placeholder remains until an audited asset is available.';

  @override
  String get reviewerReject => 'Reject';

  @override
  String get reviewerRemove => 'Remove';

  @override
  String get reviewerRemoveExercise => 'Remove on approval';

  @override
  String get reviewerRequestChanges => 'Request changes';

  @override
  String get reviewerResolutionRate => 'Resolution rate (%)';

  @override
  String get reviewerResolved => 'Misconceptions resolved';

  @override
  String get reviewerResponses => 'Blind-test responses';

  @override
  String get reviewerReveal => 'Continue preview';

  @override
  String get reviewerReviewMinutes => 'Average review (minutes)';

  @override
  String get reviewerRole => 'Sentence role';

  @override
  String get reviewerRuns => 'Runs';

  @override
  String get reviewerSame => 'Same';

  @override
  String get reviewerSaveEdits => 'Save paired edits';

  @override
  String get reviewerSavePlan => 'Save plan';

  @override
  String get reviewerSelectRun => 'Select a run to review its plan or draft.';

  @override
  String get reviewerSignIn => 'Reviewer sign in';

  @override
  String get reviewerSignOut => 'Sign out';

  @override
  String get reviewerSkipped => 'Skipped';

  @override
  String get reviewerStage => 'Stage';

  @override
  String get reviewerStale => 'This review changed. The latest run has been loaded. Review it again before submitting a decision.';

  @override
  String get reviewerStandalone => 'Eligible for Discover';

  @override
  String reviewerStatusStage(String status, String stage) {
    return '$status · $stage';
  }

  @override
  String get reviewerSubmit => 'Submit review';

  @override
  String get reviewerSupports => 'Supporting evidence';

  @override
  String get reviewerTargets =>
      'Guidance: 6–10 minutes; foundational lessons about 8–10. Usually 3–5 exercises (story: 2–4). Completeness takes priority; never pad or split by duration alone.';

  @override
  String get reviewerTerms => 'New terms';

  @override
  String get reviewerTitle => 'Title';

  @override
  String get reviewerUnderstandings => 'Supporting understandings';

  @override
  String get reviewerUnitId => 'Unit ID';

  @override
  String get reviewerUnitsCompleted => 'Units completed';

  @override
  String get reviewerUnitsStarted => 'Units started';

  @override
  String get reviewerUnsupported => 'Unsupported claims (%)';

  @override
  String get reviewerUnsure => 'Unsure';

  @override
  String get reviewerValidation => 'Validation findings';

  @override
  String get reviewerValueAddresseeSpecific => 'Addressee specific';

  @override
  String get reviewerValueAwaitingGate1 => 'Awaiting Gate 1';

  @override
  String get reviewerValueAwaitingGate2 => 'Awaiting Gate 2';

  @override
  String get reviewerValueBaselineLlm => 'Baseline model';

  @override
  String get reviewerValueBeliefGrading => 'Belief grading';

  @override
  String get reviewerValueBeyondSource => 'Beyond the source';

  @override
  String get reviewerValueCausalReasoning => 'Causal reasoning';

  @override
  String get reviewerValueCircularReasoning => 'Circular reasoning';

  @override
  String get reviewerValueClaim => 'Claim';

  @override
  String get reviewerValueComparison => 'Comparison';

  @override
  String get reviewerValueConcept => 'Concept';

  @override
  String get reviewerValueConsistency => 'Consistency';

  @override
  String get reviewerValueContextDependent => 'Context dependent';

  @override
  String get reviewerValueDecompose => 'Decompose';

  @override
  String get reviewerValueDemonstration => 'Demonstration';

  @override
  String get reviewerValueDifferingOpinions => 'Differing opinions';

  @override
  String get reviewerValueDone => 'Done';

  @override
  String get reviewerValueDoubtOrDeepCreed => 'Doubt or deep creed';

  @override
  String get reviewerValueDropped => 'Dropped';

  @override
  String get reviewerValueEvidence => 'Evidence';

  @override
  String get reviewerValueExact => 'Exact fit';

  @override
  String get reviewerValueExample => 'Example';

  @override
  String get reviewerValueExercises => 'Exercises';

  @override
  String get reviewerValueExplanation => 'Explanation';

  @override
  String get reviewerValueExplorer => 'Explorer';

  @override
  String get reviewerValueFailed => 'Failed';

  @override
  String get reviewerValueFatwaLike => 'Fatwa-like';

  @override
  String get reviewerValueFocused => 'Focused';

  @override
  String get reviewerValueFoundational => 'Foundational';

  @override
  String get reviewerValueFraming => 'Framing';

  @override
  String get reviewerValueGeneralKnowledge => 'General knowledge';

  @override
  String get reviewerValueGeneralisedFromSpecific => 'Generalised from a specific case';

  @override
  String get reviewerValueHistoricalEvidence => 'Historical evidence';

  @override
  String get reviewerValueHypothetical => 'Hypothetical';

  @override
  String get reviewerValueImagePolicy => 'Image policy';

  @override
  String get reviewerValueInference => 'Inference';

  @override
  String get reviewerValueInstruction => 'Instruction';

  @override
  String get reviewerValueLocalization => 'Localization';

  @override
  String get reviewerValueLocalize => 'Localize';

  @override
  String get reviewerValueNeedsTafsir => 'Needs tafsir';

  @override
  String get reviewerValueNewMuslim => 'New Muslim';

  @override
  String get reviewerValueObservation => 'Observation';

  @override
  String get reviewerValueOutOfScope => 'Out of scope';

  @override
  String get reviewerValueOversimplified => 'Oversimplified';

  @override
  String get reviewerValuePartial => 'Partial fit';

  @override
  String get reviewerValuePedagogy => 'Pedagogy';

  @override
  String get reviewerValuePending => 'Pending';

  @override
  String get reviewerValuePersonalFatwa => 'Personal fatwa';

  @override
  String get reviewerValuePlan => 'Plan';

  @override
  String get reviewerValuePractice => 'Practice';

  @override
  String get reviewerValuePrediction => 'Prediction';

  @override
  String get reviewerValuePublish => 'Publish';

  @override
  String get reviewerValuePublished => 'Published';

  @override
  String get reviewerValueQa => 'Quality assurance';

  @override
  String get reviewerValueQuestion => 'Question';

  @override
  String get reviewerValueRaqeeb => 'Raqeeb';

  @override
  String get reviewerValueReadingLevel => 'Reading level';

  @override
  String get reviewerValueReasoning => 'Reasoning';

  @override
  String get reviewerValueReflection => 'Reflection';

  @override
  String get reviewerValueRejected => 'Rejected';

  @override
  String get reviewerValueRetrieve => 'Retrieve';

  @override
  String get reviewerValueRunning => 'Running';

  @override
  String get reviewerValueScenario => 'Scenario';

  @override
  String get reviewerValueSceneAuthor => 'Scene authoring';

  @override
  String get reviewerValueSceneRender => 'Scene rendering';

  @override
  String get reviewerValueScholarlyDisagreement => 'Scholarly disagreement';

  @override
  String get reviewerValueScholarlyReview => 'Scholarly review';

  @override
  String get reviewerValueSensitive => 'Sensitive';

  @override
  String get reviewerValueSensitiveHuman => 'Sensitive personal question';

  @override
  String get reviewerValueSingleOpinionAsConsensus => 'One opinion presented as consensus';

  @override
  String get reviewerValueSkipped => 'Skipped';

  @override
  String get reviewerValueSource => 'Source';

  @override
  String get reviewerValueStandard => 'Standard';

  @override
  String get reviewerValueStory => 'Story';

  @override
  String get reviewerValueStretched => 'Stretched';

  @override
  String get reviewerValueSupported => 'Supported';

  @override
  String get reviewerValueTakeaway => 'Takeaway';

  @override
  String get reviewerValueTestimony => 'Testimony';

  @override
  String get reviewerValueTextExplanation => 'Text explanation';

  @override
  String get reviewerValueTranslationSensitive => 'Translation sensitive';

  @override
  String get reviewerValueUnknown => 'Unknown';

  @override
  String get reviewerValueUnrelated => 'Unrelated';

  @override
  String get reviewerValueUnsupportedSentence => 'Unsupported sentence';

  @override
  String get reviewerValueValidation => 'Validation';

  @override
  String get reviewerValueVerification => 'Verification';

  @override
  String get reviewerValueVerify => 'Verify';

  @override
  String get reviewerValueVisuals => 'Visuals';

  @override
  String get reviewerValueWrite => 'Write';

  @override
  String get reviewerVisuals => 'Visuals';

  @override
  String get reviewerWarning => 'Warning';

  @override
  String get sessionAllCaughtUp => 'All caught up';

  @override
  String get sessionAnswerReview => 'Your answers';

  @override
  String get sessionApplying => 'Applying';

  @override
  String get sessionBackToJourney => 'Back to my journey';

  @override
  String get sessionBegin => 'Begin';

  @override
  String sessionBlank(String number) {
    return 'Gap $number';
  }

  @override
  String get sessionChooseReason => 'Choose the reason';

  @override
  String sessionCombo(String count) {
    return '$count in a row';
  }

  @override
  String get sessionComesBack => 'Coming back in review';

  @override
  String get sessionCompanionIntro => 'I’ll walk with you. Tap any underlined word if it’s new.';

  @override
  String get sessionCorrectAnswerIs => 'Correct answer:';

  @override
  String get sessionExercisePlaceholderBody => 'Exercises will be interactive in the next phase. Continue to preview the lesson content.';

  @override
  String get sessionExercisePlaceholderTitle => 'Exercise preview';

  @override
  String sessionExercisesCount(String countText) {
    return '$countText activities';
  }

  @override
  String get sessionFalseLabel => 'False';

  @override
  String get sessionFillBlank => 'Fill the gaps';

  @override
  String get sessionFindOut => 'Let’s find out';

  @override
  String get sessionGentle1 => 'Not quite — and that’s okay';

  @override
  String get sessionGentle2 => 'So close';

  @override
  String get sessionGentle3 => 'Good try';

  @override
  String get sessionIllTry => 'I’ll try it';

  @override
  String get sessionInTwoDays => 'In 2 days';

  @override
  String get sessionKeepLearning => 'Keep learning';

  @override
  String get sessionKindChoose => 'Choose';

  @override
  String get sessionKindDay => 'Your day';

  @override
  String get sessionKindDiscover => 'Discover';

  @override
  String get sessionKindFix => 'Correct the idea';

  @override
  String get sessionKindGuess => 'Your guess';

  @override
  String get sessionKindMatch => 'Match';

  @override
  String get sessionKindOrder => 'Put in order';

  @override
  String get sessionKindRealLife => 'Real life';

  @override
  String get sessionKindRecite => 'Recite';

  @override
  String get sessionKindSort => 'Sort';

  @override
  String get sessionKindTrueFalse => 'True or false';

  @override
  String get sessionLeave => 'Leave';

  @override
  String get sessionLessonComplete => 'Lesson complete!';

  @override
  String get sessionLessonCompleteSub => 'Another step on your path — taken calmly and well.';

  @override
  String sessionLessonPosition(String unit, String lesson) {
    return 'Unit $unit · Lesson $lesson';
  }

  @override
  String get sessionListenReciter => 'Listen to the reciter';

  @override
  String get sessionListening => 'Listening…';

  @override
  String sessionMapPin(String number) {
    return 'Place $number';
  }

  @override
  String get sessionMasteryNote => 'Progress in Qabas follows mastery, not just finishing. Remembering is measured in review sessions.';

  @override
  String get sessionMeaning => 'Meaning';

  @override
  String get sessionMistakenIdea => 'A common misconception';

  @override
  String sessionNextOnPath(String title) {
    return 'Next on your path: $title';
  }

  @override
  String sessionNextUnlocked(String title) {
    return 'Next on your path: $title';
  }

  @override
  String get sessionNiceThinking => 'Nice thinking!';

  @override
  String get sessionOriginTitle => 'Where did this story come from?';

  @override
  String get sessionPairHint => 'Tap a word, then its meaning. Tap a pair to change it.';

  @override
  String get sessionPerfectBonus => 'Perfect lesson bonus';

  @override
  String get sessionPlaying => 'Playing…';

  @override
  String get sessionPraise1 => 'Well done!';

  @override
  String get sessionPraise2 => 'Exactly right';

  @override
  String get sessionPraise3 => 'Beautiful!';

  @override
  String get sessionPraise4 => 'That’s it!';

  @override
  String get sessionPraise5 => 'Spot on';

  @override
  String get sessionPretestThanks => 'Thank you for sharing what you know';

  @override
  String get sessionPreviewEndBody =>
      'You’ve reached the end of the content preview. Exercises and lesson completion are coming in the next phases.';

  @override
  String get sessionPreviewEndTitle => 'Content preview complete';

  @override
  String sessionProgress(String percent) {
    return '$percent% complete';
  }

  @override
  String get sessionQuickReview => 'Quick review';

  @override
  String get sessionQuitBody => 'Your progress in this lesson won’t be saved. You can come back any time.';

  @override
  String get sessionQuitTitle => 'Leave this lesson?';

  @override
  String get sessionReadLesson => 'Read lesson';

  @override
  String get sessionReaderEmpty => 'This lesson has no reading content yet.';

  @override
  String get sessionReciteBody => 'The verse that tells us prayer has set times.';

  @override
  String get sessionReciteGreat => 'Beautifully read';

  @override
  String get sessionReciteTip => 'One gentle tip: blend the “-an” of kitāban into the m of mawqūtā — a soft nasal hum.';

  @override
  String get sessionReciteTitle => 'Listen, then read it aloud';

  @override
  String get sessionRecordingUnavailable => 'Recording isn’t available yet';

  @override
  String get sessionRemediation => 'Let’s clarify this idea';

  @override
  String get sessionRemembering => 'Remembering';

  @override
  String get sessionReport => 'Report';

  @override
  String get sessionResultPendingBody => 'The celebration screen is coming soon. You can return to your journey.';

  @override
  String get sessionResultPendingTitle => 'Your session is saved';

  @override
  String get sessionRetryBody => 'Let’s revisit the ideas you’re still practising.';

  @override
  String get sessionRetryTitle => 'A chance to try again';

  @override
  String get sessionReviewedBySpecialist => 'Reviewed by an Islamic-studies specialist';

  @override
  String get sessionSalahPreview => 'Salah preview';

  @override
  String sessionSecondsRemaining(String seconds) {
    return '$seconds seconds remaining';
  }

  @override
  String get sessionSelectAnswer => 'Choose an answer';

  @override
  String get sessionShowAll => 'Show all';

  @override
  String get sessionShowMore => 'Next idea';

  @override
  String get sessionSimulatedNote => 'Prototype: audio and speech feedback are simulated.';

  @override
  String get sessionSituation => 'A real moment';

  @override
  String get sessionSkipRecite => 'I can’t speak now';

  @override
  String get sessionSkipped => 'Skipped';

  @override
  String get sessionSoon => 'In review';

  @override
  String sessionSourcesLine(String countText) {
    return '$countText authenticated sources';
  }

  @override
  String get sessionSourcesTitle => 'Sources for this lesson';

  @override
  String get sessionSpotError => 'Find the mistaken part';

  @override
  String get sessionStatAccuracy => 'Accuracy';

  @override
  String get sessionStatEmbers => 'Embers';

  @override
  String get sessionStatTime => 'Time';

  @override
  String get sessionSubmitError => 'Your answer is kept. Please try again.';

  @override
  String get sessionTapInOrder => 'Tap them in order.';

  @override
  String get sessionTapTheScene => 'Tap the right place in the picture.';

  @override
  String get sessionTapThenPlace => 'Tap a phrase, then the group it belongs to.';

  @override
  String get sessionTapThenSlot => 'Tap a prayer, then its moment in the day.';

  @override
  String get sessionTapToContinue => 'Tap to continue';

  @override
  String get sessionTestPassed => 'Unit test passed';

  @override
  String get sessionTestTryAgain => 'Keep building your understanding';

  @override
  String get sessionTheStory => 'The story';

  @override
  String get sessionThenAWeek => 'Then in a week';

  @override
  String get sessionThinkFirst => 'Think about it for a moment — there’s no wrong answer here.';

  @override
  String get sessionTodaysChallenge => 'Today’s small challenge';

  @override
  String get sessionTomorrowWeAsk => 'Tomorrow we’ll ask';

  @override
  String get sessionTransliteration => 'Transliteration';

  @override
  String get sessionTrueLabel => 'True';

  @override
  String get sessionUnderstanding => 'Understanding';

  @override
  String get sessionUnit0ContentPreview => 'Unit 0 content preview';

  @override
  String get sessionUpdateRequired => 'Update the app to continue';

  @override
  String sessionVerseReference(String surah, String ayah) {
    return 'Surah $surah · Ayah $ayah';
  }

  @override
  String get sessionWhichEvidence => 'Choose the evidence';

  @override
  String get sessionWhyLabel => 'Why';

  @override
  String get sessionYouWillLearn => 'You’ll learn';

  @override
  String get sessionYourAnswer => 'Your answer';

  @override
  String get sessionYourMastery => 'Your mastery';

  @override
  String get sessionYourTurn => 'Your turn — tap and read aloud';

  @override
  String get settingsAboutQabas => 'About Qabas';

  @override
  String get settingsArabic => 'العربية';

  @override
  String get settingsCharacters => 'Characters';

  @override
  String get settingsContentNote => 'About this content';

  @override
  String get settingsContentNoteBody =>
      'Qabas content is drawn from verified sources. It is pending review by a specialist in Islamic studies before publication.';

  @override
  String get settingsDailyGoalSetting => 'Daily goal';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountBody =>
      'Delete your account and learning progress? This cannot be undone. Your data will be removed within 30 days.';

  @override
  String get settingsDemoReset => 'Demo progress reset';

  @override
  String get settingsDiscreetReminders => 'Discreet reminders';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsHapticsLabel => 'Haptics';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLearnerPath => 'Learning path';

  @override
  String get settingsPrivateProfileSetting => 'Private profile';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsReduceMotionBody => 'Calmer screens, no jumps or particles';

  @override
  String get settingsReminders => 'Reminder time';

  @override
  String get settingsReplayOnboarding => 'Replay onboarding';

  @override
  String get settingsResetDemo => 'Reset demo progress';

  @override
  String get settingsResetDemoBody => 'Back to a 3-day streak with the Prayer lesson waiting';

  @override
  String get settingsSaveFailed => 'We couldn’t save that change. Please try again.';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionAccount => 'You';

  @override
  String get settingsSectionDemo => 'Prototype';

  @override
  String get settingsSectionExperience => 'Experience';

  @override
  String get settingsSectionLearning => 'Learning';

  @override
  String get settingsSectionPrivacy => 'Privacy';

  @override
  String get settingsSoundEffects => 'Sound effects';

  @override
  String get streakDayStreakLabel => 'day streak';

  @override
  String get streakKeepFlameWarm => 'Learn a little today to keep your flame warm.';

  @override
  String get streakLastFiveWeeks => 'Your last five weeks';

  @override
  String get streakRestDays => 'Rest days';

  @override
  String get streakRestDaysBody => 'Life happens. One rest day a week keeps your flame warm — no guilt, no lost progress.';

  @override
  String get streakStreakBody => 'You lit today’s flame. A little light every day becomes a path.';

  @override
  String get streakStreakKeep => 'Keep the flame';

  @override
  String streakStreakTitle(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countText-day streak!');
    return '$_temp0';
  }

  @override
  String get streakToday => 'Today';

  @override
  String get unitGuideEmpty => 'There is no guide content yet.';
}
