import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
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
/// import 'l10n/app_localizations.dart';
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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ForkScale'**
  String get appTitle;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @actionDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get actionDetails;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get actionView;

  /// No description provided for @unitKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKcal;

  /// No description provided for @kcalValue.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String kcalValue(int kcal);

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String commonError(String error);

  /// No description provided for @mealBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @sourceBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get sourceBarcode;

  /// No description provided for @sourceRecipe.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get sourceRecipe;

  /// No description provided for @mealTypeHeader.
  ///
  /// In en, this message translates to:
  /// **'MEAL TYPE'**
  String get mealTypeHeader;

  /// No description provided for @confHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get confHigh;

  /// No description provided for @confMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get confMedium;

  /// No description provided for @confLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get confLow;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @resultsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analysis Results'**
  String get resultsTitle;

  /// No description provided for @resultsAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get resultsAddItem;

  /// No description provided for @resultsUtensilWarning.
  ///
  /// In en, this message translates to:
  /// **'Utensil not clearly visible — estimates may be less accurate.'**
  String get resultsUtensilWarning;

  /// No description provided for @resultsScaleConfidence.
  ///
  /// In en, this message translates to:
  /// **'Scale confidence'**
  String get resultsScaleConfidence;

  /// No description provided for @resultsScaleConfidenceBody.
  ///
  /// In en, this message translates to:
  /// **'High: utensil clearly visible and unobstructed.\nMedium: utensil partially visible or at an angle.\nLow: utensil barely visible — portion sizes may be inaccurate.'**
  String get resultsScaleConfidenceBody;

  /// No description provided for @resultsScaleConfidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Scale confidence: {level}'**
  String resultsScaleConfidenceLabel(String level);

  /// No description provided for @resultsLowConfidenceNudge.
  ///
  /// In en, this message translates to:
  /// **'Low scale confidence — portion sizes may be off. For a better estimate, retake with the whole utensil flat and fully in frame.'**
  String get resultsLowConfidenceNudge;

  /// No description provided for @resultsRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get resultsRetake;

  /// No description provided for @resultsNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get resultsNotesLabel;

  /// No description provided for @resultsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. post-run, cheat day'**
  String get resultsNotesHint;

  /// No description provided for @resultsSaveMeal.
  ///
  /// In en, this message translates to:
  /// **'Save meal'**
  String get resultsSaveMeal;

  /// No description provided for @ingredientNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Food item'**
  String get ingredientNameLabel;

  /// No description provided for @ingredientEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get ingredientEdited;

  /// No description provided for @ingredientAiValueTooltip.
  ///
  /// In en, this message translates to:
  /// **'Calorie value from AI (not USDA database)'**
  String get ingredientAiValueTooltip;

  /// No description provided for @ingredientRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove item'**
  String get ingredientRemove;

  /// No description provided for @ingredientWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight (g)'**
  String get ingredientWeight;

  /// No description provided for @ingredientKcalPer100g.
  ///
  /// In en, this message translates to:
  /// **'kcal / 100g'**
  String get ingredientKcalPer100g;

  /// No description provided for @ingredientMacros.
  ///
  /// In en, this message translates to:
  /// **'Macros (per 100g)'**
  String get ingredientMacros;

  /// No description provided for @ingredientProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get ingredientProtein;

  /// No description provided for @ingredientCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get ingredientCarbs;

  /// No description provided for @ingredientFat.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get ingredientFat;

  /// No description provided for @ingredientKcalTotal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String ingredientKcalTotal(int kcal);

  /// No description provided for @ingredientIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase weight by 10g'**
  String get ingredientIncrease;

  /// No description provided for @ingredientDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease weight by 10g'**
  String get ingredientDecrease;

  /// No description provided for @captureAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing…'**
  String get captureAnalysing;

  /// No description provided for @captureHint.
  ///
  /// In en, this message translates to:
  /// **'Place utensil beside the plate as scale'**
  String get captureHint;

  /// No description provided for @captureScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get captureScanBarcode;

  /// No description provided for @captureTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get captureTakePhoto;

  /// No description provided for @capturePickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get capturePickFromGallery;

  /// No description provided for @captureGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get captureGallery;

  /// No description provided for @capturePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get capturePlate;

  /// No description provided for @captureLoggedToday.
  ///
  /// In en, this message translates to:
  /// **'Logged today'**
  String get captureLoggedToday;

  /// No description provided for @captureKcal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal'**
  String captureKcal(int kcal);

  /// No description provided for @captureMealLogged.
  ///
  /// In en, this message translates to:
  /// **'{name} logged'**
  String captureMealLogged(String name);

  /// No description provided for @captureNoCamera.
  ///
  /// In en, this message translates to:
  /// **'No camera available on this device.'**
  String get captureNoCamera;

  /// No description provided for @captureCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Camera failed to start: {error}'**
  String captureCameraFailed(String error);

  /// No description provided for @captureTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Request timed out — save photo for later?'**
  String get captureTimedOut;

  /// No description provided for @captureRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Rate limit reached — save photo for later?'**
  String get captureRateLimit;

  /// No description provided for @captureOverloaded.
  ///
  /// In en, this message translates to:
  /// **'Gemini is overloaded — save photo for later?'**
  String get captureOverloaded;

  /// No description provided for @captureApiError.
  ///
  /// In en, this message translates to:
  /// **'API error ({code}).'**
  String captureApiError(int code);

  /// No description provided for @captureResponseCutOff.
  ///
  /// In en, this message translates to:
  /// **'Response was cut off — please retake the photo.'**
  String get captureResponseCutOff;

  /// No description provided for @captureCouldNotRead.
  ///
  /// In en, this message translates to:
  /// **'Could not read results — please retake the photo.'**
  String get captureCouldNotRead;

  /// No description provided for @captureUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get captureUnexpectedError;

  /// No description provided for @captureSaveForLater.
  ///
  /// In en, this message translates to:
  /// **'Save for later'**
  String get captureSaveForLater;

  /// No description provided for @capturePhotoSaved.
  ///
  /// In en, this message translates to:
  /// **'Photo saved — analyze it any time from History.'**
  String get capturePhotoSaved;

  /// No description provided for @captureApiKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Gemini API key missing or invalid.'**
  String get captureApiKeyMissing;

  /// No description provided for @captureErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Error detail'**
  String get captureErrorDetail;

  /// No description provided for @captureCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get captureCopied;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSectionCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get settingsSectionCapture;

  /// No description provided for @settingsFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get settingsFork;

  /// No description provided for @settingsKnife.
  ///
  /// In en, this message translates to:
  /// **'Knife'**
  String get settingsKnife;

  /// No description provided for @settingsSpoon.
  ///
  /// In en, this message translates to:
  /// **'Spoon'**
  String get settingsSpoon;

  /// No description provided for @settingsDailyGoal.
  ///
  /// In en, this message translates to:
  /// **'Daily calorie goal'**
  String get settingsDailyGoal;

  /// No description provided for @settingsGoalKcal.
  ///
  /// In en, this message translates to:
  /// **'Goal (kcal)'**
  String get settingsGoalKcal;

  /// No description provided for @settingsAiModel.
  ///
  /// In en, this message translates to:
  /// **'AI Model'**
  String get settingsAiModel;

  /// No description provided for @settingsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get settingsActive;

  /// No description provided for @settingsApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Gemini API Key'**
  String get settingsApiKeyLabel;

  /// No description provided for @settingsSaveKey.
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get settingsSaveKey;

  /// No description provided for @settingsApiKeyHintPrefix.
  ///
  /// In en, this message translates to:
  /// **'Free — no credit card needed. Sign in with a Google account at '**
  String get settingsApiKeyHintPrefix;

  /// No description provided for @settingsGoogleAiStudio.
  ///
  /// In en, this message translates to:
  /// **'Google AI Studio'**
  String get settingsGoogleAiStudio;

  /// No description provided for @settingsApiKeyHintSuffix.
  ///
  /// In en, this message translates to:
  /// **', then tap Get API key → Create API key.'**
  String get settingsApiKeyHintSuffix;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// No description provided for @settingsCalculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get settingsCalculating;

  /// No description provided for @settingsStorageSummary.
  ///
  /// In en, this message translates to:
  /// **'{db} DB · {photos} photos'**
  String settingsStorageSummary(String db, String photos);

  /// No description provided for @settingsExportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get settingsExportCsv;

  /// No description provided for @settingsCreateBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get settingsCreateBackup;

  /// No description provided for @settingsRestoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get settingsRestoreBackup;

  /// No description provided for @settingsClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear all history'**
  String get settingsClearHistory;

  /// No description provided for @settingsApiKeyRemoved.
  ///
  /// In en, this message translates to:
  /// **'API key removed'**
  String get settingsApiKeyRemoved;

  /// No description provided for @settingsApiKeySaved.
  ///
  /// In en, this message translates to:
  /// **'API key saved and verified ✓'**
  String get settingsApiKeySaved;

  /// No description provided for @settingsApiKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid API key — not saved. Check and try again.'**
  String get settingsApiKeyInvalid;

  /// No description provided for @settingsApiKeySavedNoVerify.
  ///
  /// In en, this message translates to:
  /// **'Key saved (could not verify — no internet)'**
  String get settingsApiKeySavedNoVerify;

  /// No description provided for @settingsBackupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String settingsBackupFailed(String error);

  /// No description provided for @settingsRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get settingsRestoreTitle;

  /// No description provided for @settingsRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This will replace all current data with the backup. The app will reload automatically.'**
  String get settingsRestoreBody;

  /// No description provided for @settingsBackupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored.'**
  String get settingsBackupRestored;

  /// No description provided for @settingsRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String settingsRestoreFailed(String error);

  /// No description provided for @settingsExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String settingsExportFailed(String error);

  /// No description provided for @settingsClearTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear all history?'**
  String get settingsClearTitle;

  /// No description provided for @settingsClearBody.
  ///
  /// In en, this message translates to:
  /// **'All meals and photos will be permanently deleted.'**
  String get settingsClearBody;

  /// No description provided for @settingsDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all'**
  String get settingsDeleteAll;

  /// No description provided for @settingsHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared.'**
  String get settingsHistoryCleared;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal History'**
  String get historyTitle;

  /// No description provided for @historyStarred.
  ///
  /// In en, this message translates to:
  /// **'Starred'**
  String get historyStarred;

  /// No description provided for @historySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search meals…'**
  String get historySearchHint;

  /// No description provided for @historyGoalLine.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get historyGoalLine;

  /// No description provided for @historyToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get historyToday;

  /// No description provided for @historyDayTotal.
  ///
  /// In en, this message translates to:
  /// **'{total} / {goal} kcal'**
  String historyDayTotal(int total, int goal);

  /// No description provided for @historyDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete meal?'**
  String get historyDeleteTitle;

  /// No description provided for @historyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the meal and its photo.'**
  String get historyDeleteBody;

  /// No description provided for @historyMealDeleted.
  ///
  /// In en, this message translates to:
  /// **'Meal deleted'**
  String get historyMealDeleted;

  /// No description provided for @historyPending.
  ///
  /// In en, this message translates to:
  /// **'Pending — not yet analyzed'**
  String get historyPending;

  /// No description provided for @historyStar.
  ///
  /// In en, this message translates to:
  /// **'Star meal'**
  String get historyStar;

  /// No description provided for @historyUnstar.
  ///
  /// In en, this message translates to:
  /// **'Unstar meal'**
  String get historyUnstar;

  /// No description provided for @historyCopyToToday.
  ///
  /// In en, this message translates to:
  /// **'Copy to today'**
  String get historyCopyToToday;

  /// No description provided for @historyCopiedToToday.
  ///
  /// In en, this message translates to:
  /// **'Copied {name} to today'**
  String historyCopiedToToday(String name);

  /// No description provided for @historyMealFallback.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get historyMealFallback;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No meals yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Take a photo to log your first meal'**
  String get historyEmptySubtitle;

  /// No description provided for @utensilFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get utensilFork;

  /// No description provided for @utensilKnife.
  ///
  /// In en, this message translates to:
  /// **'Knife'**
  String get utensilKnife;

  /// No description provided for @utensilSpoon.
  ///
  /// In en, this message translates to:
  /// **'Spoon'**
  String get utensilSpoon;

  /// No description provided for @macros.
  ///
  /// In en, this message translates to:
  /// **'Macros'**
  String get macros;

  /// No description provided for @macroProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get macroProtein;

  /// No description provided for @macroCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get macroCarbs;

  /// No description provided for @macroFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get macroFat;

  /// No description provided for @macroAbbrevProtein.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get macroAbbrevProtein;

  /// No description provided for @macroAbbrevCarbs.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get macroAbbrevCarbs;

  /// No description provided for @macroAbbrevFat.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get macroAbbrevFat;

  /// No description provided for @gramsValue.
  ///
  /// In en, this message translates to:
  /// **'{g} g'**
  String gramsValue(int g);

  /// No description provided for @mealDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Meal Detail'**
  String get mealDetailTitle;

  /// No description provided for @mealDetailPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending Meal'**
  String get mealDetailPendingTitle;

  /// No description provided for @mealDetailEditMeal.
  ///
  /// In en, this message translates to:
  /// **'Edit meal'**
  String get mealDetailEditMeal;

  /// No description provided for @mealDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Meal not found'**
  String get mealDetailNotFound;

  /// No description provided for @mealDetailApiKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'Gemini API key missing.'**
  String get mealDetailApiKeyMissing;

  /// No description provided for @mealDetailRateLimit.
  ///
  /// In en, this message translates to:
  /// **'Rate limit reached — try again in a minute.'**
  String get mealDetailRateLimit;

  /// No description provided for @mealDetailOverloaded.
  ///
  /// In en, this message translates to:
  /// **'Gemini is overloaded — try again in a moment.'**
  String get mealDetailOverloaded;

  /// No description provided for @mealDetailKeyInvalid.
  ///
  /// In en, this message translates to:
  /// **'API key invalid — check Settings.'**
  String get mealDetailKeyInvalid;

  /// No description provided for @mealDetailAnalysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed: {error}'**
  String mealDetailAnalysisFailed(String error);

  /// No description provided for @mealDetailPendingBody.
  ///
  /// In en, this message translates to:
  /// **'This photo was saved but not yet analyzed.'**
  String get mealDetailPendingBody;

  /// No description provided for @mealDetailAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get mealDetailAnalyzing;

  /// No description provided for @mealDetailAnalyzeNow.
  ///
  /// In en, this message translates to:
  /// **'Analyze now'**
  String get mealDetailAnalyzeNow;

  /// No description provided for @mealDetailConf.
  ///
  /// In en, this message translates to:
  /// **'Conf: {level}'**
  String mealDetailConf(String level);

  /// No description provided for @mealDetailIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get mealDetailIngredients;

  /// No description provided for @mealDetailIngredientsFromRecipe.
  ///
  /// In en, this message translates to:
  /// **'Ingredients (from recipe)'**
  String get mealDetailIngredientsFromRecipe;

  /// No description provided for @mealDetailItemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{weight} g · {kcal} kcal/100g'**
  String mealDetailItemSubtitle(int weight, int kcal);

  /// No description provided for @mealDetailRecipeMeal.
  ///
  /// In en, this message translates to:
  /// **'Recipe meal'**
  String get mealDetailRecipeMeal;

  /// No description provided for @mealDetailPortion.
  ///
  /// In en, this message translates to:
  /// **'{g} g portion'**
  String mealDetailPortion(int g);

  /// No description provided for @mealDetailGoToRecipe.
  ///
  /// In en, this message translates to:
  /// **'Go to recipe'**
  String get mealDetailGoToRecipe;

  /// No description provided for @mealDetailEditRecipe.
  ///
  /// In en, this message translates to:
  /// **'Edit recipe'**
  String get mealDetailEditRecipe;

  /// No description provided for @mealEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit meal'**
  String get mealEditTitle;

  /// No description provided for @mealEditNewItem.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get mealEditNewItem;

  /// No description provided for @mealEditSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get mealEditSaveChanges;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get insightsCurrentStreak;

  /// No description provided for @insightsNoStreak.
  ///
  /// In en, this message translates to:
  /// **'No streak yet'**
  String get insightsNoStreak;

  /// No description provided for @insightsStreakDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String insightsStreakDays(int count);

  /// No description provided for @insightsAvgIntake.
  ///
  /// In en, this message translates to:
  /// **'AVERAGE DAILY INTAKE'**
  String get insightsAvgIntake;

  /// No description provided for @insightsLast7.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get insightsLast7;

  /// No description provided for @insightsLast30.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get insightsLast30;

  /// No description provided for @insightsAvgMacros.
  ///
  /// In en, this message translates to:
  /// **'AVERAGE DAILY MACROS'**
  String get insightsAvgMacros;

  /// No description provided for @insightsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get insightsThisWeek;

  /// No description provided for @insightsDaysLogged.
  ///
  /// In en, this message translates to:
  /// **'Days logged'**
  String get insightsDaysLogged;

  /// No description provided for @insightsOverGoal.
  ///
  /// In en, this message translates to:
  /// **'Over goal'**
  String get insightsOverGoal;

  /// No description provided for @insightsOutOf7.
  ///
  /// In en, this message translates to:
  /// **'{n} / 7'**
  String insightsOutOf7(int n);

  /// No description provided for @insightsTopMeals.
  ///
  /// In en, this message translates to:
  /// **'MOST LOGGED MEALS'**
  String get insightsTopMeals;

  /// No description provided for @insightsCount.
  ///
  /// In en, this message translates to:
  /// **'{count}×'**
  String insightsCount(int count);

  /// No description provided for @insightsApproxKcal.
  ///
  /// In en, this message translates to:
  /// **'~{kcal} kcal'**
  String insightsApproxKcal(int kcal);

  /// No description provided for @recipesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipesTitle;

  /// No description provided for @recipesCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal/100g · {g} g'**
  String recipesCardSubtitle(int kcal, int g);

  /// No description provided for @recipesDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get recipesDuplicate;

  /// No description provided for @recipesCopySuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (copy)'**
  String recipesCopySuffix(String name);

  /// No description provided for @recipesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recipe?'**
  String get recipesDeleteTitle;

  /// No description provided for @recipesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String recipesDeleteBody(String name);

  /// No description provided for @recipesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recipes yet'**
  String get recipesEmptyTitle;

  /// No description provided for @recipesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to build your first recipe'**
  String get recipesEmptySubtitle;

  /// No description provided for @recipesNew.
  ///
  /// In en, this message translates to:
  /// **'New recipe'**
  String get recipesNew;

  /// No description provided for @recipeKcalPer100g.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal/100g'**
  String recipeKcalPer100g(int kcal);

  /// No description provided for @recipeDetailFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get recipeDetailFallbackTitle;

  /// No description provided for @recipeDetailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Recipe not found'**
  String get recipeDetailNotFound;

  /// No description provided for @recipeYield.
  ///
  /// In en, this message translates to:
  /// **'Yield: {g} g'**
  String recipeYield(int g);

  /// No description provided for @recipeLogPortion.
  ///
  /// In en, this message translates to:
  /// **'Log a portion'**
  String get recipeLogPortion;

  /// No description provided for @logPortionQuestion.
  ///
  /// In en, this message translates to:
  /// **'How much did you eat?'**
  String get logPortionQuestion;

  /// No description provided for @logPortionLogMeal.
  ///
  /// In en, this message translates to:
  /// **'Log meal'**
  String get logPortionLogMeal;

  /// No description provided for @barcodeScanError.
  ///
  /// In en, this message translates to:
  /// **'Could not read barcode — try again'**
  String get barcodeScanError;

  /// No description provided for @barcodeScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point at the barcode on the package'**
  String get barcodeScanHint;

  /// No description provided for @barcodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode: {code}'**
  String barcodeTitle(String code);

  /// No description provided for @barcodeProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get barcodeProductFallback;

  /// No description provided for @barcodeProductName.
  ///
  /// In en, this message translates to:
  /// **'Product name'**
  String get barcodeProductName;

  /// No description provided for @barcodePack.
  ///
  /// In en, this message translates to:
  /// **'Pack: {value}'**
  String barcodePack(String value);

  /// No description provided for @barcodeHowMuch.
  ///
  /// In en, this message translates to:
  /// **'How much did you have?'**
  String get barcodeHowMuch;

  /// No description provided for @barcodeTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {kcal} kcal'**
  String barcodeTotal(int kcal);

  /// No description provided for @barcodeLogMeal.
  ///
  /// In en, this message translates to:
  /// **'Log this meal'**
  String get barcodeLogMeal;

  /// No description provided for @barcodeAddToRecipe.
  ///
  /// In en, this message translates to:
  /// **'Add to recipe'**
  String get barcodeAddToRecipe;

  /// No description provided for @barcodeAddMoreItems.
  ///
  /// In en, this message translates to:
  /// **'Add more items'**
  String get barcodeAddMoreItems;

  /// No description provided for @barcodeLoggedSnack.
  ///
  /// In en, this message translates to:
  /// **'{name} logged ({kcal} kcal)'**
  String barcodeLoggedSnack(String name, int kcal);

  /// No description provided for @barcodeNutritionHeader.
  ///
  /// In en, this message translates to:
  /// **'Nutrition per 100 g / 100 ml'**
  String get barcodeNutritionHeader;

  /// No description provided for @barcodeEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy (kcal)'**
  String get barcodeEnergy;

  /// No description provided for @barcodeEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get barcodeEnterManually;

  /// No description provided for @barcodeNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get barcodeNotFoundTitle;

  /// No description provided for @barcodeDbUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Could not reach product database.'**
  String get barcodeDbUnreachable;

  /// No description provided for @barcodeNoProduct.
  ///
  /// In en, this message translates to:
  /// **'No product found for barcode {code}.'**
  String barcodeNoProduct(String code);

  /// No description provided for @barcodeContribute.
  ///
  /// In en, this message translates to:
  /// **'Contribute to Open Food Facts'**
  String get barcodeContribute;

  /// No description provided for @barcodeNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Product name is required'**
  String get barcodeNameRequired;

  /// No description provided for @barcodeProductNameStar.
  ///
  /// In en, this message translates to:
  /// **'Product name *'**
  String get barcodeProductNameStar;

  /// No description provided for @barcodeKcalPer100.
  ///
  /// In en, this message translates to:
  /// **'kcal per 100 g'**
  String get barcodeKcalPer100;

  /// No description provided for @barcodeZeroKcalWarning.
  ///
  /// In en, this message translates to:
  /// **'Logged with 0 kcal — you can edit it later.'**
  String get barcodeZeroKcalWarning;

  /// No description provided for @builderTitle.
  ///
  /// In en, this message translates to:
  /// **'Build meal'**
  String get builderTitle;

  /// No description provided for @builderAddItemFirst.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item first'**
  String get builderAddItemFirst;

  /// No description provided for @builderEmpty.
  ///
  /// In en, this message translates to:
  /// **'No items yet — scan a barcode or add manually'**
  String get builderEmpty;

  /// No description provided for @builderAddManually.
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get builderAddManually;

  /// No description provided for @builderItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String builderItemCount(int count);

  /// No description provided for @builderTotalKcal.
  ///
  /// In en, this message translates to:
  /// **'{kcal} kcal total'**
  String builderTotalKcal(int kcal);

  /// No description provided for @editorNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Recipe name is required'**
  String get editorNameRequired;

  /// No description provided for @editorYieldError.
  ///
  /// In en, this message translates to:
  /// **'Yield must be greater than 0'**
  String get editorYieldError;

  /// No description provided for @editorRecipeName.
  ///
  /// In en, this message translates to:
  /// **'Recipe name *'**
  String get editorRecipeName;

  /// No description provided for @editorYieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Yield (g) *'**
  String get editorYieldLabel;

  /// No description provided for @editorYieldHint.
  ///
  /// In en, this message translates to:
  /// **'Total grams produced'**
  String get editorYieldHint;

  /// No description provided for @editorScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get editorScale;

  /// No description provided for @editorNoIngredients.
  ///
  /// In en, this message translates to:
  /// **'No ingredients yet'**
  String get editorNoIngredients;

  /// No description provided for @editorIngredientLabel.
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get editorIngredientLabel;

  /// No description provided for @editorChooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get editorChooseGallery;

  /// No description provided for @editorAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo (optional)'**
  String get editorAddPhoto;

  /// No description provided for @editorTotalKcal.
  ///
  /// In en, this message translates to:
  /// **'Total: {kcal} kcal'**
  String editorTotalKcal(int kcal);

  /// No description provided for @editorPer100.
  ///
  /// In en, this message translates to:
  /// **'Per 100g: {kcal} kcal'**
  String editorPer100(int kcal);

  /// No description provided for @editorPer100Unknown.
  ///
  /// In en, this message translates to:
  /// **'Per 100g: — kcal'**
  String get editorPer100Unknown;

  /// No description provided for @editorSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search food database…'**
  String get editorSearchHint;

  /// No description provided for @editorNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get editorNoResults;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you start'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'ForkScale sends each photo you analyse to Google\'s Gemini API to estimate calories. Photos and meal data are otherwise stored only on this device. You can review this any time in Settings.'**
  String get privacyBody;

  /// No description provided for @privacyAccept.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get privacyAccept;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
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
