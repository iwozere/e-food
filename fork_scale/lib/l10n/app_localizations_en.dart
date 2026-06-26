// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'ForkScale';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionDetails => 'Details';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionOk => 'OK';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionView => 'View';

  @override
  String get unitKcal => 'kcal';

  @override
  String kcalValue(int kcal) {
    return '$kcal kcal';
  }

  @override
  String commonError(String error) {
    return 'Error: $error';
  }

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get sourceBarcode => 'Barcode';

  @override
  String get sourceRecipe => 'Recipe';

  @override
  String get mealTypeHeader => 'MEAL TYPE';

  @override
  String get confHigh => 'High';

  @override
  String get confMedium => 'Medium';

  @override
  String get confLow => 'Low';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHistory => 'History';

  @override
  String get resultsTitle => 'Analysis Results';

  @override
  String get resultsAddItem => 'Add item';

  @override
  String get resultsUtensilWarning =>
      'Utensil not clearly visible — estimates may be less accurate.';

  @override
  String get resultsScaleConfidence => 'Scale confidence';

  @override
  String get resultsScaleConfidenceBody =>
      'High: utensil clearly visible and unobstructed.\nMedium: utensil partially visible or at an angle.\nLow: utensil barely visible — portion sizes may be inaccurate.';

  @override
  String resultsScaleConfidenceLabel(String level) {
    return 'Scale confidence: $level';
  }

  @override
  String get resultsLowConfidenceNudge =>
      'Low scale confidence — portion sizes may be off. For a better estimate, retake with the whole utensil flat and fully in frame.';

  @override
  String get resultsRetake => 'Retake';

  @override
  String get resultsNotesLabel => 'Notes (optional)';

  @override
  String get resultsNotesHint => 'e.g. post-run, cheat day';

  @override
  String get resultsSaveMeal => 'Save meal';

  @override
  String get ingredientNameLabel => 'Food item';

  @override
  String get ingredientEdited => 'edited';

  @override
  String get ingredientAiValueTooltip =>
      'Calorie value from AI (not USDA database)';

  @override
  String get ingredientRemove => 'Remove item';

  @override
  String get ingredientWeight => 'Weight (g)';

  @override
  String get ingredientKcalPer100g => 'kcal / 100g';

  @override
  String get ingredientMacros => 'Macros (per 100g)';

  @override
  String get ingredientProtein => 'Protein (g)';

  @override
  String get ingredientCarbs => 'Carbs (g)';

  @override
  String get ingredientFat => 'Fat (g)';

  @override
  String ingredientKcalTotal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get ingredientIncrease => 'Increase weight by 10g';

  @override
  String get ingredientDecrease => 'Decrease weight by 10g';

  @override
  String get captureAnalysing => 'Analysing…';

  @override
  String get captureHint => 'Place utensil beside the plate as scale';

  @override
  String get captureScanBarcode => 'Scan barcode';

  @override
  String get captureTakePhoto => 'Take photo';

  @override
  String get capturePickFromGallery => 'Pick from gallery';

  @override
  String get captureGallery => 'Gallery';

  @override
  String get capturePlate => 'Plate';

  @override
  String get captureLoggedToday => 'Logged today';

  @override
  String captureKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String captureMealLogged(String name) {
    return '$name logged';
  }

  @override
  String get captureNoCamera => 'No camera available on this device.';

  @override
  String captureCameraFailed(String error) {
    return 'Camera failed to start: $error';
  }

  @override
  String get captureTimedOut => 'Request timed out — save photo for later?';

  @override
  String get captureRateLimit => 'Rate limit reached — save photo for later?';

  @override
  String get captureOverloaded =>
      'Gemini is overloaded — save photo for later?';

  @override
  String captureApiError(int code) {
    return 'API error ($code).';
  }

  @override
  String get captureResponseCutOff =>
      'Response was cut off — please retake the photo.';

  @override
  String get captureCouldNotRead =>
      'Could not read results — please retake the photo.';

  @override
  String get captureUnexpectedError => 'An unexpected error occurred.';

  @override
  String get captureSaveForLater => 'Save for later';

  @override
  String get capturePhotoSaved =>
      'Photo saved — analyze it any time from History.';

  @override
  String get captureApiKeyMissing => 'Gemini API key missing or invalid.';

  @override
  String get captureErrorDetail => 'Error detail';

  @override
  String get captureCopied => 'Copied to clipboard';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionCapture => 'Capture';

  @override
  String get settingsFork => 'Fork';

  @override
  String get settingsKnife => 'Knife';

  @override
  String get settingsSpoon => 'Spoon';

  @override
  String get settingsDailyGoal => 'Daily calorie goal';

  @override
  String get settingsGoalKcal => 'Goal (kcal)';

  @override
  String get settingsAiModel => 'AI Model';

  @override
  String get settingsActive => 'Active';

  @override
  String get settingsApiKeyLabel => 'Gemini API Key';

  @override
  String get settingsSaveKey => 'Save key';

  @override
  String get settingsApiKeyHintPrefix =>
      'Free — no credit card needed. Sign in with a Google account at ';

  @override
  String get settingsGoogleAiStudio => 'Google AI Studio';

  @override
  String get settingsApiKeyHintSuffix =>
      ', then tap Get API key → Create API key.';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsCalculating => 'Calculating…';

  @override
  String settingsStorageSummary(String db, String photos) {
    return '$db DB · $photos photos';
  }

  @override
  String get settingsExportCsv => 'Export to CSV';

  @override
  String get settingsCreateBackup => 'Create backup';

  @override
  String get settingsRestoreBackup => 'Restore from backup';

  @override
  String get settingsClearHistory => 'Clear all history';

  @override
  String get settingsApiKeyRemoved => 'API key removed';

  @override
  String get settingsApiKeySaved => 'API key saved and verified ✓';

  @override
  String get settingsApiKeyInvalid =>
      'Invalid API key — not saved. Check and try again.';

  @override
  String get settingsApiKeySavedNoVerify =>
      'Key saved (could not verify — no internet)';

  @override
  String settingsBackupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get settingsRestoreTitle => 'Restore backup?';

  @override
  String get settingsRestoreBody =>
      'This will replace all current data with the backup. The app will reload automatically.';

  @override
  String get settingsBackupRestored => 'Backup restored.';

  @override
  String settingsRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String settingsExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get settingsClearTitle => 'Clear all history?';

  @override
  String get settingsClearBody =>
      'All meals and photos will be permanently deleted.';

  @override
  String get settingsDeleteAll => 'Delete all';

  @override
  String get settingsHistoryCleared => 'History cleared.';

  @override
  String get historyTitle => 'Meal History';

  @override
  String get historyStarred => 'Starred';

  @override
  String get historySearchHint => 'Search meals…';

  @override
  String get historyGoalLine => 'Goal';

  @override
  String get historyToday => 'Today';

  @override
  String historyDayTotal(int total, int goal) {
    return '$total / $goal kcal';
  }

  @override
  String get historyDeleteTitle => 'Delete meal?';

  @override
  String get historyDeleteBody =>
      'This will permanently delete the meal and its photo.';

  @override
  String get historyMealDeleted => 'Meal deleted';

  @override
  String get historyPending => 'Pending — not yet analyzed';

  @override
  String get historyStar => 'Star meal';

  @override
  String get historyUnstar => 'Unstar meal';

  @override
  String get historyCopyToToday => 'Copy to today';

  @override
  String historyCopiedToToday(String name) {
    return 'Copied $name to today';
  }

  @override
  String get historyMealFallback => 'Meal';

  @override
  String get historyEmptyTitle => 'No meals yet';

  @override
  String get historyEmptySubtitle => 'Take a photo to log your first meal';

  @override
  String get utensilFork => 'Fork';

  @override
  String get utensilKnife => 'Knife';

  @override
  String get utensilSpoon => 'Spoon';

  @override
  String get macros => 'Macros';

  @override
  String get macroProtein => 'Protein';

  @override
  String get macroCarbs => 'Carbs';

  @override
  String get macroFat => 'Fat';

  @override
  String get macroAbbrevProtein => 'P';

  @override
  String get macroAbbrevCarbs => 'C';

  @override
  String get macroAbbrevFat => 'F';

  @override
  String gramsValue(int g) {
    return '$g g';
  }

  @override
  String get mealDetailTitle => 'Meal Detail';

  @override
  String get mealDetailPendingTitle => 'Pending Meal';

  @override
  String get mealDetailEditMeal => 'Edit meal';

  @override
  String get mealDetailNotFound => 'Meal not found';

  @override
  String get mealDetailApiKeyMissing => 'Gemini API key missing.';

  @override
  String get mealDetailRateLimit =>
      'Rate limit reached — try again in a minute.';

  @override
  String get mealDetailOverloaded =>
      'Gemini is overloaded — try again in a moment.';

  @override
  String get mealDetailKeyInvalid => 'API key invalid — check Settings.';

  @override
  String mealDetailAnalysisFailed(String error) {
    return 'Analysis failed: $error';
  }

  @override
  String get mealDetailPendingBody =>
      'This photo was saved but not yet analyzed.';

  @override
  String get mealDetailAnalyzing => 'Analyzing…';

  @override
  String get mealDetailAnalyzeNow => 'Analyze now';

  @override
  String mealDetailConf(String level) {
    return 'Conf: $level';
  }

  @override
  String get mealDetailIngredients => 'Ingredients';

  @override
  String get mealDetailIngredientsFromRecipe => 'Ingredients (from recipe)';

  @override
  String mealDetailItemSubtitle(int weight, int kcal) {
    return '$weight g · $kcal kcal/100g';
  }

  @override
  String get mealDetailRecipeMeal => 'Recipe meal';

  @override
  String mealDetailPortion(int g) {
    return '$g g portion';
  }

  @override
  String get mealDetailGoToRecipe => 'Go to recipe';

  @override
  String get mealDetailEditRecipe => 'Edit recipe';

  @override
  String get mealEditTitle => 'Edit meal';

  @override
  String get mealEditNewItem => 'New item';

  @override
  String get mealEditSaveChanges => 'Save changes';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsCurrentStreak => 'Current streak';

  @override
  String get insightsNoStreak => 'No streak yet';

  @override
  String insightsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get insightsAvgIntake => 'AVERAGE DAILY INTAKE';

  @override
  String get insightsLast7 => 'Last 7 days';

  @override
  String get insightsLast30 => 'Last 30 days';

  @override
  String get insightsAvgMacros => 'AVERAGE DAILY MACROS';

  @override
  String get insightsThisWeek => 'THIS WEEK';

  @override
  String get insightsDaysLogged => 'Days logged';

  @override
  String get insightsOverGoal => 'Over goal';

  @override
  String insightsOutOf7(int n) {
    return '$n / 7';
  }

  @override
  String get insightsTopMeals => 'MOST LOGGED MEALS';

  @override
  String insightsCount(int count) {
    return '$count×';
  }

  @override
  String insightsApproxKcal(int kcal) {
    return '~$kcal kcal';
  }

  @override
  String get recipesTitle => 'Recipes';

  @override
  String recipesCardSubtitle(int kcal, int g) {
    return '$kcal kcal/100g · $g g';
  }

  @override
  String get recipesDuplicate => 'Duplicate';

  @override
  String recipesCopySuffix(String name) {
    return '$name (copy)';
  }

  @override
  String get recipesDeleteTitle => 'Delete recipe?';

  @override
  String recipesDeleteBody(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get recipesEmptyTitle => 'No recipes yet';

  @override
  String get recipesEmptySubtitle => 'Tap + to build your first recipe';

  @override
  String get recipesNew => 'New recipe';

  @override
  String recipeKcalPer100g(int kcal) {
    return '$kcal kcal/100g';
  }

  @override
  String get recipeDetailFallbackTitle => 'Recipe';

  @override
  String get recipeDetailNotFound => 'Recipe not found';

  @override
  String recipeYield(int g) {
    return 'Yield: $g g';
  }

  @override
  String get recipeLogPortion => 'Log a portion';

  @override
  String get logPortionQuestion => 'How much did you eat?';

  @override
  String get logPortionLogMeal => 'Log meal';

  @override
  String get barcodeScanError => 'Could not read barcode — try again';

  @override
  String get barcodeScanHint => 'Point at the barcode on the package';

  @override
  String barcodeTitle(String code) {
    return 'Barcode: $code';
  }

  @override
  String get barcodeProductFallback => 'Product';

  @override
  String get barcodeProductName => 'Product name';

  @override
  String barcodePack(String value) {
    return 'Pack: $value';
  }

  @override
  String get barcodeHowMuch => 'How much did you have?';

  @override
  String barcodeTotal(int kcal) {
    return 'Total: $kcal kcal';
  }

  @override
  String get barcodeLogMeal => 'Log this meal';

  @override
  String get barcodeAddToRecipe => 'Add to recipe';

  @override
  String get barcodeAddMoreItems => 'Add more items';

  @override
  String barcodeLoggedSnack(String name, int kcal) {
    return '$name logged ($kcal kcal)';
  }

  @override
  String get barcodeNutritionHeader => 'Nutrition per 100 g / 100 ml';

  @override
  String get barcodeEnergy => 'Energy (kcal)';

  @override
  String get barcodeEnterManually => 'Enter manually';

  @override
  String get barcodeNotFoundTitle => 'Product not found';

  @override
  String get barcodeDbUnreachable => 'Could not reach product database.';

  @override
  String barcodeNoProduct(String code) {
    return 'No product found for barcode $code.';
  }

  @override
  String get barcodeContribute => 'Contribute to Open Food Facts';

  @override
  String get barcodeNameRequired => 'Product name is required';

  @override
  String get barcodeProductNameStar => 'Product name *';

  @override
  String get barcodeKcalPer100 => 'kcal per 100 g';

  @override
  String get barcodeZeroKcalWarning =>
      'Logged with 0 kcal — you can edit it later.';

  @override
  String get builderTitle => 'Build meal';

  @override
  String get builderAddItemFirst => 'Add at least one item first';

  @override
  String get builderEmpty => 'No items yet — scan a barcode or add manually';

  @override
  String get builderAddManually => 'Add manually';

  @override
  String builderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String builderTotalKcal(int kcal) {
    return '$kcal kcal total';
  }

  @override
  String get editorNameRequired => 'Recipe name is required';

  @override
  String get editorYieldError => 'Yield must be greater than 0';

  @override
  String get editorRecipeName => 'Recipe name *';

  @override
  String get editorYieldLabel => 'Yield (g) *';

  @override
  String get editorYieldHint => 'Total grams produced';

  @override
  String get editorScale => 'Scale';

  @override
  String get editorNoIngredients => 'No ingredients yet';

  @override
  String get editorIngredientLabel => 'Ingredient';

  @override
  String get editorChooseGallery => 'Choose from gallery';

  @override
  String get editorAddPhoto => 'Add photo (optional)';

  @override
  String editorTotalKcal(int kcal) {
    return 'Total: $kcal kcal';
  }

  @override
  String editorPer100(int kcal) {
    return 'Per 100g: $kcal kcal';
  }

  @override
  String get editorPer100Unknown => 'Per 100g: — kcal';

  @override
  String get editorSearchHint => 'Search food database…';

  @override
  String get editorNoResults => 'No results found';

  @override
  String get privacyTitle => 'Before you start';

  @override
  String get privacyBody =>
      'ForkScale sends each photo you analyse to Google\'s Gemini API to estimate calories. Photos and meal data are otherwise stored only on this device. You can review this any time in Settings.';

  @override
  String get privacyAccept => 'Got it';
}
