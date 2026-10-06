// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get aboutAiNotice => 'تُعالج الأسئلة بواسطة خدمات الذكاء الاصطناعي. وللفتاوى الشخصية، استشر مختصًا مؤهلًا.';

  @override
  String get aboutFullVerse => 'اقرأ الآية كاملة';

  @override
  String get aboutNameMeaning =>
      'القبس شعلة صغيرة تؤخذ من نار أكبر، تُحمل لتمنح النور والدفء. والكلمة من القرآن الكريم، في قصة موسى عليه السلام: كان يسير ليلًا مع أهله، في البرد، غير متيقّن من الطريق، فرأى نارًا من بعيد.';

  @override
  String get aboutNameMeaningTitle => 'الاسم';

  @override
  String get aboutOurPromises => 'وعودنا';

  @override
  String get aboutPromise1 => 'كل درس يراجعه مختص في العلوم الشرعية';

  @override
  String get aboutPromise2 => 'الآيات والأحاديث تُنقل بنصها مع مصادرها';

  @override
  String get aboutPromise3 => 'نرحّب ولا نضغط، واسأل عن أي شيء بأمان';

  @override
  String get aboutPromise4 => 'رحلتك خاصة إلا إذا اخترت مشاركتها';

  @override
  String get aboutTahaReference => 'سورة طه: ١٠';

  @override
  String get aboutTranslationNote => 'المصدر: Quran.com';

  @override
  String get aboutVerseTranslation => 'لعلّي آتيكم بقبس أو أجد عند النار هدى.';

  @override
  String get aboutWhyItFits =>
      'وهذه قصة متعلّمنا: يرى نورًا من بعيد، فيدفعه الفضول إليه، فيجد الهداية. قبس هو تلك الشعلة الأولى: صغيرة، دافئة، تدعو إليها، وتقود إلى ما هو أعظم.';

  @override
  String get challengeAccept => 'انضم إلى التحدي';

  @override
  String get challengeAnswered => 'تم تثبيت الإجابة';

  @override
  String get challengeAsync => 'العب الآن؛ صديقك يلعب لاحقًا';

  @override
  String get challengeBotFill => 'أكمل المقاعد الفارغة بمدربين';

  @override
  String get challengeChooseFriends => 'اختر حتى ثلاثة أصدقاء';

  @override
  String get challengeConnectionLost => 'انقطع الاتصال';

  @override
  String get challengeDecline => 'رفض';

  @override
  String challengeDisconnected(String name, String seconds) {
    return '$name يعيد الاتصال · $seconds ث';
  }

  @override
  String get challengeDone => 'تم';

  @override
  String get challengeDraw => 'أضأتم الطريق معًا!';

  @override
  String get challengeFastest => 'الأسرع';

  @override
  String get challengeGetReady => 'استعد';

  @override
  String get challengeGroup => 'تحدَّ الأصدقاء';

  @override
  String get challengeInvitations => 'الدعوات';

  @override
  String challengeInviteFrom(String name) {
    return 'تحدٍّ من $name';
  }

  @override
  String get challengeLiveLobby => 'الأصدقاء ينضمون…';

  @override
  String get challengeNoInvitations => 'لا توجد دعوات حاليًا';

  @override
  String get challengeNotJoinableTitle => 'بدأ هذا التحدي أو انتهى بالفعل';

  @override
  String get challengePlayAgain => 'العب مجددًا';

  @override
  String get challengePoints => 'نقطة';

  @override
  String get challengePracticeBot => 'تدرّب مع المدرب';

  @override
  String challengeQuestionOf(String current, String total) {
    return 'السؤال $current من $total';
  }

  @override
  String get challengeReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get challengeResults => 'النتائج';

  @override
  String challengeSeconds(String value) {
    return '$value ث';
  }

  @override
  String get challengeSummary => 'مراجعة الإجابات';

  @override
  String get challengeWaitingFriend => 'في انتظار صديقك';

  @override
  String get challengeWellPlayed => 'لعب جميل!';

  @override
  String get challengeYouWon => 'كنت الأسرع!';

  @override
  String get characterGuideSemantics => 'رفيقك يحمل قبسًا صغيرًا';

  @override
  String get characterLanternSemantics => 'فانوس رقيب';

  @override
  String get commonAppName => 'قبس';

  @override
  String get commonArabic => 'العربية';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonBrandArabic => 'قبس';

  @override
  String get commonBrandLatin => 'Qabas';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonCheck => 'تحقّق';

  @override
  String get commonChooseAnother => 'اختر غيره';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonConnectingSlow => 'جارٍ الاتصال بقبس… قد تستغرق الزيارة الأولى دقيقة واحدة.';

  @override
  String get commonContinue => 'متابعة';

  @override
  String commonDayStreak(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText يومًا متتالية',
      few: '$countText أيام متتالية',
      two: '$countText يومان متتالية',
      one: '$countText يوم متتالية',
      zero: '$countText أيام متتالية',
    );
    return '$_temp0';
  }

  @override
  String commonDays(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText يومًا',
      few: '$countText أيام',
      two: '$countText أيام',
      one: '$countText يوم',
      zero: '$countText أيام',
    );
    return '$_temp0';
  }

  @override
  String get commonDone => 'تم';

  @override
  String get commonEdit => 'تعديل';

  @override
  String commonEmbers(String value) {
    return '$value قبسة';
  }

  @override
  String get commonEmbersName => 'القبسات';

  @override
  String get commonEnglish => 'English';

  @override
  String get commonGotIt => 'فهمت';

  @override
  String get commonLater => 'لاحقًا';

  @override
  String get commonLoading => 'جارٍ التحميل…';

  @override
  String commonMinutes(String value) {
    return '$value د';
  }

  @override
  String commonMinutesLong(num count, String value) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$value دقيقة',
      few: '$value دقائق',
      two: '$value دقائق',
      one: '$value دقائق',
      zero: '$value دقائق',
    );
    return '$_temp0';
  }

  @override
  String get commonNew => 'جديد';

  @override
  String get commonNext => 'التالي';

  @override
  String get commonOfflineBody => 'أنت غير متصل. سنحفظ ما أنجزته.';

  @override
  String get commonPathExplorer => 'المستكشف';

  @override
  String get commonPathExplorerLong => 'مسار المستكشف';

  @override
  String get commonPathNewMuslim => 'المسلم الجديد';

  @override
  String get commonPathNewMuslimLong => 'مسار المسلم الجديد';

  @override
  String commonPercent(String value) {
    return '$value٪';
  }

  @override
  String commonPlusEmbers(String value) {
    return '+$value قبسة';
  }

  @override
  String get commonRecordTooltip => 'سجّل سؤالًا';

  @override
  String get commonRemoveAttachmentTooltip => 'إزالة المرفق';

  @override
  String get commonRetry => 'حاول مجددًا';

  @override
  String get commonSeeAll => 'عرض الكل';

  @override
  String get commonSendTooltip => 'إرسال';

  @override
  String get commonSessionEndedBody => 'انتهت جلستك كضيف. سنساعدك على بدء رحلة جديدة.';

  @override
  String get commonSessionEndedTitle => 'لنبدأ مجددًا';

  @override
  String get commonSkip => 'تخطَّ';

  @override
  String get commonStart => 'ابدأ';

  @override
  String get commonTabCommunity => 'المجتمع';

  @override
  String get commonTabDiscover => 'اكتشف';

  @override
  String get commonTabJourney => 'الرحلة';

  @override
  String get commonTabProfile => 'حسابي';

  @override
  String get commonTabRaqeeb => 'رقيب';

  @override
  String get commonTabReview => 'المراجعة';

  @override
  String get commonTagline => 'تعلّم الإسلام خطوة بخطوة، من أول سؤال إلى فهم متين.';

  @override
  String get commonUpdate => 'حدّث قبس';

  @override
  String get commonUpdateBody => 'حدّث قبس لتواصل التعلّم. رحلتك بانتظارك.';

  @override
  String get commonUpdateTitle => 'تحديث صغير، وطريق أكثر نورًا';

  @override
  String get communityCommunityTitle => 'المجتمع';

  @override
  String get communityDailyQuests => 'مهام اليوم';

  @override
  String communityEndsIn(String days, String hours) {
    return 'ينتهي خلال $days يوم و$hours ساعة';
  }

  @override
  String get communityFriends => 'الأصدقاء';

  @override
  String get communityInvite => 'دعوة';

  @override
  String get communityJoinLeague => 'انضم إلى الدوري';

  @override
  String get communityLearningPrivately => 'أنت تتعلّم بخصوصية';

  @override
  String get communityLearningPrivatelyBody => 'نشاطك مخفي عن الدوري والأصدقاء. يمكنك الانضمام في أي وقت.';

  @override
  String get communityLiveChallenge => 'تحدٍّ مباشر';

  @override
  String get communityLiveChallengeBody => 'تحدَّ أصدقاءك في مسابقة مباشرة، والأسرع بالإجابة الصحيحة يفوز.';

  @override
  String get communityNoFriends => 'ادعُ صديقًا لتتعلموا معًا';

  @override
  String get communityNoLeagueTitle => 'اجمع جمرات لتنضم إلى دوري هذا الأسبوع';

  @override
  String get communityNoQuests => 'أنجزت مهام اليوم';

  @override
  String communityProgressCount(String current, String target) {
    return '$current/$target';
  }

  @override
  String communityPromoteLine(String countText, String league) {
    return 'أول $countText ينتقلون إلى $league';
  }

  @override
  String communityPromotionCount(String count) {
    return 'أفضل $count يصعدون';
  }

  @override
  String get communityPromotionZone => 'منطقة الترقّي';

  @override
  String communityQuestReward(String count) {
    return '+$count جمرة';
  }

  @override
  String communityResetsIn(String hours) {
    return 'تتجدد بعد $hours س';
  }

  @override
  String get communityStartChallenge => 'ابدأ تحدّيًا';

  @override
  String communityStreakDays(String countText) {
    return '$countText أيام متتالية';
  }

  @override
  String get communityTopTier => 'حافظ على نورك';

  @override
  String get communityYou => 'أنت';

  @override
  String get contentArticle => 'مقال';

  @override
  String get contentAudioError => 'هذا الصوت غير متاح الآن.';

  @override
  String get contentBook => 'كتاب';

  @override
  String get contentFatwa => 'فتوى';

  @override
  String get contentHadithLabel => 'حديث';

  @override
  String get contentLearnMore => 'اعرف المزيد';

  @override
  String get contentLevelBasic => 'أساسي';

  @override
  String get contentLevelIntermediate => 'متوسط';

  @override
  String get contentLevelUnknown => 'مستواك';

  @override
  String get contentProviderDorar => 'الدرر السنية';

  @override
  String get contentProviderHadeethenc => 'موسوعة الأحاديث';

  @override
  String get contentProviderIslamhouse => 'IslamHouse';

  @override
  String get contentProviderQuranCom => 'Quran.com';

  @override
  String get contentProviderQuranenc => 'موسوعة القرآن';

  @override
  String get contentProviderTafsirCenter => 'مركز تفسير';

  @override
  String get contentQuranLabel => 'القرآن الكريم';

  @override
  String get contentSource => 'مصدر';

  @override
  String get contentTafsir => 'تفسير';

  @override
  String get contentViewSource => 'المصدر';

  @override
  String get discoverEmptyBody => 'ستظهر هنا دروس جديدة لتستكشفها.';

  @override
  String get discoverEmptyTitle => 'المزيد لتستكشفه';

  @override
  String get discoverNotice => 'تأتي بعض الدروس عادةً لاحقاً في طريقك. وقد تجعل الوحدات السابقة فهمها أسهل.';

  @override
  String discoverUnitHeading(String number, String title) {
    return 'الوحدة $number · $title';
  }

  @override
  String get errorFileTypeBody => 'نوع هذا الملف غير مدعوم.';

  @override
  String get errorFileTypeTitle => 'جرّب ملفًا آخر';

  @override
  String get errorForbiddenBody => 'هذا غير متاح لحسابك.';

  @override
  String get errorForbiddenTitle => 'هذا غير متاح';

  @override
  String get errorGenericBody => 'لنحاول مرة أخرى.';

  @override
  String get errorGenericTitle => 'حدث أمر غير متوقع';

  @override
  String get errorNetworkBody => 'تحقّق من اتصالك بالإنترنت وحاول مجددًا.';

  @override
  String get errorNetworkTitle => 'لا يوجد اتصال';

  @override
  String get errorNotFoundBody => 'عُد وخذ خطوة أخرى.';

  @override
  String get errorNotFoundTitle => 'لم نتمكن من العثور عليه';

  @override
  String errorRateLimitedBody(String time) {
    return 'يمكنك المحاولة مجددًا بعد $time.';
  }

  @override
  String get errorRateLimitedTitle => 'لننتظر قليلًا';

  @override
  String get errorServerBody => 'حدث خطأ لدينا. حاول مجددًا.';

  @override
  String get errorServerTitle => 'لحظة من الانتظار';

  @override
  String get errorSourcesBody => 'المصادر غير متاحة مؤقتًا. حاول بعد قليل.';

  @override
  String get errorSourcesTitle => 'المصادر تحتاج بعض الوقت';

  @override
  String get errorTooLargeBody => 'اختر ملفًا أصغر وحاول مجددًا.';

  @override
  String get errorTooLargeTitle => 'هذا الملف كبير جدًا';

  @override
  String get friendsAccept => 'قبول الدعوة';

  @override
  String get friendsAcceptCode => 'أدخل رمز الدعوة';

  @override
  String get friendsAccepted => 'يمكنكم الآن التعلم معًا';

  @override
  String get friendsAlreadyFriends => 'أنتم أصدقاء بالفعل.';

  @override
  String get friendsCode => 'رمز الدعوة';

  @override
  String get friendsInviteInvalid => 'هذا الرمز لا يعمل. تحقق منه وأعد المحاولة.';

  @override
  String get friendsOffline => 'غير متصل';

  @override
  String get friendsOnline => 'متصل';

  @override
  String get friendsRemove => 'إزالة الصديق';

  @override
  String friendsRemoveBody(String name) {
    return 'هل تريد إزالة $name من أصدقائك؟';
  }

  @override
  String get friendsShare => 'مشاركة الدعوة';

  @override
  String get galleryBrand => 'الهوية والرسوم';

  @override
  String get galleryButtons => 'الأزرار';

  @override
  String get galleryCardBody => 'قبسٌ صغير لرحلة كبيرة';

  @override
  String get galleryCelebrate => 'احتفل';

  @override
  String get galleryConfirm => 'نافذة التأكيد';

  @override
  String get galleryDisabled => 'غير مفعّل';

  @override
  String get galleryEmptyBody => 'مساحة صغيرة لشيء جديد.';

  @override
  String get galleryEmptyTitle => 'خطوتك التالية في الطريق';

  @override
  String get galleryInputs => 'الحقول والإعدادات';

  @override
  String get galleryMotion => 'الحركة';

  @override
  String get galleryNudge => 'جرّب حركة لطيفة';

  @override
  String get galleryOpenSheet => 'افتح النافذة';

  @override
  String get gallerySheets => 'النوافذ والإشعارات';

  @override
  String get galleryStates => 'التحميل والفراغ والخطأ';

  @override
  String get gallerySurfaces => 'البطاقات والتقدّم';

  @override
  String get galleryTitle => 'معرض المكوّنات';

  @override
  String get glossaryAll => 'الكل';

  @override
  String get glossaryAskRaqeeb => 'اسأل رقيب';

  @override
  String get glossaryEmpty => 'ستظهر هنا الكلمات التي تتعرف عليها في الدروس.';

  @override
  String get glossaryIKnowThis => 'أعرفها';

  @override
  String get glossaryLearning => 'قيد التعلم';

  @override
  String get glossaryLevelExplorer => 'مشروحة للمستكشف';

  @override
  String get glossaryLevelNewMuslim => 'مشروحة للمسلم الجديد';

  @override
  String get glossaryListen => 'استمع';

  @override
  String get glossaryLoadMore => 'اعرض كلمات أخرى';

  @override
  String get glossaryMastered => 'متقنة';

  @override
  String get glossaryNew => 'جديدة';

  @override
  String get glossaryUnderlineHint => 'حين تتقن الكلمة، يختفي الخط تحتها.';

  @override
  String get glossaryYourDictionary => 'قاموسك';

  @override
  String get journeyAvailable => 'متاح';

  @override
  String get journeyCheckpoint => 'محطة';

  @override
  String get journeyComingSoonBody =>
      'يتضمن هذا النموذج الأولي درسًا كاملًا واحدًا: «الصلاة: نهرٌ على باب يومك». بقية الرحلة تعرض كيف يتدرّج الطريق.';

  @override
  String get journeyComingSoonTitle => 'قريبًا';

  @override
  String get journeyDailyGoal => 'هدفك اليومي';

  @override
  String get journeyDoneLabel => 'مكتمل';

  @override
  String get journeyDownloadAction => 'تحميل تطبيق أندرويد';

  @override
  String get journeyDownloadBody => 'مصمم لأندرويد وiOS والويب وويندوز وmacOS ولينكس. جرّب قبس على أندرويد اليوم.';

  @override
  String get journeyDownloadDismiss => 'إغلاق إعلان تحميل تطبيق أندرويد';

  @override
  String get journeyDownloadEyebrow => 'أبعد من المتصفح';

  @override
  String get journeyDownloadFailed => 'تعذّر فتح رابط التحميل. حاول مرة أخرى.';

  @override
  String get journeyDownloadTitle => 'رحلة واحدة، عبر أجهزتك.';

  @override
  String get journeyEmptyBody => 'ستظهر خطواتك التالية هنا. حاول مجدداً بعد قليل.';

  @override
  String get journeyEmptyTitle => 'نعدّ طريقك';

  @override
  String get journeyExplorerPathHint => 'للمهتمين: الأسئلة الكبرى أولًا';

  @override
  String journeyGoalProgress(String done, String goal) {
    return '$done / $goal د';
  }

  @override
  String get journeyGreetingAfternoon => 'نهارك سعيد';

  @override
  String get journeyGreetingEvening => 'مساء الخير';

  @override
  String get journeyGreetingMorning => 'صباح الخير';

  @override
  String get journeyGuide => 'الدليل';

  @override
  String get journeyJumpBack => 'تابع';

  @override
  String get journeyKeepTheLight => 'طريقك مضاء. خطوة صغيرة اليوم؟';

  @override
  String get journeyLearnedTodayLine => 'أوقدت شعلة اليوم. عمل جميل.';

  @override
  String get journeyLesson => 'درس';

  @override
  String journeyLessonAction(String reward) {
    return 'ابدأ الدرس  $reward';
  }

  @override
  String get journeyLoading => 'نضيء طريقك…';

  @override
  String get journeyLockedBody => 'أكمل الخطوات التي قبلها وسيضيء لك الطريق.';

  @override
  String get journeyLockedTitle => 'ليس بعد';

  @override
  String get journeyNewMuslimPathHint => 'الخطوات الأولى في الإيمان والعبادة';

  @override
  String journeyNodeSemantics(String title, String status) {
    return '$title — $status';
  }

  @override
  String get journeyOpenPlayableLesson => 'جرّب الدرس النموذجي';

  @override
  String get journeyPathUnfolds => 'الطريق يتّسع كلما تقدّمت';

  @override
  String get journeyPillarNames1 => 'الشهادتان';

  @override
  String get journeyPillarNames2 => 'الصلاة';

  @override
  String get journeyPillarNames3 => 'الزكاة';

  @override
  String get journeyPillarNames4 => 'الحج';

  @override
  String get journeyPillarNames5 => 'الصوم';

  @override
  String get journeyPractice => 'تدريب';

  @override
  String get journeyQuickReview => 'مراجعة سريعة';

  @override
  String journeyReviewDue(String countText) {
    return '$countText بطاقات جاهزة لمراجعة في ٦٠ ثانية';
  }

  @override
  String get journeyReviewLesson => 'راجع الدرس';

  @override
  String get journeySkipUnit => 'تجاوز الوحدة';

  @override
  String get journeySoftLockBody => 'أنت قريب. فكرة سابقة واحدة ستجعل فهم هذا الدرس أسهل.';

  @override
  String get journeySoftLockTitle => 'فكرة واحدة أولاً';

  @override
  String get journeyStartHere => 'ابدأ';

  @override
  String get journeyStartLesson => 'ابدأ الدرس';

  @override
  String get journeyStartReview => 'ابدأ المراجعة';

  @override
  String journeyStartWith(String title) {
    return 'ابدأ بـ: $title';
  }

  @override
  String get journeyStory => 'قصة';

  @override
  String get journeyTakeUnitTest => 'ابدأ اختبار الوحدة';

  @override
  String get journeyUnitComplete => 'اكتملت الوحدة';

  @override
  String journeyUnitN(String number) {
    return 'الوحدة $number';
  }

  @override
  String get journeyWhatYoullLearn => 'في هذه الوحدة';

  @override
  String get journeyYourPath => 'مسارك';

  @override
  String get learningEntryBody => 'نعدّ هذا الجزء من طريقك. تقدمك محفوظ.';

  @override
  String get mediaCamera => 'التقط صورة';

  @override
  String get mediaCaptureFailed => 'تعذّر قراءة هذا التسجيل أو الملف. أعد المحاولة.';

  @override
  String get mediaCountLimit => 'يمكنك إرفاق ثلاث صور وملف واحد وتسجيل صوتي واحد.';

  @override
  String get mediaDocumentLimit => 'يمكن أن يصل حجم الملفات إلى ١٠ ميجابايت';

  @override
  String get mediaImageLimit => 'يمكن أن يصل حجم الصور إلى ٨ ميجابايت';

  @override
  String get mediaMicrophoneDenied => 'اسمح بالوصول إلى الميكروفون للتسجيل. يمكنك تغيير ذلك في الإعدادات.';

  @override
  String get mediaOpenSettings => 'فتح الإعدادات';

  @override
  String get mediaRecitationLimit => 'يمكن أن تصل التلاوة إلى ٣٠ ثانية و٥ ميجابايت';

  @override
  String get mediaRecord => 'دورك الآن';

  @override
  String mediaRecordingTime(String seconds, String limit) {
    return 'جارٍ التسجيل · $seconds / $limit ث';
  }

  @override
  String get mediaStopRecording => 'إيقاف التسجيل';

  @override
  String get mediaVoiceLimit => 'يمكن أن تصل التسجيلات الصوتية إلى ٦٠ ثانية و١٠ ميجابايت';

  @override
  String get onboardingArabicGlyph => 'أ';

  @override
  String get onboardingChooseLanguage => 'اختر لغتك';

  @override
  String get onboardingCompanionHello => 'أهلًا بك! سأحمل لك القبس وأنت تجد طريقك.';

  @override
  String get onboardingDiscreetBody => '«حان وقت درسك اليومي» — لا أكثر.';

  @override
  String get onboardingDiscreetTitle => 'تذكيرات متحفّظة';

  @override
  String get onboardingEnglishGlyph => 'Aa';

  @override
  String get onboardingExplorerBody => 'أسئلة كبيرة، وأجوبة واضحة، بلا ضغط.';

  @override
  String get onboardingExplorerTitle => 'أريد أن أتعرّف على الإسلام';

  @override
  String get onboardingFamiliarBasics => 'أعرف الأساسيات';

  @override
  String get onboardingFamiliarNew => 'جديد تمامًا';

  @override
  String get onboardingFamiliarNote => 'سنبدأ بهدوء في كل الأحوال، واختبار قصير لاحقًا يتخطى ما تعرفه.';

  @override
  String get onboardingFamiliarSome => 'أعرف القليل';

  @override
  String get onboardingFamiliarTitle => 'ما مدى معرفتك؟';

  @override
  String get onboardingGetStarted => 'لنبدأ';

  @override
  String get onboardingGoalBubble => 'قليلٌ دائم خيرٌ من كثيرٍ منقطع.';

  @override
  String get onboardingGoalDedicated => 'جادّ';

  @override
  String get onboardingGoalDeep => 'معمّق';

  @override
  String get onboardingGoalGentle => 'هادئ';

  @override
  String get onboardingGoalSteady => 'منتظم';

  @override
  String get onboardingGoalTitle => 'كم من الوقت يناسبك كل يوم؟';

  @override
  String get onboardingHaveAccount => 'لديّ حساب بالفعل';

  @override
  String get onboardingLanguageArabicPrompt => 'اختر لغتك';

  @override
  String get onboardingLanguageEnglishPrompt => 'Choose your language';

  @override
  String get onboardingLanguageHint => 'يمكنك تغييرها في أي وقت من الإعدادات.';

  @override
  String get onboardingNewMuslimBody => 'خطواتك الأولى في الإيمان والعبادة، خطوة بخطوة.';

  @override
  String get onboardingNewMuslimTitle => 'أسلمتُ حديثًا';

  @override
  String onboardingPerDay(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText دقيقة يوميًا',
      few: '$countText دقائق يوميًا',
      two: '$countText دقائق يوميًا',
      one: '$countText دقائق يوميًا',
      zero: '$countText دقائق يوميًا',
    );
    return '$_temp0';
  }

  @override
  String get onboardingPreferNotToSay => 'أفضل عدم الإجابة';

  @override
  String get onboardingPrivacyBody => 'تعلّم بخصوصية إن أردت. بعض الناس يفضّلون أن تبقى رحلتهم لأنفسهم، ولا بأس بذلك أبدًا.';

  @override
  String get onboardingPrivacyTitle => 'رحلتك تبقى لك';

  @override
  String get onboardingPrivateBody => 'إخفاء نشاطك عن الدوري والأصدقاء.';

  @override
  String get onboardingPrivateTitle => 'ملف شخصي خاص';

  @override
  String get onboardingReadyExplorer => 'سنبدأ بالأسئلة الكبرى، ثم نرى كيف يعيش المسلم إيمانه في يومه.';

  @override
  String get onboardingReadyNewMuslim => 'سنبدأ بخطواتك الأولى، الشهادتين ثم الصلاة، بهدوء وخطوة خطوة.';

  @override
  String get onboardingReadyTitle => 'طريقك جاهز';

  @override
  String onboardingReminderTime(String time) {
    return 'وقت التذكير: $time';
  }

  @override
  String get onboardingReminderTitle => 'وقت التذكير';

  @override
  String get onboardingSkipCuriosity => 'تخطّ الآن';

  @override
  String get onboardingStartMyJourney => 'ابدأ رحلتي';

  @override
  String onboardingStepOf(String current, String total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get onboardingSubmitError => 'تعذّر بدء رحلتك. احتفظنا باختياراتك.';

  @override
  String get onboardingWelcomeBody => 'دروس قصيرة، ومصادر موثوقة، ورفيق يمشي معك — بالسرعة التي تناسبك.';

  @override
  String get onboardingWelcomeExplorer => 'أهلًا بك. اسأل عن أي شيء، فأنت بين أصدقاء.';

  @override
  String get onboardingWelcomeNewMuslim => 'أهلًا بك، ومبارك عليك. سنمشي معًا خطوة بخطوة.';

  @override
  String get onboardingWelcomeTitle => 'قبسٌ صغير لرحلة كبيرة';

  @override
  String get onboardingWhoBubble => 'لا توجد إجابة خاطئة. سأصمم الطريق على مقاسك.';

  @override
  String get onboardingWhoTitle => 'ما الذي أتى بك إلى قبس؟';

  @override
  String get profileAchievementsTitle => 'الإنجازات';

  @override
  String get profileEditName => 'اسمك';

  @override
  String profileJoined(String month) {
    return 'انضممت في $month';
  }

  @override
  String profileLeagueRank(String rank) {
    return 'المرتبة $rank';
  }

  @override
  String get profileLearnerName => 'متعلّم';

  @override
  String get profileNameValidation => 'استخدم من حرفين إلى ٢٤ حرفًا.';

  @override
  String get profileNewBadge => 'وسام جديد!';

  @override
  String get profileNoAchievements => 'وسامك الأول ينتظرك في الطريق.';

  @override
  String get profileNoLeague => 'لم تنضم إلى دوري بعد';

  @override
  String get profileNoWords => 'ستظهر كلماتك هنا وأنت تتعلم.';

  @override
  String get profilePrivateBadge => 'خاص';

  @override
  String get profileProfileTitle => 'حسابي';

  @override
  String get profileSave => 'حفظ';

  @override
  String get profileSettings => 'الإعدادات';

  @override
  String get profileStatBadges => 'الأوسمة';

  @override
  String get profileStatLeague => 'الدوري';

  @override
  String get profileStatLessons => 'دروس';

  @override
  String get profileStatStreak => 'أيام متتالية';

  @override
  String get profileStatTotal => 'مجموع القبسات';

  @override
  String get profileStatWords => 'كلمات أتقنتها';

  @override
  String get profileStatistics => 'إحصاءات';

  @override
  String profileUnlockedOf(String current, String total) {
    return '$current من $total مفتوحة';
  }

  @override
  String get raqeebAbstained => 'إحالة أو امتناع عن الإجابة';

  @override
  String get raqeebAcceptable => 'حسن';

  @override
  String get raqeebAlternative => 'نص صحيح ذو معنى قريب';

  @override
  String get raqeebAskAnything => 'اسأل عن أي شيء…';

  @override
  String get raqeebAskSpecialist => 'اسأل مختصًا بشكل خاص';

  @override
  String get raqeebAttachDoc => 'مستند';

  @override
  String get raqeebAttachDocBody => 'يقرؤه رقيب ويجيب بالمصادر';

  @override
  String get raqeebAttachPhoto => 'صورة';

  @override
  String get raqeebAttachPhotoBody => 'لافتة، أو صفحة، أو منشور رأيته';

  @override
  String get raqeebAttachTitle => 'اسأل عبر…';

  @override
  String get raqeebAttachVoice => 'صوتك';

  @override
  String get raqeebAttachVoiceBody => 'اسأل بصوتك فقط';

  @override
  String get raqeebAuthentic => 'صحيح';

  @override
  String get raqeebAuthenticityCheck => 'التحقق من الصحة';

  @override
  String get raqeebExactText => 'النص الدقيق';

  @override
  String get raqeebFabricated => 'موضوع';

  @override
  String get raqeebFailed => 'لم أتمكن من إكمال الإجابة. لنحاول مرة أخرى.';

  @override
  String get raqeebFoundIn => 'موجود في';

  @override
  String get raqeebGrade => 'الحكم';

  @override
  String get raqeebGradeOther => 'حكم آخر';

  @override
  String get raqeebGrader => 'حكم عليه';

  @override
  String get raqeebHistory => 'المحادثات';

  @override
  String get raqeebLearnMore => 'تعلّم أكثر';

  @override
  String get raqeebNeedsSpecialist => 'يحتاج إلى مختص';

  @override
  String get raqeebNewChat => 'سؤال جديد';

  @override
  String get raqeebNoHistory => 'ستظهر محادثاتك هنا';

  @override
  String get raqeebNotFound => 'لم نجد له أصلاً في المصادر المتاحة';

  @override
  String get raqeebNotSent => 'لم تُرسل';

  @override
  String get raqeebOpen => 'فتح';

  @override
  String get raqeebProcessing => 'رقيب ما زال يكتب الإجابة…';

  @override
  String get raqeebPrototypeAnswer =>
      'في هذا النموذج الأولي أجيب عن بعض الأسئلة النموذجية، جرّب أحد الاقتراحات. في التطبيق الكامل أجيب من مصادر مراجَعة وأبيّن مصدر كل إجابة.';

  @override
  String get raqeebQuranExact => 'مطابق للمصحف';

  @override
  String get raqeebQuranInexact => 'نص الآية غير دقيق';

  @override
  String get raqeebRaqeebName => 'رقيب';

  @override
  String get raqeebRaqeebTagline => 'دليلك إلى إجابات موثوقة';

  @override
  String get raqeebRaqeebThinking => 'أراجع المصادر…';

  @override
  String get raqeebRaqeebTrust1 => 'يجيب من مصادر موثوقة ومراجَعة';

  @override
  String get raqeebRaqeebTrust2 => 'يبيّن مصدر كل إجابة';

  @override
  String get raqeebRaqeebTrust3 => 'يتحقق من صحة الأقوال والأحاديث';

  @override
  String get raqeebRaqeebTrust4 => 'يحيلك إلى مختص عند الحاجة';

  @override
  String get raqeebRateDown => 'الإجابة بحاجة إلى توضيح';

  @override
  String get raqeebRateFailed => 'تعذّر حفظ تقييمك. حاول مرة أخرى.';

  @override
  String get raqeebRateLimited => 'طرحت أسئلة كثيرة في وقت قصير. لننتظر قليلاً قبل المحاولة مرة أخرى.';

  @override
  String get raqeebRateUp => 'إجابة مفيدة';

  @override
  String get raqeebSending => 'جارٍ الإرسال…';

  @override
  String get raqeebSources => 'المصادر';

  @override
  String get raqeebSpecialistSent => 'أُرسل بشكل خاص، وسنخبرك حين يصل الرد.';

  @override
  String get raqeebSpecialistTitle => 'يمكن لمختص أن يساعدك';

  @override
  String get raqeebStageAdapting => 'أبسّط الإجابة لك';

  @override
  String get raqeebStageClassifying => 'أفهم سؤالك';

  @override
  String get raqeebStageReading => 'أقرأ ما أرسلته';

  @override
  String get raqeebStageReceived => 'أستقبل سؤالك…';

  @override
  String get raqeebStageRetrieving => 'أبحث في المصادر';

  @override
  String get raqeebStageVerifying => 'أتحقق من المصادر';

  @override
  String get raqeebStageWriting => 'أكتب الإجابة';

  @override
  String get raqeebSuggestionArabic => 'هل أستطيع أن أصلي قبل أن أتعلم العربية؟';

  @override
  String get raqeebSuggestionHadith => 'هل هذا الحديث صحيح؟ «الصلوات الخمس كنهر على باب أحدكم»';

  @override
  String get raqeebSuggestionIslam => 'ما معنى كلمة «إسلام»؟';

  @override
  String get raqeebSuggestionPrayer => 'لماذا يصلي المسلمون خمس مرات في اليوم؟';

  @override
  String get raqeebTextLimit => 'اكتب سؤالك في حدود ٢٠٠٠ حرف.';

  @override
  String get raqeebTextOnly => 'سؤالك المكتوب';

  @override
  String get raqeebTextOnlyPhase => 'يمكنك طرح سؤالك كتابةً هنا. ستتوفر الأسئلة بالصوت والصور والمستندات لاحقًا.';

  @override
  String get raqeebTimeout => 'استغرقت الإجابة وقتًا أطول من المتوقع. يمكنك المحاولة مرة أخرى.';

  @override
  String get raqeebTruncated => 'تمت قراءة جزء من المستند فقط';

  @override
  String get raqeebTryAsking => 'جرّب أن تسأل';

  @override
  String get raqeebUnderstood => 'ما فهمته من رسالتك';

  @override
  String get raqeebWeak => 'ضعيف';

  @override
  String get recitationAgain => 'سجّل مرة أخرى';

  @override
  String get recitationBusy => 'خدمة التحقق من التلاوة مشغولة. أعد المحاولة أو تخطَّ.';

  @override
  String get recitationChecking => 'جارٍ التحقق…';

  @override
  String get recitationContinue => 'تابع بهذه القراءة';

  @override
  String get recitationCorrectWord => 'صحيح';

  @override
  String get recitationDeveloperMissingExtra => 'كلمات ناقصة وزائدة';

  @override
  String get recitationDeveloperOutcome => 'نتيجة تلاوة تجريبية (للتطوير فقط)';

  @override
  String get recitationDeveloperUnclear => 'تسجيل غير واضح';

  @override
  String get recitationExtraWord => 'كلمة زائدة';

  @override
  String get recitationMissingWord => 'ناقص';

  @override
  String get recitationRetry => 'أعد التحقق';

  @override
  String get recitationSubstitutedWord => 'أعد هذه الكلمة';

  @override
  String recitationWordFeedback(String word, String result) {
    return '$word: $result';
  }

  @override
  String get reviewAgain => 'مجددًا';

  @override
  String reviewCardsReady(String countText) {
    return '$countText بطاقات جاهزة';
  }

  @override
  String get reviewEasy => 'سهل';

  @override
  String get reviewGood => 'جيد';

  @override
  String get reviewHard => 'صعب';

  @override
  String get reviewHowWell => 'ما مدى تذكّرك؟';

  @override
  String get reviewIntervals1 => '١ د';

  @override
  String get reviewIntervals2 => 'يوم';

  @override
  String get reviewIntervals3 => '٣ أيام';

  @override
  String get reviewIntervals4 => 'أسبوع';

  @override
  String get reviewReviewDone => 'اكتملت المراجعة';

  @override
  String get reviewReviewDoneBody => 'ستعود إليك قبل أن تنساها بقليل.';

  @override
  String get reviewReviewSubtitle => 'مراجعات قصيرة في وقتها تجعل ما تعلّمته يبقى معك.';

  @override
  String get reviewReviewTiming => 'مرتّبة بحسب قوة تذكّرك لكل واحدة';

  @override
  String get reviewReviewTitle => 'المراجعة';

  @override
  String get reviewStartReview => 'ابدأ مراجعة ٦٠ ثانية';

  @override
  String get reviewTapToFlip => 'اضغط البطاقة لترى الإجابة';

  @override
  String reviewWordsMasteredOf(String mastered, String total) {
    return 'أتقنت $mastered من $total';
  }

  @override
  String get reviewYourWords => 'كلماتك';

  @override
  String get reviewerAbstention => 'الامتناع الصحيح (%)';

  @override
  String get reviewerAccountDescription =>
      'يسجّل المراجعون الدخول بحساباتهم لمراجعة خطط الدروس ومسوداتها، وإجراء المقارنات مجهولة المصدر، والاطلاع على المؤشرات. يعود تقدمك في التعلم على هذا الجهاز عند تسجيل الخروج.';

  @override
  String get reviewerAccuracy => 'الدقة (%)';

  @override
  String get reviewerAccurate => 'أي الدرسين أدق؟';

  @override
  String get reviewerActivated => 'التصورات الخاطئة المكتشفة';

  @override
  String get reviewerAdd => 'إضافة';

  @override
  String get reviewerAfter => 'بعد';

  @override
  String get reviewerAllStatuses => 'كل الحالات';

  @override
  String get reviewerAnswerKey => 'مفتاح الإجابة';

  @override
  String get reviewerApprove => 'اعتماد';

  @override
  String get reviewerArc => 'مسار الدرس';

  @override
  String get reviewerArcMap => 'خريطة المسار';

  @override
  String get reviewerBasis => 'أساس الادّعاء';

  @override
  String get reviewerBefore => 'قبل';

  @override
  String get reviewerBenchmark => 'تقييم رقيب';

  @override
  String get reviewerBlindEmpty => 'لا توجد أزواج متبقية للاختبار الأعمى.';

  @override
  String get reviewerBlindTest => 'اختبار أعمى';

  @override
  String reviewerBlockPosition(int current, int total) {
    return 'الكتلة $current من $total';
  }

  @override
  String get reviewerBlocker => 'مانع';

  @override
  String get reviewerBlockers => 'الاعتماد غير متاح ما دامت الموانع قائمة.';

  @override
  String get reviewerBrief => 'وصف الدرس';

  @override
  String get reviewerClearer => 'أي الدرسين أوضح؟';

  @override
  String get reviewerCommaIds => 'معرّفات مفصولة بفواصل';

  @override
  String get reviewerCompiled => 'مدمج · جاهز';

  @override
  String get reviewerConsole => 'لوحة المراجعة';

  @override
  String get reviewerContentBudget => 'كتل المحتوى';

  @override
  String get reviewerCreate => 'بدء الإنشاء';

  @override
  String get reviewerDepth => 'عمق الدرس';

  @override
  String get reviewerDone => 'مكتمل';

  @override
  String get reviewerEditAr => 'النص العربي البديل';

  @override
  String get reviewerEditEn => 'النص الإنجليزي البديل';

  @override
  String get reviewerEditPlan => 'تعديل الخطة';

  @override
  String get reviewerEditSentence => 'تعديل الجملة';

  @override
  String get reviewerEditsSaved => 'حُفظت التعديلات للاعتماد.';

  @override
  String get reviewerEmail => 'البريد الإلكتروني';

  @override
  String get reviewerEvidence => 'الجمل والأدلة';

  @override
  String get reviewerExerciseBudget => 'تمارين مقيّمة (٢–٦)';

  @override
  String get reviewerExercises => 'التمارين ومفاتيح الإجابة';

  @override
  String get reviewerExperience => 'تجربة المتعلم';

  @override
  String get reviewerFactory => 'مصنع الدروس';

  @override
  String get reviewerGate1 => 'البوابة ١ · مراجعة الخطة';

  @override
  String get reviewerGate2 => 'البوابة ٢ · مراجعة المسودة';

  @override
  String get reviewerGenerationMinutes => 'متوسط الإنشاء (دقائق)';

  @override
  String get reviewerHandwritten => 'أي الدرسين تظن أنه كُتب بواسطة شخص؟';

  @override
  String get reviewerIdentified => 'تمييز الكتابة البشرية (%)';

  @override
  String reviewerIdsPair(String left, String right) {
    return '$left ← $right';
  }

  @override
  String get reviewerInfo => 'معلومة';

  @override
  String get reviewerInteractive => 'يتفاعل المتعلم';

  @override
  String get reviewerIntroduced => 'المفاهيم المقدّمة';

  @override
  String get reviewerInvalidCredentials => 'البريد الإلكتروني أو كلمة المرور غير صحيحة. حاول مجددًا.';

  @override
  String get reviewerInvalidPlan => 'راجع الحقول ثنائية اللغة والأهداف والمفاهيم والمسار والميزانيات قبل الاعتماد.';

  @override
  String get reviewerLearning => 'التعلم';

  @override
  String get reviewerLessonA => 'الدرس أ';

  @override
  String get reviewerLessonB => 'الدرس ب';

  @override
  String get reviewerLessonType => 'نوع الدرس';

  @override
  String get reviewerLockout => 'محاولات كثيرة. انتظر قبل المحاولة مجدداً.';

  @override
  String get reviewerMetrics => 'المؤشرات';

  @override
  String get reviewerMinutes => 'الدقائق المقدّرة';

  @override
  String get reviewerMisconceptions => 'التصورات الخاطئة المستهدفة';

  @override
  String get reviewerMore => 'تحميل المزيد';

  @override
  String get reviewerNewRun => 'إنشاء جديد';

  @override
  String get reviewerNoIssues => 'لا توجد ملاحظات جودة.';

  @override
  String get reviewerNoKey => 'تقييم ذاتي أو تلاوة مفحوصة؛ لا يوجد مفتاح مخزّن.';

  @override
  String get reviewerNoMetrics => 'لا تتوفر قياسات.';

  @override
  String get reviewerNoRuns => 'لا توجد عمليات تطابق هذا المرشح.';

  @override
  String get reviewerNotMeasured => 'لم يُقَس بعد';

  @override
  String get reviewerNotSupporting => 'لا يدعم هذا الادّعاء';

  @override
  String get reviewerNote => 'ملاحظة المراجع';

  @override
  String get reviewerObjectives => 'الأهداف (١–٣)';

  @override
  String get reviewerOpenRun => 'فتح العملية';

  @override
  String get reviewerOutcome => 'الناتج التعلمي الرئيسي';

  @override
  String get reviewerPairedEnglish => 'يتطلب تعديل العربية تعديل الإنجليزية للجملة والمسار نفسيهما.';

  @override
  String get reviewerParticipants => 'المشاركون';

  @override
  String reviewerParticipantsValue(String value) {
    return 'المشاركون: $value';
  }

  @override
  String get reviewerPassword => 'كلمة المرور';

  @override
  String get reviewerPending => 'قيد الانتظار';

  @override
  String reviewerPercentValue(String label, String value) {
    return '$label · $value٪';
  }

  @override
  String reviewerPercentageNumber(String value) {
    return '$value٪';
  }

  @override
  String get reviewerPlaceholder => 'عنصر نائب / يحتاج مراجعة';

  @override
  String get reviewerPlan => 'خطة الدرس';

  @override
  String get reviewerPosition => 'موضع الدرس في الوحدة (بدءاً من ٠)';

  @override
  String get reviewerPrePost => 'التقييم القبلي / البعدي';

  @override
  String get reviewerPreferred => 'تفضيل المنشأ آلياً أو مساواته (%)';

  @override
  String get reviewerPrerequisites => 'المفاهيم المطلوبة مسبقاً';

  @override
  String get reviewerPreview => 'معاينة المتعلم';

  @override
  String get reviewerPreviewEmpty => 'لا تتوفر كتل للمعاينة.';

  @override
  String get reviewerPublished => 'الدروس المنشورة';

  @override
  String get reviewerQA => 'تقرير الجودة';

  @override
  String get reviewerQuestion => 'سؤال المتعلم المركزي';

  @override
  String get reviewerRationale => 'المبرر';

  @override
  String get reviewerReasonRequired => 'أضف ملاحظة توضّح التعديلات المطلوبة.';

  @override
  String get reviewerReasoning => 'أدوات الاستدلال ومبرراتها';

  @override
  String get reviewerReconfirm => 'راجعت أحدث نسخة';

  @override
  String get reviewerReferral => 'الإحالة الصحيحة (%)';

  @override
  String get reviewerRegenerate => 'إعادة إنشاء الصورة';

  @override
  String get reviewerRegenerationAccepted => 'قُبل طلب إعادة الإنشاء. يبقى العنصر النائب حتى يتوفر أصل مُدقّق.';

  @override
  String get reviewerReject => 'رفض';

  @override
  String get reviewerRemove => 'إزالة';

  @override
  String get reviewerRemoveExercise => 'إزالة عند الاعتماد';

  @override
  String get reviewerRequestChanges => 'طلب تعديلات';

  @override
  String get reviewerResolutionRate => 'نسبة المعالجة (%)';

  @override
  String get reviewerResolved => 'التصورات الخاطئة المعالجة';

  @override
  String get reviewerResponses => 'إجابات الاختبار الأعمى';

  @override
  String get reviewerReveal => 'متابعة المعاينة';

  @override
  String get reviewerReviewMinutes => 'متوسط المراجعة (دقائق)';

  @override
  String get reviewerRole => 'دور الجملة';

  @override
  String get reviewerRuns => 'عمليات الإنشاء';

  @override
  String get reviewerSame => 'متساويان';

  @override
  String get reviewerSampleDescription =>
      'راجع خطط الدروس ومسوداتها، وقارن الدروس في اختبار مجهول المصدر، واستكشف مؤشرات توضيحية. تستخدم هذه المعاينة محتوى تجريبياً، ويُحفظ تقدمك في التعلم عند العودة.';

  @override
  String get reviewerSampleOpen => 'استكشف لوحة المراجع';

  @override
  String get reviewerSaveEdits => 'حفظ التعديلات المزدوجة';

  @override
  String get reviewerSavePlan => 'حفظ الخطة';

  @override
  String get reviewerSelectRun => 'اختر عملية لمراجعة خطتها أو مسودتها.';

  @override
  String get reviewerSignIn => 'تسجيل دخول المراجع';

  @override
  String get reviewerSignOut => 'تسجيل الخروج';

  @override
  String get reviewerSkipped => 'تم تجاوزه';

  @override
  String get reviewerStage => 'المرحلة';

  @override
  String get reviewerStale => 'تغيّرت المراجعة. تم تحميل أحدث نسخة. راجعها مجدداً قبل إرسال القرار.';

  @override
  String get reviewerStandalone => 'مؤهل للاستكشاف';

  @override
  String reviewerStatusStage(String status, String stage) {
    return '$status · $stage';
  }

  @override
  String get reviewerSubmit => 'إرسال المراجعة';

  @override
  String get reviewerSupports => 'دليل داعم';

  @override
  String get reviewerTargets =>
      'إرشاد: ٦–١٠ دقائق؛ الدروس التأسيسية نحو ٨–١٠. عادةً ٣–٥ تمارين (القصة: ٢–٤). الأولوية للاكتمال؛ لا يُطوّل الدرس ولا يُقسّم بسبب المدة وحدها.';

  @override
  String get reviewerTerms => 'المصطلحات الجديدة';

  @override
  String get reviewerTitle => 'العنوان';

  @override
  String get reviewerUnderstandings => 'الفهم الداعم';

  @override
  String get reviewerUnitId => 'معرّف الوحدة';

  @override
  String get reviewerUnitsCompleted => 'الوحدات المكتملة';

  @override
  String get reviewerUnitsStarted => 'الوحدات المبدوءة';

  @override
  String get reviewerUnsupported => 'الادّعاءات غير المدعومة (%)';

  @override
  String get reviewerUnsure => 'غير متأكد';

  @override
  String get reviewerValidation => 'ملاحظات التحقق';

  @override
  String get reviewerValueAddresseeSpecific => 'خاص بالمخاطب';

  @override
  String get reviewerValueAwaitingGate1 => 'بانتظار البوابة ١';

  @override
  String get reviewerValueAwaitingGate2 => 'بانتظار البوابة ٢';

  @override
  String get reviewerValueBaselineLlm => 'النموذج المرجعي';

  @override
  String get reviewerValueBeliefGrading => 'تقييم المعتقد';

  @override
  String get reviewerValueBeyondSource => 'يتجاوز المصدر';

  @override
  String get reviewerValueCausalReasoning => 'استدلال سببي';

  @override
  String get reviewerValueCircularReasoning => 'استدلال دائري';

  @override
  String get reviewerValueClaim => 'ادّعاء';

  @override
  String get reviewerValueComparison => 'مقارنة';

  @override
  String get reviewerValueConcept => 'مفهوم';

  @override
  String get reviewerValueConsistency => 'الاتساق';

  @override
  String get reviewerValueContextDependent => 'يعتمد على السياق';

  @override
  String get reviewerValueDecompose => 'تفكيك المحتوى';

  @override
  String get reviewerValueDemonstration => 'عرض عملي';

  @override
  String get reviewerValueDifferingOpinions => 'اختلاف الآراء';

  @override
  String get reviewerValueDone => 'مكتمل';

  @override
  String get reviewerValueDoubtOrDeepCreed => 'شك أو اعتقاد عميق';

  @override
  String get reviewerValueDropped => 'محذوف';

  @override
  String get reviewerValueEvidence => 'دليل';

  @override
  String get reviewerValueExact => 'مطابقة تامة';

  @override
  String get reviewerValueExample => 'مثال';

  @override
  String get reviewerValueExercises => 'التمارين';

  @override
  String get reviewerValueExplanation => 'شرح';

  @override
  String get reviewerValueExplorer => 'المستكشف';

  @override
  String get reviewerValueFailed => 'فشل';

  @override
  String get reviewerValueFatwaLike => 'شبيه بالفتوى';

  @override
  String get reviewerValueFocused => 'محدّد';

  @override
  String get reviewerValueFoundational => 'تأسيسي';

  @override
  String get reviewerValueFraming => 'تمهيد';

  @override
  String get reviewerValueGeneralKnowledge => 'معرفة عامة';

  @override
  String get reviewerValueGeneralisedFromSpecific => 'تعميم من حالة خاصة';

  @override
  String get reviewerValueHistoricalEvidence => 'دليل تاريخي';

  @override
  String get reviewerValueHypothetical => 'افتراضي';

  @override
  String get reviewerValueImagePolicy => 'سياسة الصور';

  @override
  String get reviewerValueInference => 'استنتاج';

  @override
  String get reviewerValueInstruction => 'تعليمات';

  @override
  String get reviewerValueLocalization => 'التوطين';

  @override
  String get reviewerValueLocalize => 'التوطين';

  @override
  String get reviewerValueNeedsTafsir => 'يحتاج تفسيراً';

  @override
  String get reviewerValueNewMuslim => 'المسلم الجديد';

  @override
  String get reviewerValueObservation => 'ملاحظة';

  @override
  String get reviewerValueOutOfScope => 'خارج النطاق';

  @override
  String get reviewerValueOversimplified => 'تبسيط مخلّ';

  @override
  String get reviewerValuePartial => 'مطابقة جزئية';

  @override
  String get reviewerValuePedagogy => 'التربية';

  @override
  String get reviewerValuePending => 'قيد الانتظار';

  @override
  String get reviewerValuePersonalFatwa => 'فتوى شخصية';

  @override
  String get reviewerValuePlan => 'الخطة';

  @override
  String get reviewerValuePractice => 'تطبيق';

  @override
  String get reviewerValuePrediction => 'توقع';

  @override
  String get reviewerValuePublish => 'النشر';

  @override
  String get reviewerValuePublished => 'منشور';

  @override
  String get reviewerValueQa => 'ضمان الجودة';

  @override
  String get reviewerValueQuestion => 'سؤال';

  @override
  String get reviewerValueRaqeeb => 'رقيب';

  @override
  String get reviewerValueReadingLevel => 'مستوى القراءة';

  @override
  String get reviewerValueReasoning => 'استدلال';

  @override
  String get reviewerValueReflection => 'تأمل';

  @override
  String get reviewerValueRejected => 'مرفوض';

  @override
  String get reviewerValueRetrieve => 'جلب المصادر';

  @override
  String get reviewerValueRunning => 'قيد التنفيذ';

  @override
  String get reviewerValueScenario => 'موقف';

  @override
  String get reviewerValueSceneAuthor => 'تأليف المشهد';

  @override
  String get reviewerValueSceneRender => 'رسم المشهد';

  @override
  String get reviewerValueScholarlyDisagreement => 'خلاف علمي';

  @override
  String get reviewerValueScholarlyReview => 'مراجعة علمية';

  @override
  String get reviewerValueSensitive => 'حساس';

  @override
  String get reviewerValueSensitiveHuman => 'سؤال شخصي حساس';

  @override
  String get reviewerValueSingleOpinionAsConsensus => 'رأي واحد يُعرض إجماعاً';

  @override
  String get reviewerValueSkipped => 'تم تجاوزه';

  @override
  String get reviewerValueSource => 'مصدر';

  @override
  String get reviewerValueStandard => 'قياسي';

  @override
  String get reviewerValueStory => 'قصة';

  @override
  String get reviewerValueStretched => 'تحميل زائد';

  @override
  String get reviewerValueSupported => 'مدعوم';

  @override
  String get reviewerValueTakeaway => 'خلاصة';

  @override
  String get reviewerValueTestimony => 'شهادة';

  @override
  String get reviewerValueTextExplanation => 'شرح النص';

  @override
  String get reviewerValueTranslationSensitive => 'حساس للترجمة';

  @override
  String get reviewerValueUnknown => 'غير معروف';

  @override
  String get reviewerValueUnrelated => 'غير ذي صلة';

  @override
  String get reviewerValueUnsupportedSentence => 'جملة غير مدعومة';

  @override
  String get reviewerValueValidation => 'التحقق';

  @override
  String get reviewerValueVerification => 'توثيق';

  @override
  String get reviewerValueVerify => 'التحقق';

  @override
  String get reviewerValueVisuals => 'المرئيات';

  @override
  String get reviewerValueWrite => 'الكتابة';

  @override
  String get reviewerVisuals => 'المرئيات';

  @override
  String get reviewerWarning => 'تنبيه';

  @override
  String get sessionAllCaughtUp => 'أكملت كل المراجعات';

  @override
  String get sessionAnswerReview => 'إجاباتك';

  @override
  String get sessionApplying => 'التطبيق';

  @override
  String get sessionBackToJourney => 'العودة إلى رحلتي';

  @override
  String get sessionBegin => 'لنبدأ';

  @override
  String sessionBlank(String number) {
    return 'الفراغ $number';
  }

  @override
  String get sessionChooseReason => 'اختر السبب';

  @override
  String sessionCombo(String count) {
    return '$count إجابات متتالية';
  }

  @override
  String get sessionComesBack => 'سيعود إليك في المراجعة';

  @override
  String get sessionCompanionIntro => 'سأمشي معك. اضغط على أي كلمة مسطّرة إن كانت جديدة عليك.';

  @override
  String get sessionCorrectAnswerIs => 'الإجابة الصحيحة:';

  @override
  String get sessionExercisePlaceholderBody => 'ستصبح التمارين تفاعلية في المرحلة التالية. تابع لمعاينة محتوى الدرس.';

  @override
  String get sessionExercisePlaceholderTitle => 'معاينة التمرين';

  @override
  String sessionExercisesCount(String countText) {
    return '$countText أنشطة';
  }

  @override
  String get sessionFalseLabel => 'خطأ';

  @override
  String get sessionFillBlank => 'أكمل الفراغات';

  @override
  String get sessionFindOut => 'لنكتشف';

  @override
  String get sessionGentle1 => 'ليس تمامًا — ولا بأس';

  @override
  String get sessionGentle2 => 'اقتربت كثيرًا';

  @override
  String get sessionGentle3 => 'محاولة جيدة';

  @override
  String get sessionIllTry => 'سأجرّب';

  @override
  String get sessionInTwoDays => 'بعد يومين';

  @override
  String get sessionKeepLearning => 'أكمل التعلّم';

  @override
  String get sessionKindChoose => 'اختيار';

  @override
  String get sessionKindDay => 'يومك';

  @override
  String get sessionKindDiscover => 'اكتشف';

  @override
  String get sessionKindFix => 'صحّح الفكرة';

  @override
  String get sessionKindGuess => 'توقّعك';

  @override
  String get sessionKindMatch => 'طابق';

  @override
  String get sessionKindOrder => 'رتّب';

  @override
  String get sessionKindRealLife => 'موقف حقيقي';

  @override
  String get sessionKindRecite => 'تلاوة';

  @override
  String get sessionKindSort => 'صنّف';

  @override
  String get sessionKindTrueFalse => 'صح أم خطأ';

  @override
  String get sessionLeave => 'غادر';

  @override
  String get sessionLessonComplete => 'أتممت الدرس!';

  @override
  String get sessionLessonCompleteSub => 'خطوة جديدة في طريقك، بهدوء وإتقان.';

  @override
  String sessionLessonPosition(String unit, String lesson) {
    return 'الوحدة $unit · الدرس $lesson';
  }

  @override
  String get sessionListenReciter => 'استمع إلى القارئ';

  @override
  String get sessionListening => 'أستمع إليك…';

  @override
  String sessionMapPin(String number) {
    return 'الموضع $number';
  }

  @override
  String get sessionMasteryNote => 'التقدم في قبس مبني على الإتقان لا على إنهاء الدروس. التذكّر يُقاس في جلسات المراجعة.';

  @override
  String get sessionMeaning => 'المعنى';

  @override
  String get sessionMistakenIdea => 'فكرة شائعة خاطئة';

  @override
  String sessionNextOnPath(String title) {
    return 'التالي في رحلتك: $title';
  }

  @override
  String sessionNextUnlocked(String title) {
    return 'التالي في طريقك: $title';
  }

  @override
  String get sessionNiceThinking => 'فكرة جميلة!';

  @override
  String get sessionOriginTitle => 'من أين جاءت هذه القصة؟';

  @override
  String get sessionPairHint => 'اضغط على كلمة ثم معناها. اضغط على الزوج لتغييره.';

  @override
  String get sessionPerfectBonus => 'مكافأة الدرس المتقن';

  @override
  String get sessionPlaying => 'يُتلى الآن…';

  @override
  String get sessionPraise1 => 'أحسنت!';

  @override
  String get sessionPraise2 => 'إجابة صحيحة';

  @override
  String get sessionPraise3 => 'رائع!';

  @override
  String get sessionPraise4 => 'تمامًا!';

  @override
  String get sessionPraise5 => 'بالضبط';

  @override
  String get sessionPretestThanks => 'شكرًا لمشاركتك ما تعرفه';

  @override
  String get sessionPreviewEndBody => 'وصلت إلى نهاية معاينة المحتوى. التمارين وإكمال الدرس سيأتيان في المراحل التالية.';

  @override
  String get sessionPreviewEndTitle => 'اكتملت معاينة المحتوى';

  @override
  String sessionProgress(String percent) {
    return 'اكتمل $percent٪';
  }

  @override
  String get sessionQuickReview => 'مراجعة سريعة';

  @override
  String get sessionQuitBody => 'لن يُحفظ تقدمك في هذا الدرس. يمكنك العودة في أي وقت.';

  @override
  String get sessionQuitTitle => 'تغادر الدرس؟';

  @override
  String get sessionReadLesson => 'اقرأ الدرس';

  @override
  String get sessionReaderEmpty => 'لا يوجد محتوى للقراءة في هذا الدرس بعد.';

  @override
  String get sessionReciteBody => 'الآية التي تخبرنا أن للصلاة أوقاتًا محددة.';

  @override
  String get sessionReciteGreat => 'قراءة جميلة';

  @override
  String get sessionReciteTip => 'ملاحظة لطيفة: أدغم تنوين «كتابًا» في ميم «موقوتا» مع غنّة خفيفة.';

  @override
  String get sessionReciteTitle => 'استمع، ثم اقرأ بصوتك';

  @override
  String get sessionRecordingUnavailable => 'التسجيل غير متاح بعد';

  @override
  String get sessionRemediation => 'لنوضّح هذه الفكرة';

  @override
  String get sessionRemembering => 'التذكّر';

  @override
  String get sessionReport => 'إبلاغ';

  @override
  String get sessionResultPendingBody => 'شاشة الاحتفال ستتوفر قريبًا. يمكنك العودة إلى رحلتك.';

  @override
  String get sessionResultPendingTitle => 'حُفظت جلستك';

  @override
  String get sessionRetryBody => 'لنراجع الأفكار التي ما زلت تتدرّب عليها.';

  @override
  String get sessionRetryTitle => 'فرصة للمحاولة مرة أخرى';

  @override
  String get sessionReviewedBySpecialist => 'يراجعه مختص في العلوم الشرعية';

  @override
  String get sessionSalahPreview => 'معاينة درس الصلاة';

  @override
  String sessionSecondsRemaining(String seconds) {
    return 'متبقي $seconds ثانية';
  }

  @override
  String get sessionSelectAnswer => 'اختر إجابة';

  @override
  String get sessionShowAll => 'اعرض الكل';

  @override
  String get sessionShowMore => 'الفكرة التالية';

  @override
  String get sessionSimulatedNote => 'نموذج أولي: الصوت وتقييم القراءة محاكاة.';

  @override
  String get sessionSituation => 'موقف';

  @override
  String get sessionSkipRecite => 'لا أستطيع التحدث الآن';

  @override
  String get sessionSkipped => 'تم التخطي';

  @override
  String get sessionSoon => 'في المراجعة';

  @override
  String sessionSourcesLine(String countText) {
    return '$countText مصادر موثّقة';
  }

  @override
  String get sessionSourcesTitle => 'مصادر هذا الدرس';

  @override
  String get sessionSpotError => 'حدّد الجزء غير الصحيح';

  @override
  String get sessionStatAccuracy => 'الدقة';

  @override
  String get sessionStatEmbers => 'قبسات';

  @override
  String get sessionStatTime => 'الوقت';

  @override
  String get sessionSubmitError => 'احتُفظ بإجابتك. حاول مرة أخرى.';

  @override
  String get sessionTapInOrder => 'اضغط عليها بالترتيب.';

  @override
  String get sessionTapTheScene => 'اضغط على المكان الصحيح في الصورة.';

  @override
  String get sessionTapThenPlace => 'اختر عبارة، ثم المجموعة التي تنتمي إليها.';

  @override
  String get sessionTapThenSlot => 'اختر صلاة، ثم موضعها من اليوم.';

  @override
  String get sessionTapToContinue => 'اضغط للمتابعة';

  @override
  String get sessionTestPassed => 'اجتزت اختبار الوحدة';

  @override
  String get sessionTestTryAgain => 'واصل بناء فهمك';

  @override
  String get sessionTheStory => 'القصة';

  @override
  String get sessionThenAWeek => 'ثم بعد أسبوع';

  @override
  String get sessionThinkFirst => 'فكّر لحظة، لا توجد إجابة خاطئة هنا.';

  @override
  String get sessionTodaysChallenge => 'تحدٍّ صغير لليوم';

  @override
  String get sessionTomorrowWeAsk => 'غدًا سنسألك';

  @override
  String get sessionTransliteration => 'النقل الصوتي';

  @override
  String get sessionTrueLabel => 'صحيح';

  @override
  String get sessionUnderstanding => 'الفهم';

  @override
  String get sessionUnit0ContentPreview => 'معاينة محتوى الوحدة ٠';

  @override
  String get sessionUpdateRequired => 'حدّث التطبيق للمتابعة';

  @override
  String sessionVerseReference(String surah, String ayah) {
    return 'السورة $surah · الآية $ayah';
  }

  @override
  String get sessionWhichEvidence => 'اختر الدليل';

  @override
  String get sessionWhyLabel => 'لماذا';

  @override
  String get sessionYouWillLearn => 'ستتعلم';

  @override
  String get sessionYourAnswer => 'إجابتك';

  @override
  String get sessionYourMastery => 'إتقانك';

  @override
  String get sessionYourTurn => 'دورك — اضغط واقرأ بصوتك';

  @override
  String get settingsAboutQabas => 'عن قبس';

  @override
  String get settingsArabic => 'العربية';

  @override
  String get settingsCharacters => 'الشخصيات';

  @override
  String get settingsContentNote => 'عن هذا المحتوى';

  @override
  String get settingsContentNoteBody => 'يستند محتوى قبس إلى مصادر موثوقة، وينتظر مراجعة مختص في الدراسات الإسلامية قبل النشر.';

  @override
  String get settingsDailyGoalSetting => 'الهدف اليومي';

  @override
  String get settingsDeleteAccount => 'حذف الحساب';

  @override
  String get settingsDeleteAccountBody => 'هل تريد حذف حسابك وتقدمك في التعلم؟ لا يمكن التراجع عن ذلك. ستُحذف بياناتك خلال ٣٠ يومًا.';

  @override
  String get settingsDemoReset => 'أعيد تعيين تقدم العرض';

  @override
  String get settingsDiscreetReminders => 'تذكيرات متحفّظة';

  @override
  String get settingsEnglish => 'English';

  @override
  String get settingsHapticsLabel => 'الاهتزاز';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLearnerPath => 'مسار التعلّم';

  @override
  String get settingsPrivateProfileSetting => 'ملف شخصي خاص';

  @override
  String get settingsReduceMotion => 'تقليل الحركة';

  @override
  String get settingsReduceMotionBody => 'شاشات أهدأ، بلا قفز أو جزيئات';

  @override
  String get settingsReminders => 'وقت التذكير';

  @override
  String get settingsReplayOnboarding => 'إعادة الترحيب';

  @override
  String get settingsResetDemo => 'إعادة تعيين تقدم العرض';

  @override
  String get settingsResetDemoBody => 'العودة إلى ٣ أيام متتالية ودرس الصلاة بانتظارك';

  @override
  String get settingsSaveFailed => 'لم نتمكن من حفظ التغيير. حاول مرة أخرى.';

  @override
  String get settingsSectionAbout => 'عن قبس';

  @override
  String get settingsSectionAccount => 'أنت';

  @override
  String get settingsSectionDemo => 'النموذج الأولي';

  @override
  String get settingsSectionExperience => 'التجربة';

  @override
  String get settingsSectionLearning => 'التعلّم';

  @override
  String get settingsSectionPrivacy => 'الخصوصية';

  @override
  String get settingsSoundEffects => 'المؤثرات الصوتية';

  @override
  String get streakDayStreakLabel => 'أيام متتالية';

  @override
  String get streakKeepFlameWarm => 'تعلّم قليلًا اليوم لتبقى شعلتك دافئة.';

  @override
  String get streakLastFiveWeeks => 'أسابيعك الخمسة الأخيرة';

  @override
  String get streakRestDays => 'أيام الراحة';

  @override
  String get streakRestDaysBody => 'الحياة لها ظروفها. يوم راحة في الأسبوع يحفظ شعلتك دافئة، بلا لوم ولا ضياع للتقدم.';

  @override
  String get streakStreakBody => 'أوقدت شعلة اليوم. قليلٌ من النور كل يوم يصنع طريقًا.';

  @override
  String get streakStreakKeep => 'حافظ على الشعلة';

  @override
  String streakStreakTitle(num count, String countText) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countText يومًا متتالية!',
      few: '$countText أيام متتالية!',
      two: '$countText يومان متتالية!',
      one: '$countText يوم متتالية!',
      zero: '$countText أيام متتالية!',
    );
    return '$_temp0';
  }

  @override
  String get streakToday => 'اليوم';

  @override
  String get unitGuideEmpty => 'لا يوجد محتوى في الدليل بعد.';
}
