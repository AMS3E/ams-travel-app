import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/locale_provider.dart';
import '../utils/geo.dart';

/// UI copy in English and Khmer, matching the website's EN / ខ្មែរ toggle.
///
/// The text lives in `lib/l10n/en.json` and `lib/l10n/km.json`, one key per
/// string; edit those files to change or translate copy. To add a string, put
/// the key in both files and add a getter below.
///
/// Usage: `final s = S.of(context); Text(s.startExploring)`.
/// Content (place names, descriptions) comes from the API; only app chrome
/// lives here.
class S {
  S._(this._strings);

  final Map<String, String> _strings;

  static late S en;
  static late S km;

  /// Reads both language files; call once in `main` before `runApp`.
  static Future<void> load() async {
    final (enStrings, kmStrings) = await (_readFile('en'), _readFile('km')).wait;
    en = S._(enStrings);
    km = S._(kmStrings);
  }

  static Future<Map<String, String>> _readFile(String lang) async {
    final json = await rootBundle.loadString('lib/l10n/$lang.json');
    return Map<String, String>.from(jsonDecode(json) as Map);
  }

  static S of(BuildContext context) => context.watch<LocaleProvider>().isKhmer ? km : en;

  /// For callbacks where `watch` is not allowed.
  static S read(BuildContext context) => context.read<LocaleProvider>().isKhmer ? km : en;

  /// Falls back to English, then to the key, so a missing translation shows
  /// something instead of crashing.
  String _t(String key) => _strings[key] ?? en._strings[key] ?? key;

  /// A text with `{name}` slots filled in: `s.fill(s.durationDays, {'n': 3})`.
  String fill(String text, Map<String, Object> values) =>
      values.entries.fold(text, (t, e) => t.replaceAll('{${e.key}}', '${e.value}'));

  /// An interest group's name in the app's language. The API names groups
  /// in English only (R-075); a group the app does not know keeps that name.
  String interestGroup(String name) => switch (name) {
    'Attraction Sites' => _t('groupAttractionSites'),
    'Stays' => _t('groupStays'),
    'Food' => _t('groupFood'),
    'Water' => _t('groupWater'),
    'Activities & Experiences' => _t('groupActivities'),
    'Tourism Corridors' => _t('groupCorridors'),
    _ => name,
  };

  /// "1 place", "4 places".
  String placeCountText(int n) => n == 1 ? placeCountOne : fill(placeCountMany, {'n': n});

  /// "1 review", "128 reviews".
  String reviewCountText(int n) => n == 1 ? reviewCountOne : fill(reviewsCountLabel, {'n': thousands(n)});

  /// "1 badge", "3 badges".
  String badgeCountText(int n) => n == 1 ? badgeCountOne : fill(badgeCountMany, {'n': n});

  /// "1 day", "3 days".
  String daysCount(int n) => n == 1 ? durationOneDay : fill(durationDays, {'n': n});

  String get placeCountOne => _t('placeCountOne');
  String get placeCountMany => _t('placeCountMany');
  String get durationOneDay => _t('durationOneDay');
  String get navExplore => _t('navExplore');
  String get navMap => _t('navMap');
  String get navSaved => _t('navSaved');
  String get navProfile => _t('navProfile');
  String get whatTravelersSay => _t('whatTravelersSay');
  String get showMore => _t('showMore');
  String get showAllReviews => _t('showAllReviews');
  String get reviewsWord => _t('reviewsWord');
  String get yourRate => _t('yourRate');
  String get kindOfVisit => _t('kindOfVisit');
  String get overview => _t('overview');
  String get readMore => _t('readMore');
  String get regionMap => _t('regionMap');
  String get regionMapSubtitle => _t('regionMapSubtitle');
  String get discoverDestination => _t('discoverDestination');
  String get tags => _t('tags');
  String get popularKeywords => _t('popularKeywords');
  String get viewAll => _t('viewAll');
  String get reset => _t('reset');
  String get applyFilters => _t('applyFilters');
  String get tourismRegions => _t('tourismRegions');
  String get exploreNearby => _t('exploreNearby');
  String get allowLocationAccess => _t('allowLocationAccess');
  String get recommendCorridors => _t('recommendCorridors');
  String get yourLocation => _t('yourLocation');
  String get searchEverythingHint => _t('searchEverythingHint');
  String get exploreByRegion => _t('exploreByRegion');
  String get exploreByPopular => _t('exploreByPopular');
  String get exploreByCorridors => _t('exploreByCorridors');
  String get exploreByProvinces => _t('exploreByProvinces');
  String get recommendByAms => _t('recommendByAms');
  String get recommendByTraveler => _t('recommendByTraveler');

