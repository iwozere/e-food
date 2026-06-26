// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'ForkScale';

  @override
  String get actionSave => 'Speichern';

  @override
  String get actionCancel => 'Abbrechen';

  @override
  String get actionClose => 'Schließen';

  @override
  String get actionCopy => 'Kopieren';

  @override
  String get actionDetails => 'Details';

  @override
  String get actionRestore => 'Wiederherstellen';

  @override
  String get actionOk => 'OK';

  @override
  String get actionDelete => 'Löschen';

  @override
  String get actionEdit => 'Bearbeiten';

  @override
  String get actionAdd => 'Hinzufügen';

  @override
  String get actionView => 'Ansehen';

  @override
  String get unitKcal => 'kcal';

  @override
  String kcalValue(int kcal) {
    return '$kcal kcal';
  }

  @override
  String commonError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get mealBreakfast => 'Frühstück';

  @override
  String get mealLunch => 'Mittagessen';

  @override
  String get mealDinner => 'Abendessen';

  @override
  String get mealSnack => 'Snack';

  @override
  String get sourceBarcode => 'Barcode';

  @override
  String get sourceRecipe => 'Rezept';

  @override
  String get mealTypeHeader => 'MAHLZEITTYP';

  @override
  String get confHigh => 'Hoch';

  @override
  String get confMedium => 'Mittel';

  @override
  String get confLow => 'Niedrig';

  @override
  String get navSettings => 'Einstellungen';

  @override
  String get navHistory => 'Verlauf';

  @override
  String get resultsTitle => 'Analyseergebnisse';

  @override
  String get resultsAddItem => 'Zutat hinzufügen';

  @override
  String get resultsUtensilWarning =>
      'Besteck nicht klar sichtbar — Schätzungen können ungenauer sein.';

  @override
  String get resultsScaleConfidence => 'Maßstab-Konfidenz';

  @override
  String get resultsScaleConfidenceBody =>
      'Hoch: Besteck klar und unverdeckt sichtbar.\nMittel: Besteck teilweise sichtbar oder schräg.\nNiedrig: Besteck kaum sichtbar — Portionsgrößen können ungenau sein.';

  @override
  String resultsScaleConfidenceLabel(String level) {
    return 'Maßstab-Konfidenz: $level';
  }

  @override
  String get resultsLowConfidenceNudge =>
      'Niedrige Maßstab-Konfidenz — Portionsgrößen können abweichen. Für eine bessere Schätzung das ganze Besteck flach und vollständig im Bild erneut aufnehmen.';

  @override
  String get resultsRetake => 'Erneut aufnehmen';

  @override
  String get resultsNotesLabel => 'Notizen (optional)';

  @override
  String get resultsNotesHint => 'z. B. nach dem Lauf, Schlemmertag';

  @override
  String get resultsSaveMeal => 'Mahlzeit speichern';

  @override
  String get ingredientNameLabel => 'Lebensmittel';

  @override
  String get ingredientEdited => 'bearbeitet';

  @override
  String get ingredientAiValueTooltip =>
      'Kalorienwert von der KI (nicht aus der USDA-Datenbank)';

  @override
  String get ingredientRemove => 'Zutat entfernen';

  @override
  String get ingredientWeight => 'Gewicht (g)';

  @override
  String get ingredientKcalPer100g => 'kcal / 100g';

  @override
  String get ingredientMacros => 'Makros (pro 100g)';

  @override
  String get ingredientProtein => 'Protein (g)';

  @override
  String get ingredientCarbs => 'Kohlenhydrate (g)';

  @override
  String get ingredientFat => 'Fett (g)';

  @override
  String ingredientKcalTotal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String get ingredientIncrease => 'Gewicht um 10g erhöhen';

  @override
  String get ingredientDecrease => 'Gewicht um 10g verringern';

  @override
  String get captureAnalysing => 'Analysiere…';

  @override
  String get captureHint => 'Besteck als Maßstab neben den Teller legen';

  @override
  String get captureScanBarcode => 'Barcode scannen';

  @override
  String get captureTakePhoto => 'Foto aufnehmen';

  @override
  String get capturePickFromGallery => 'Aus Galerie wählen';

  @override
  String get captureGallery => 'Galerie';

  @override
  String get capturePlate => 'Teller';

  @override
  String get captureLoggedToday => 'Heute erfasst';

  @override
  String captureKcal(int kcal) {
    return '$kcal kcal';
  }

  @override
  String captureMealLogged(String name) {
    return '$name erfasst';
  }

  @override
  String get captureNoCamera => 'Auf diesem Gerät ist keine Kamera verfügbar.';

  @override
  String captureCameraFailed(String error) {
    return 'Kamera konnte nicht gestartet werden: $error';
  }

  @override
  String get captureTimedOut =>
      'Zeitüberschreitung — Foto für später speichern?';

  @override
  String get captureRateLimit =>
      'Anfragelimit erreicht — Foto für später speichern?';

  @override
  String get captureOverloaded =>
      'Gemini ist überlastet — Foto für später speichern?';

  @override
  String captureApiError(int code) {
    return 'API-Fehler ($code).';
  }

  @override
  String get captureResponseCutOff =>
      'Antwort wurde abgeschnitten — bitte Foto erneut aufnehmen.';

  @override
  String get captureCouldNotRead =>
      'Ergebnisse konnten nicht gelesen werden — bitte Foto erneut aufnehmen.';

  @override
  String get captureUnexpectedError =>
      'Ein unerwarteter Fehler ist aufgetreten.';

  @override
  String get captureSaveForLater => 'Für später speichern';

  @override
  String get capturePhotoSaved =>
      'Foto gespeichert — jederzeit im Verlauf analysierbar.';

  @override
  String get captureApiKeyMissing =>
      'Gemini-API-Schlüssel fehlt oder ist ungültig.';

  @override
  String get captureErrorDetail => 'Fehlerdetails';

  @override
  String get captureCopied => 'In die Zwischenablage kopiert';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionCapture => 'Aufnahme';

  @override
  String get settingsFork => 'Gabel';

  @override
  String get settingsKnife => 'Messer';

  @override
  String get settingsSpoon => 'Löffel';

  @override
  String get settingsDailyGoal => 'Tägliches Kalorienziel';

  @override
  String get settingsGoalKcal => 'Ziel (kcal)';

  @override
  String get settingsAiModel => 'KI-Modell';

  @override
  String get settingsActive => 'Aktiv';

  @override
  String get settingsApiKeyLabel => 'Gemini-API-Schlüssel';

  @override
  String get settingsSaveKey => 'Schlüssel speichern';

  @override
  String get settingsApiKeyHintPrefix =>
      'Kostenlos — keine Kreditkarte nötig. Melde dich mit einem Google-Konto an unter ';

  @override
  String get settingsGoogleAiStudio => 'Google AI Studio';

  @override
  String get settingsApiKeyHintSuffix =>
      ', dann auf „Get API key“ → „Create API key“ tippen.';

  @override
  String get settingsStorage => 'Speicher';

  @override
  String get settingsCalculating => 'Berechne…';

  @override
  String settingsStorageSummary(String db, String photos) {
    return '$db DB · $photos Fotos';
  }

  @override
  String get settingsExportCsv => 'Als CSV exportieren';

  @override
  String get settingsCreateBackup => 'Backup erstellen';

  @override
  String get settingsRestoreBackup => 'Aus Backup wiederherstellen';

  @override
  String get settingsClearHistory => 'Gesamten Verlauf löschen';

  @override
  String get settingsApiKeyRemoved => 'API-Schlüssel entfernt';

  @override
  String get settingsApiKeySaved => 'API-Schlüssel gespeichert und geprüft ✓';

  @override
  String get settingsApiKeyInvalid =>
      'Ungültiger API-Schlüssel — nicht gespeichert. Bitte prüfen und erneut versuchen.';

  @override
  String get settingsApiKeySavedNoVerify =>
      'Schlüssel gespeichert (konnte nicht geprüft werden — kein Internet)';

  @override
  String settingsBackupFailed(String error) {
    return 'Backup fehlgeschlagen: $error';
  }

  @override
  String get settingsRestoreTitle => 'Backup wiederherstellen?';

  @override
  String get settingsRestoreBody =>
      'Dadurch werden alle aktuellen Daten durch das Backup ersetzt. Die App wird automatisch neu geladen.';

  @override
  String get settingsBackupRestored => 'Backup wiederhergestellt.';

  @override
  String settingsRestoreFailed(String error) {
    return 'Wiederherstellung fehlgeschlagen: $error';
  }

  @override
  String settingsExportFailed(String error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String get settingsClearTitle => 'Gesamten Verlauf löschen?';

  @override
  String get settingsClearBody =>
      'Alle Mahlzeiten und Fotos werden dauerhaft gelöscht.';

  @override
  String get settingsDeleteAll => 'Alle löschen';

  @override
  String get settingsHistoryCleared => 'Verlauf gelöscht.';

  @override
  String get historyTitle => 'Mahlzeiten-Verlauf';

  @override
  String get historyStarred => 'Favoriten';

  @override
  String get historySearchHint => 'Mahlzeiten suchen…';

  @override
  String get historyGoalLine => 'Ziel';

  @override
  String get historyToday => 'Heute';

  @override
  String historyDayTotal(int total, int goal) {
    return '$total / $goal kcal';
  }

  @override
  String get historyDeleteTitle => 'Mahlzeit löschen?';

  @override
  String get historyDeleteBody =>
      'Dadurch werden die Mahlzeit und ihr Foto dauerhaft gelöscht.';

  @override
  String get historyMealDeleted => 'Mahlzeit gelöscht';

  @override
  String get historyPending => 'Ausstehend — noch nicht analysiert';

  @override
  String get historyStar => 'Zu Favoriten';

  @override
  String get historyUnstar => 'Aus Favoriten entfernen';

  @override
  String get historyCopyToToday => 'Auf heute kopieren';

  @override
  String historyCopiedToToday(String name) {
    return '$name auf heute kopiert';
  }

  @override
  String get historyMealFallback => 'Mahlzeit';

  @override
  String get historyEmptyTitle => 'Noch keine Mahlzeiten';

  @override
  String get historyEmptySubtitle =>
      'Mach ein Foto, um deine erste Mahlzeit zu erfassen';

  @override
  String get utensilFork => 'Gabel';

  @override
  String get utensilKnife => 'Messer';

  @override
  String get utensilSpoon => 'Löffel';

  @override
  String get macros => 'Makros';

  @override
  String get macroProtein => 'Protein';

  @override
  String get macroCarbs => 'Kohlenhydrate';

  @override
  String get macroFat => 'Fett';

  @override
  String get macroAbbrevProtein => 'P';

  @override
  String get macroAbbrevCarbs => 'K';

  @override
  String get macroAbbrevFat => 'F';

  @override
  String gramsValue(int g) {
    return '$g g';
  }

  @override
  String get mealDetailTitle => 'Mahlzeit-Details';

  @override
  String get mealDetailPendingTitle => 'Ausstehende Mahlzeit';

  @override
  String get mealDetailEditMeal => 'Mahlzeit bearbeiten';

  @override
  String get mealDetailNotFound => 'Mahlzeit nicht gefunden';

  @override
  String get mealDetailApiKeyMissing => 'Gemini-API-Schlüssel fehlt.';

  @override
  String get mealDetailRateLimit =>
      'Anfragelimit erreicht — in einer Minute erneut versuchen.';

  @override
  String get mealDetailOverloaded =>
      'Gemini ist überlastet — gleich erneut versuchen.';

  @override
  String get mealDetailKeyInvalid =>
      'API-Schlüssel ungültig — in den Einstellungen prüfen.';

  @override
  String mealDetailAnalysisFailed(String error) {
    return 'Analyse fehlgeschlagen: $error';
  }

  @override
  String get mealDetailPendingBody =>
      'Dieses Foto wurde gespeichert, aber noch nicht analysiert.';

  @override
  String get mealDetailAnalyzing => 'Analysiere…';

  @override
  String get mealDetailAnalyzeNow => 'Jetzt analysieren';

  @override
  String mealDetailConf(String level) {
    return 'Konf.: $level';
  }

  @override
  String get mealDetailIngredients => 'Zutaten';

  @override
  String get mealDetailIngredientsFromRecipe => 'Zutaten (aus Rezept)';

  @override
  String mealDetailItemSubtitle(int weight, int kcal) {
    return '$weight g · $kcal kcal/100g';
  }

  @override
  String get mealDetailRecipeMeal => 'Rezept-Mahlzeit';

  @override
  String mealDetailPortion(int g) {
    return '$g g Portion';
  }

  @override
  String get mealDetailGoToRecipe => 'Zum Rezept';

  @override
  String get mealDetailEditRecipe => 'Rezept bearbeiten';

  @override
  String get mealEditTitle => 'Mahlzeit bearbeiten';

  @override
  String get mealEditNewItem => 'Neue Zutat';

  @override
  String get mealEditSaveChanges => 'Änderungen speichern';

  @override
  String get insightsTitle => 'Statistiken';

  @override
  String get insightsCurrentStreak => 'Aktuelle Serie';

  @override
  String get insightsNoStreak => 'Noch keine Serie';

  @override
  String insightsStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage',
      one: '1 Tag',
    );
    return '$_temp0';
  }

  @override
  String get insightsAvgIntake => 'DURCHSCHNITTLICHE TAGESZUFUHR';

  @override
  String get insightsLast7 => 'Letzte 7 Tage';

  @override
  String get insightsLast30 => 'Letzte 30 Tage';

  @override
  String get insightsAvgMacros => 'DURCHSCHNITTLICHE TAGES-MAKROS';

  @override
  String get insightsThisWeek => 'DIESE WOCHE';

  @override
  String get insightsDaysLogged => 'Erfasste Tage';

  @override
  String get insightsOverGoal => 'Über dem Ziel';

  @override
  String insightsOutOf7(int n) {
    return '$n / 7';
  }

  @override
  String get insightsTopMeals => 'AM HÄUFIGSTEN ERFASST';

  @override
  String insightsCount(int count) {
    return '$count×';
  }

  @override
  String insightsApproxKcal(int kcal) {
    return '~$kcal kcal';
  }

  @override
  String get recipesTitle => 'Rezepte';

  @override
  String recipesCardSubtitle(int kcal, int g) {
    return '$kcal kcal/100g · $g g';
  }

  @override
  String get recipesDuplicate => 'Duplizieren';

  @override
  String recipesCopySuffix(String name) {
    return '$name (Kopie)';
  }

  @override
  String get recipesDeleteTitle => 'Rezept löschen?';

  @override
  String recipesDeleteBody(String name) {
    return '„$name“ löschen?';
  }

  @override
  String get recipesEmptyTitle => 'Noch keine Rezepte';

  @override
  String get recipesEmptySubtitle =>
      'Tippe auf +, um dein erstes Rezept zu erstellen';

  @override
  String get recipesNew => 'Neues Rezept';

  @override
  String recipeKcalPer100g(int kcal) {
    return '$kcal kcal/100g';
  }

  @override
  String get recipeDetailFallbackTitle => 'Rezept';

  @override
  String get recipeDetailNotFound => 'Rezept nicht gefunden';

  @override
  String recipeYield(int g) {
    return 'Ertrag: $g g';
  }

  @override
  String get recipeLogPortion => 'Portion erfassen';

  @override
  String get logPortionQuestion => 'Wie viel hast du gegessen?';

  @override
  String get logPortionLogMeal => 'Mahlzeit erfassen';

  @override
  String get barcodeScanError =>
      'Barcode konnte nicht gelesen werden — erneut versuchen';

  @override
  String get barcodeScanHint => 'Auf den Barcode der Verpackung richten';

  @override
  String barcodeTitle(String code) {
    return 'Barcode: $code';
  }

  @override
  String get barcodeProductFallback => 'Produkt';

  @override
  String get barcodeProductName => 'Produktname';

  @override
  String barcodePack(String value) {
    return 'Packung: $value';
  }

  @override
  String get barcodeHowMuch => 'Wie viel hattest du?';

  @override
  String barcodeTotal(int kcal) {
    return 'Gesamt: $kcal kcal';
  }

  @override
  String get barcodeLogMeal => 'Diese Mahlzeit erfassen';

  @override
  String get barcodeAddToRecipe => 'Zum Rezept hinzufügen';

  @override
  String get barcodeAddMoreItems => 'Weitere Zutaten hinzufügen';

  @override
  String barcodeLoggedSnack(String name, int kcal) {
    return '$name erfasst ($kcal kcal)';
  }

  @override
  String get barcodeNutritionHeader => 'Nährwerte pro 100 g / 100 ml';

  @override
  String get barcodeEnergy => 'Energie (kcal)';

  @override
  String get barcodeEnterManually => 'Manuell eingeben';

  @override
  String get barcodeNotFoundTitle => 'Produkt nicht gefunden';

  @override
  String get barcodeDbUnreachable => 'Produktdatenbank nicht erreichbar.';

  @override
  String barcodeNoProduct(String code) {
    return 'Kein Produkt für Barcode $code gefunden.';
  }

  @override
  String get barcodeContribute => 'Zu Open Food Facts beitragen';

  @override
  String get barcodeNameRequired => 'Produktname ist erforderlich';

  @override
  String get barcodeProductNameStar => 'Produktname *';

  @override
  String get barcodeKcalPer100 => 'kcal pro 100 g';

  @override
  String get barcodeZeroKcalWarning =>
      'Mit 0 kcal erfasst — du kannst es später bearbeiten.';

  @override
  String get builderTitle => 'Mahlzeit zusammenstellen';

  @override
  String get builderAddItemFirst => 'Füge zuerst mindestens eine Zutat hinzu';

  @override
  String get builderEmpty =>
      'Noch keine Zutaten — Barcode scannen oder manuell hinzufügen';

  @override
  String get builderAddManually => 'Manuell hinzufügen';

  @override
  String builderItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Zutaten',
      one: '1 Zutat',
    );
    return '$_temp0';
  }

  @override
  String builderTotalKcal(int kcal) {
    return '$kcal kcal gesamt';
  }

  @override
  String get editorNameRequired => 'Rezeptname ist erforderlich';

  @override
  String get editorYieldError => 'Ertrag muss größer als 0 sein';

  @override
  String get editorRecipeName => 'Rezeptname *';

  @override
  String get editorYieldLabel => 'Ertrag (g) *';

  @override
  String get editorYieldHint => 'Gesamtgewicht in Gramm';

  @override
  String get editorScale => 'Skalieren';

  @override
  String get editorNoIngredients => 'Noch keine Zutaten';

  @override
  String get editorIngredientLabel => 'Zutat';

  @override
  String get editorChooseGallery => 'Aus Galerie wählen';

  @override
  String get editorAddPhoto => 'Foto hinzufügen (optional)';

  @override
  String editorTotalKcal(int kcal) {
    return 'Gesamt: $kcal kcal';
  }

  @override
  String editorPer100(int kcal) {
    return 'Pro 100g: $kcal kcal';
  }

  @override
  String get editorPer100Unknown => 'Pro 100g: — kcal';

  @override
  String get editorSearchHint => 'Lebensmitteldatenbank durchsuchen…';

  @override
  String get editorNoResults => 'Keine Ergebnisse gefunden';

  @override
  String get privacyTitle => 'Bevor du startest';

  @override
  String get privacyBody =>
      'ForkScale sendet jedes analysierte Foto an die Gemini-API von Google, um Kalorien zu schätzen. Fotos und Mahlzeitendaten werden ansonsten nur auf diesem Gerät gespeichert. Du kannst dies jederzeit in den Einstellungen nachlesen.';

  @override
  String get privacyAccept => 'Verstanden';
}