  /// A place's seal: the travellers' if they gave it, else AMS's.
  String? seal({required bool traveler, required bool verified}) =>
      traveler ? recommendByTraveler : (verified ? recommendByAms : null);
  String get notifications => _t('notifications');
  String get unreadWord => _t('unreadWord');
  String get today => _t('today');
  String get yesterday => _t('yesterday');
  String get thisWeek => _t('thisWeek');
  String get earlier => _t('earlier');
  String get agoWord => _t('agoWord');
  String get noNotifications => _t('noNotifications');
  String get registerCta => _t('registerCta');
  String get startJourney => _t('startJourney');
  String get exploreAsGuest => _t('exploreAsGuest');
  String get welcomeEyebrow1 => _t('welcomeEyebrow1');
  String get welcomeTitleA1 => _t('welcomeTitleA1');
  String get welcomeTitleB1 => _t('welcomeTitleB1');
  String get welcomeBody1 => _t('welcomeBody1');
  String get welcomeEyebrow2 => _t('welcomeEyebrow2');
  String get welcomeTitleA2 => _t('welcomeTitleA2');
  String get welcomeTitleB2 => _t('welcomeTitleB2');
  String get welcomeBody2 => _t('welcomeBody2');
  String get welcomeEyebrow3 => _t('welcomeEyebrow3');
  String get welcomeTitleA3 => _t('welcomeTitleA3');
  String get welcomeTitleB3 => _t('welcomeTitleB3');
  String get welcomeBody3 => _t('welcomeBody3');
  String get welcomeEyebrow4 => _t('welcomeEyebrow4');
  String get welcomeTitleA4 => _t('welcomeTitleA4');
  String get welcomeTitleB4 => _t('welcomeTitleB4');
  String get welcomeBody4 => _t('welcomeBody4');
  String get saves => _t('saves');
  String get footerVersion => _t('footerVersion');
  String get openNow => _t('openNow');
  String get closedNow => _t('closedNow');
  String get verified => _t('verified');
  String get tabRegions => _t('tabRegions');
  String get tabInterests => _t('tabInterests');
  String get tabProvinces => _t('tabProvinces');
  String get tabCorridors => _t('tabCorridors');
  String get destinations => _t('destinations');
  String get categories => _t('categories');
  String get provinces => _t('provinces');
  String get regions => _t('regions');
  String get filters => _t('filters');
  String get province => _t('province');
  String get map => _t('map');
  String get all => _t('all');
  String get noResults => _t('noResults');
  String get noResultsBody => _t('noResultsBody');
  String get region => _t('region');
  String get seeOnFullMap => _t('seeOnFullMap');
  String get reviews => _t('reviews');
  String get noReviews => _t('noReviews');
  String get beFirst => _t('beFirst');
  String get writeReview => _t('writeReview');
  String get editReview => _t('editReview');
  String get logInToReview => _t('logInToReview');
  String get facilities => _t('facilities');
  String get share => _t('share');
  String get save => _t('save');
  String get savedToList => _t('savedToList');
  String get removedFromList => _t('removedFromList');
  String get onTheMap => _t('onTheMap');
  String get pinnedIn => _t('pinnedIn');
  String get photos => _t('photos');
  String get stops => _t('stops');
  String get searchMap => _t('searchMap');
  String get notificationsNote => _t('notificationsNote');
  String get currency => _t('currency');
  String get unit => _t('unit');
  String get notification => _t('notification');
  String get onWord => _t('onWord');
  String get offWord => _t('offWord');
  String get accountSaved => _t('accountSaved');
  String get delete => _t('delete');
  String get emptyFolder => _t('emptyFolder');
  String get mostRecent => _t('mostRecent');
  String get oldest => _t('oldest');
  String get highestRated => _t('highestRated');
  String get lowestRated => _t('lowestRated');
  String get reviewsWritten => _t('reviewsWritten');
  String get averageRating => _t('averageRating');
  String get sortBy => _t('sortBy');
  String get noReviewsBody => _t('noReviewsBody');
  String get achievement => _t('achievement');
  String get badgeEarned => _t('badgeEarned');
  String get badgeInProgress => _t('badgeInProgress');
  String get earnedOn => _t('earnedOn');
  String get viewTerms => _t('viewTerms');
  String get viewBadgeHistory => _t('viewBadgeHistory');
  String get notYet => _t('notYet');
  String get digitalStamps => _t('digitalStamps');
  String get browseShort => _t('browseShort');
  String get badges => _t('badges');
  String get progressLabel => _t('progressLabel');
  String get requiredWord => _t('requiredWord');
  String get completeFirst => _t('completeFirst');
  String get badgeCategories => _t('badgeCategories');
  String get badgeHistory => _t('badgeHistory');
  String get currentStatus => _t('currentStatus');
  String get browserBadge => _t('browserBadge');
  String get reviewerBadge => _t('reviewerBadge');
  String get adventureBadge => _t('adventureBadge');
  String get silverTier => _t('silverTier');
  String get goldTier => _t('goldTier');
  String get platinumTier => _t('platinumTier');
  String get topTierReached => _t('topTierReached');
  String get accountInfo => _t('accountInfo');
  String get preference => _t('preference');
  String get gallery => _t('gallery');
  String get routeOverview => _t('routeOverview');
  String get startThisTrip => _t('startThisTrip');
  String get corridorsMap => _t('corridorsMap');
  String get exploreThrough => _t('exploreThrough');
  String get exploreRegions => _t('exploreRegions');
  String get popularDestinations => _t('popularDestinations');
  String get exploreMoreIn => _t('exploreMoreIn');
  String get searchProvince => _t('searchProvince');
  String get showAllProvinces => _t('showAllProvinces');
  String get exploreInterest => _t('exploreInterest');
  String get helpSupport => _t('helpSupport');
  String get helpIntro => _t('helpIntro');
  String get socialLinkLater => _t('socialLinkLater');
  String get termsConditions => _t('termsConditions');
  String get yourBadge => _t('yourBadge');
  String get joined => _t('joined');
  String get name => _t('name');
  String get reviewTitle => _t('reviewTitle');
  String get rateYourExperience => _t('rateYourExperience');
  String get whenDidYouVisit => _t('whenDidYouVisit');
  String get reviewTitleLabel => _t('reviewTitleLabel');
  String get reviewTitleHint => _t('reviewTitleHint');
  String get yourReview => _t('yourReview');
  String get yourReviewHint => _t('yourReviewHint');
  String get photoOfYourVisit => _t('photoOfYourVisit');
  String get addPhotos => _t('addPhotos');
  String get submitReview => _t('submitReview');
  String get reviewSaved => _t('reviewSaved');
  String get max => _t('max');
  String get min => _t('min');
  String get characters => _t('characters');
  String get words => _t('words');
  String get showRoute => _t('showRoute');
  String get howToGetThere => _t('howToGetThere');
  String get recommendNearby => _t('recommendNearby');
  String get maxAdults => _t('maxAdults');
  String get adultsWord => _t('adultsWord');
  String get breakfastIncluded => _t('breakfastIncluded');
  String get featuredAmenities => _t('featuredAmenities');
  String get roomDetails => _t('roomDetails');
  String get rooms => _t('rooms');
  String get noRooms => _t('noRooms');
  String get noRoomsBody => _t('noRoomsBody');
  String get stayPolicies => _t('stayPolicies');
  String get viewRooms => _t('viewRooms');
  String get fromTime => _t('fromTime');
  String get beforeTime => _t('beforeTime');
  String get perNightSuffix => _t('perNightSuffix');

  /// A hotel's class: "5 star".
  String hotelStarsText(int n) => fill(_t('hotelStars'), {'n': n});
  String get checkIn => _t('checkIn');
  String get checkOut => _t('checkOut');
  String get description => _t('description');
  String get showLess => _t('showLess');
  String get website => _t('website');
  String get call => _t('call');
  String get back => _t('back');
  String get zoomIn => _t('zoomIn');
  String get zoomOut => _t('zoomOut');
  String get resetView => _t('resetView');
  String get savedTitle => _t('savedTitle');
  String get places => _t('places');
  String get exploreCorridors => _t('exploreCorridors');
  String get tourismCorridors => _t('tourismCorridors');
  String get corridors => _t('corridors');
  String get stamps => _t('stamps');
  String get emptySaved => _t('emptySaved');
  String get emptySavedBody => _t('emptySavedBody');
  String get logIn => _t('logIn');
  String get email => _t('email');
  String get guestTitle => _t('guestTitle');
  String get guestSubtitle => _t('guestSubtitle');
  String get benefitSave => _t('benefitSave');
  String get benefitAny => _t('benefitAny');
  String get benefitAlerts => _t('benefitAlerts');
  String get language => _t('language');
  String get editProfile => _t('editProfile');
  String get profileCompleted => _t('profileCompleted');
  String get profileIncompleteTitle => _t('profileIncompleteTitle');
  String get profileIncompleteBody => _t('profileIncompleteBody');
  String get profilePhoto => _t('profilePhoto');
  String get completeProfile => _t('completeProfile');
  String get later => _t('later');
  String get changePhoto => _t('changePhoto');
  String get logOut => _t('logOut');
  String get logOutConfirm => _t('logOutConfirm');
  String get cancel => _t('cancel');
  String get account => _t('account');
  String get retry => _t('retry');
  String get somethingWentWrong => _t('somethingWentWrong');
  String get searchIn => _t('searchIn');
  String get editDetails => _t('editDetails');
  String get apply => _t('apply');
  String get nightSelected => _t('nightSelected');
  String get nightsSelected => _t('nightsSelected');
  String get stayDetails => _t('stayDetails');
  String get roomWord => _t('roomWord');
  String get roomsWord => _t('roomsWord');
  String get guestWord => _t('guestWord');
  String get guestsWord => _t('guestsWord');
  String get childWord => _t('childWord');
  String get childrenWord => _t('childrenWord');
  String get agesAdult => _t('agesAdult');
  String get agesChild => _t('agesChild');
  String get viewBookingDetails => _t('viewBookingDetails');
  String get adults => _t('adults');
  String get children => _t('children');
  String get done => _t('done');
  String get whatYouExpect => _t('whatYouExpect');
  String get aboutThisCorridor => _t('aboutThisCorridor');
  String get aboutPlace => _t('aboutPlace');
  String get cuisines => _t('cuisines');
  String get serving => _t('serving');
  String get closeNow => _t('closeNow');
  String get openNowPill => _t('openNowPill');
  String get signInFailed => _t('signInFailed');
  String get logInToSave => _t('logInToSave');
  String get durationDays => _t('durationDays');
  String get cambodia => _t('cambodia');
  String get mapLocationOff => _t('mapLocationOff');
  String get nearMe => _t('nearMe');
  String get logInToSeeSaved => _t('logInToSeeSaved');
  String get mapPickCorridor => _t('mapPickCorridor');
  String get recentSearches => _t('recentSearches');
  String get clearRecentSearches => _t('clearRecentSearches');
  String get searchFoundCount => _t('searchFoundCount');
  String get searchNoMatches => _t('searchNoMatches');
  String get searchNoMatchesBody => _t('searchNoMatchesBody');
  String get nearbyLocating => _t('nearbyLocating');
  String get nearbyLocationOff => _t('nearbyLocationOff');
  String get nearbyLocationDenied => _t('nearbyLocationDenied');
  String get nearbyLocationUnavailable => _t('nearbyLocationUnavailable');
  String get openSettingsAction => _t('openSettingsAction');
  String get nearbyNothing => _t('nearbyNothing');
  String get popularEmptyTitle => _t('popularEmptyTitle');
  String get popularEmptyBody => _t('popularEmptyBody');
  String get filterInterestsSubtitle => _t('filterInterestsSubtitle');
  String get typeToSearch => _t('typeToSearch');
  String get savedSignInTitle => _t('savedSignInTitle');
  String get savedSignInBody => _t('savedSignInBody');
  String get listView => _t('listView');
  String get gridView => _t('gridView');
  String get newFolder => _t('newFolder');
  String get folderName => _t('folderName');
  String get createWord => _t('createWord');
  String get addToFolder => _t('addToFolder');
  String get addedToFolder => _t('addedToFolder');
  String get removedFromFolder => _t('removedFromFolder');
  String get deleteFolder => _t('deleteFolder');
  String get foldersDeviceNote => _t('foldersDeviceNote');
  String get nothingToGroup => _t('nothingToGroup');
  String get markAllRead => _t('markAllRead');
  String get notificationDeleted => _t('notificationDeleted');
  String get notificationsSignIn => _t('notificationsSignIn');
  String get checkIns => _t('checkIns');
  String get pointsThisSeason => _t('pointsThisSeason');
  String get noCheckIns => _t('noCheckIns');
  String get noCheckInsBody => _t('noCheckInsBody');
  String get noPoints => _t('noPoints');
  String get noPointsBody => _t('noPointsBody');
  String get pointsForReview => _t('pointsForReview');
  String get pointsForRating => _t('pointsForRating');
  String get pointsWord => _t('pointsWord');
  String get fullName => _t('fullName');
  String get phoneNumber => _t('phoneNumber');
  String get changeEmailPassword => _t('changeEmailPassword');
  String get changeEmailPasswordNote => _t('changeEmailPasswordNote');
  String get photoUpdated => _t('photoUpdated');
  String get saveFailed => _t('saveFailed');
  String get badgesSignIn => _t('badgesSignIn');
  String get noLevelYet => _t('noLevelYet');
  String get seasonUntil => _t('seasonUntil');
  String get greenSeason => _t('greenSeason');
  String get highSeason => _t('highSeason');
  String get seasonPoints => _t('seasonPoints');
  String get pointsEarned => _t('pointsEarned');
  String get seasonDaysLeft => _t('seasonDaysLeft');
  String get seasonLastDay => _t('seasonLastDay');
  String get seasonEnded => _t('seasonEnded');
  String get seasonNext => _t('seasonNext');
  String get seasonNextNoDate => _t('seasonNextNoDate');
  String get seasonActivity => _t('seasonActivity');
  String get seasonTotals => _t('seasonTotals');
  String get badgesEarned => _t('badgesEarned');
  String get seasonsWord => _t('seasonsWord');
  String get noSeasonHistory => _t('noSeasonHistory');
  String get shareBadge => _t('shareBadge');
  String get shareBadgeText => _t('shareBadgeText');
  String get remainingTo => _t('remainingTo');
  String get deleteReview => _t('deleteReview');
  String get deleteReviewConfirm => _t('deleteReviewConfirm');
  String get reviewDeleted => _t('reviewDeleted');
  String get reviewUpdated => _t('reviewUpdated');
  String get saveChanges => _t('saveChanges');
  String get reviewsSignIn => _t('reviewsSignIn');
  String get reviewPending => _t('reviewPending');
  String get reviewRejected => _t('reviewRejected');
  String get visitBusiness => _t('visitBusiness');
  String get visitCouples => _t('visitCouples');
  String get visitFamily => _t('visitFamily');
  String get visitFriends => _t('visitFriends');
  String get visitSolo => _t('visitSolo');
  String get currencyNote => _t('currencyNote');
  String get notificationsAccountNote => _t('notificationsAccountNote');
  String get directions => _t('directions');
  String get staysNearby => _t('staysNearby');
  String get foodNearby => _t('foodNearby');
  String get openingHours => _t('openingHours');
  String get untilTime => _t('untilTime');
  String get dayMonday => _t('dayMonday');
  String get dayTuesday => _t('dayTuesday');
  String get dayWednesday => _t('dayWednesday');
  String get dayThursday => _t('dayThursday');
  String get dayFriday => _t('dayFriday');
  String get daySaturday => _t('daySaturday');
  String get daySunday => _t('daySunday');
  String get photoUploadFailed => _t('photoUploadFailed');
  String get priceTotalNights => _t('priceTotalNights');
  String get priceTotalOneNight => _t('priceTotalOneNight');
  String get roomTooSmall => _t('roomTooSmall');
  String get notEnoughRooms => _t('notEnoughRooms');
  String get minNightsNeeded => _t('minNightsNeeded');
  String get notBookable => _t('notBookable');
  String get noPriceForDates => _t('noPriceForDates');
  String get priceNoBooking => _t('priceNoBooking');
  String get sleepsGuests => _t('sleepsGuests');
  String get maxChildrenLabel => _t('maxChildrenLabel');
  String get stopsCount => _t('stopsCount');
  String get reviewSentForApproval => _t('reviewSentForApproval');
  String get emptyFolderHint => _t('emptyFolderHint');
  String get filterPickAny => _t('filterPickAny');
  String get reviewsCountLabel => _t('reviewsCountLabel');
  String get reviewCountOne => _t('reviewCountOne');
  String get closedToday => _t('closedToday');
  String get todayHours => _t('todayHours');
  String get homeProvince => _t('homeProvince');
  String get chooseProvince => _t('chooseProvince');
  String get topPercentOfMembers => _t('topPercentOfMembers');

  // Past seasons
  String get pastSeasons => _t('pastSeasons');
  String get pastSeasonsHint => _t('pastSeasonsHint');
  String get noPastSeasons => _t('noPastSeasons');
  String get noPastSeasonsBody => _t('noPastSeasonsBody');
  String get badgeCountOne => _t('badgeCountOne');
  String get badgeCountMany => _t('badgeCountMany');
  String get seasonPlaces => _t('seasonPlaces');
  String get seasonCompleted => _t('seasonCompleted');
  String get levelsReached => _t('levelsReached');
  String get badgesEarnedThisSeason => _t('badgesEarnedThisSeason');
  String get noBadgesThatSeason => _t('noBadgesThatSeason');
  String get notFinishedProgress => _t('notFinishedProgress');
  String get finishedTopPercent => _t('finishedTopPercent');
  String get otherSeason => _t('otherSeason');

  // Check-in by QR code
  String get checkInTitle => _t('checkInTitle');
  String get scanCode => _t('scanCode');
  String get checkInSignIn => _t('checkInSignIn');
  String get scanHint => _t('scanHint');
  String get typeCodeInstead => _t('typeCodeInstead');
  String get typeCodeTitle => _t('typeCodeTitle');
  String get typeCodeBody => _t('typeCodeBody');
  String get cameraUnavailable => _t('cameraUnavailable');
  String get cameraUnavailableBody => _t('cameraUnavailableBody');
  String get checkingIn => _t('checkingIn');
  String get stampCollected => _t('stampCollected');
  String get stampCollectedBody => _t('stampCollectedBody');
  String get alreadyCollected => _t('alreadyCollected');
  String get alreadyCollectedBody => _t('alreadyCollectedBody');
  String get tooFar => _t('tooFar');
  String get tooFarBody => _t('tooFarBody');
  String get tooFarNoDistance => _t('tooFarNoDistance');
  String get invalidCode => _t('invalidCode');
  String get invalidCodeBody => _t('invalidCodeBody');
  String get newBadgeEarned => _t('newBadgeEarned');
  String get scanAnother => _t('scanAnother');
  String get openThePlace => _t('openThePlace');
  String get checkInLocationTitle => _t('checkInLocationTitle');
  String get checkInLocationDenied => _t('checkInLocationDenied');
  String get checkInLocationOff => _t('checkInLocationOff');
  String get checkInLocationUnavailable => _t('checkInLocationUnavailable');
  String get activitiesNearby => _t('activitiesNearby');

  // Activities & Experiences

  /// An activity's `type` (DIVING, KAYAK, …) in words.
  String activityType(String code) => _strings.containsKey('activity$code') || en._strings.containsKey('activity$code')
      ? _t('activity$code')
      : _t('activityOTHER');
}
