import 'package:flutter/foundation.dart';
import 'package:arcane/src/services/firebase_service.dart' as fb_service;
import 'package:arcane/src/services/storage_service.dart';
import 'package:arcane/src/utils/constants.dart';
import 'package:arcane/src/utils/helpers.dart' as helper;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:collection/collection.dart';
import 'dart:async';
import 'package:flutter/material.dart'; // For TimeOfDay

import 'package:arcane/src/models/game_models.dart';

import 'actions/task_actions.dart';
import 'actions/item_actions.dart';
import 'actions/combat_actions.dart';
import 'actions/ai_generation_actions.dart';
import 'actions/timer_actions.dart';
import 'actions/park_actions.dart';
import 'package:arcane/src/services/ai_service.dart'; // For chatbot AI service

class GameProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final AIService _aiService = AIService(); // For chatbot
  Timer? _periodicUiTimer;
  Timer? _autoSaveTimer;
  Timer? _parkUpdateTimer; // For park income/costs

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _authLoading = true;
  bool get authLoading => _authLoading;
  bool _isDataLoadingAfterLogin = false;
  bool get isDataLoadingAfterLogin => _isDataLoadingAfterLogin;
  bool _isUsernameMissing = false;
  bool get isUsernameMissing => _isUsernameMissing;

  String? _lastLoginDate;
  double _coins = 100;
  double _xp = 0;
  int _playerLevel = 1;
  double _playerEnergy = baseMaxPlayerEnergy;
  List<MainTask> _mainTasks =
      initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
  Map<String, dynamic> _completedByDay = {};
  List<OwnedArtifact> _artifacts = [];
  List<ArtifactTemplate> _artifactTemplatesList = [];
  List<EnemyTemplate> _enemyTemplatesList = [];
  List<GameLocation> _gameLocationsList = []; // New list for game locations
  List<Rune> _runeTemplatesList = [];
  List<OwnedRune> _ownedRunes = [];

  Map<String, PlayerStat> _playerGameStats = {
    ...Map.from(basePlayerGameStats.map((key, value) => MapEntry(
        key,
        PlayerStat(
            name: value.name,
            description: value.description,
            icon: value.icon,
            value: value.value,
            base: value.base)))),
  };
  void _ensureBonusXpModStat() {
    if (!_playerGameStats.containsKey('bonusXPMod')) {
      _playerGameStats['bonusXPMod'] = PlayerStat(
          name: 'XP CALC MOD', // Display name for the UI
          value: 0,
          base: 0,
          description: 'Internal XP modifier from gear.',
          icon: 'mdi-percent-outline'); // Using MDI string
    }
  }

  Map<String, String?> _equippedItems = {
    'weapon': null,
    'armor': null,
    'talisman': null
  };
  Map<String, String?> _equippedRunes = {
    'rune_slot_1': null,
    'rune_slot_2': null
  };

  List<String> _defeatedEnemyIds = [];
  List<String> _clearedLocationIds = []; // To track cleared locations
  List<String> get clearedLocationIds => _clearedLocationIds;

  CurrentGame _currentGame = CurrentGame(
      playerCurrentHp: basePlayerGameStats['vitality']!.value,
      currentPlaceKey: initialGameLocations.isNotEmpty
          ? initialGameLocations.first.id
          : null);
  GameSettings _settings = GameSettings();
  String _currentView = 'task-details';
  String? _selectedTaskId = initialMainTaskTemplates.isNotEmpty
      ? initialMainTaskTemplates[0].id
      : null;
  int _apiKeyIndex = 0;
  Map<String, ActiveTimerInfo> _activeTimers = {};

  bool _hasUnsavedChanges = false;
  bool _isManuallySaving = false;
  bool get isManuallySaving => _isManuallySaving;
  bool _isManuallyLoading = false;
  bool get isManuallyLoading => _isManuallyLoading;
  DateTime? _lastSuccessfulSaveTimestamp;
  DateTime? get lastSuccessfulSaveTimestamp => _lastSuccessfulSaveTimestamp;

  bool _isGeneratingGlobalContent = false;
  bool get isGeneratingContent => _isGeneratingGlobalContent;
  bool _isGeneratingSubquestsForTask = false;
  bool get isGeneratingSubquests => _isGeneratingSubquestsForTask;

  double _aiGenerationProgress = 0.0;
  double get aiGenerationProgress => _aiGenerationProgress;
  String _aiGenerationStatusMessage = "";
  String get aiGenerationStatusMessage => _aiGenerationStatusMessage;

  // Park Management State
  List<DinosaurSpecies> _dinosaurSpeciesList = [];
  List<BuildingTemplate> _buildingTemplatesList = [];
  List<OwnedBuilding> _ownedBuildings = [];
  List<OwnedDinosaur> _ownedDinosaurs = [];
  List<FossilRecord> _fossilRecords = [];
  ParkManager _parkManager = ParkManager();

  List<DinosaurSpecies> get dinosaurSpeciesList => _dinosaurSpeciesList;
  List<BuildingTemplate> get buildingTemplatesList => _buildingTemplatesList;
  List<OwnedBuilding> get ownedBuildings => _ownedBuildings;
  List<OwnedDinosaur> get ownedDinosaurs => _ownedDinosaurs;
  List<FossilRecord> get fossilRecords => _fossilRecords;
  ParkManager get parkManager => _parkManager;
  ParkActions get parkActions => _parkActions;

  String? get lastLoginDate => _lastLoginDate;
  double get coins => _coins;
  double get xp => _xp;
  int get playerLevel => _playerLevel;
  double get playerEnergy => _playerEnergy;
  List<MainTask> get mainTasks => _mainTasks;
  Map<String, dynamic> get completedByDay => _completedByDay;
  List<OwnedArtifact> get artifacts => _artifacts;
  List<ArtifactTemplate> get artifactTemplatesList => _artifactTemplatesList;
  List<EnemyTemplate> get enemyTemplatesList => _enemyTemplatesList;
  List<GameLocation> get gameLocationsList =>
      _gameLocationsList; // Getter for locations
  List<Rune> get runeTemplatesList => _runeTemplatesList;
  List<OwnedRune> get ownedRunes => _ownedRunes;

  Map<String, PlayerStat> get playerGameStats => _playerGameStats;
  Map<String, String?> get equippedItems => _equippedItems;
  Map<String, String?> get equippedRunes => _equippedRunes;

  List<String> get defeatedEnemyIds => _defeatedEnemyIds;
  CurrentGame get currentGame => _currentGame;
  GameSettings get settings => _settings;
  String get currentView => _currentView;
  String? get selectedTaskId => _selectedTaskId;
  int get apiKeyIndex => _apiKeyIndex;
  Map<String, ActiveTimerInfo> get activeTimers => _activeTimers;

  double get calculatedMaxEnergy =>
      baseMaxPlayerEnergy + (_playerLevel - 1) * playerEnergyPerLevelVitality;
  double get xpNeededForNextLevel =>
      helper.xpToNext(_playerLevel, xpPerLevelBase, xpLevelMultiplier);
  double get currentLevelXPStart =>
      helper.xpForLevel(_playerLevel, xpPerLevelBase, xpLevelMultiplier);
  double get currentLevelXPProgress => _xp - currentLevelXPStart;
  double get xpProgressPercent => xpNeededForNextLevel > 0
      ? (currentLevelXPProgress / xpNeededForNextLevel).clamp(0.0, 1.0) * 100
      : 0;

  TimeOfDay get wakeupTime =>
      TimeOfDay(hour: _settings.wakeupTimeHour, minute: _settings.wakeupTimeMinute);

  // Chatbot State
  ChatbotMemory _chatbotMemory = ChatbotMemory();
  ChatbotMemory get chatbotMemory => _chatbotMemory;
  bool _isChatbotMemoryInitialized = false;

  late final TaskActions _taskActions;
  late final ItemActions _itemActions;
  late final CombatActions _combatActions;
  late final AIGenerationActions _aiGenerationActions;
  late final TimerActions _timerActions;
  late final ParkActions _parkActions;

  GameProvider() {
    print("[GameProvider] Constructor called. Initializing actions first...");
    // Initialize actions first to prevent LateInitializationError from async callbacks
    _taskActions = TaskActions(this);
    _itemActions = ItemActions(this);
    _combatActions = CombatActions(this);
    _aiGenerationActions = AIGenerationActions(this);
    _timerActions = TimerActions(this);
    _parkActions = ParkActions(this);

    print("[GameProvider] Actions initialized. Ensuring bonusXPModStat...");
    _ensureBonusXpModStat();

    print("[GameProvider] Initializing core systems and listeners...");
    _initialize(); // Now call initialize, which sets up listeners

    _periodicUiTimer?.cancel();
    _periodicUiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimers.values.any((info) => info.isRunning)) {
        notifyListeners();
      }
    });

    _parkUpdateTimer?.cancel();
    _parkUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _parkActions
          .updateAllDinosaursStatus(); // Periodically update dinosaur needs
      _parkActions
          .recalculateParkStats(); // This also calls _updateBuildingOperationalStatusBasedOnPower and updates income/costs
    });
    print("[GameProvider] Initialization complete.");
  }

  @override
  void dispose() {
    print("[GameProvider] dispose called.");
    _periodicUiTimer?.cancel();
    _autoSaveTimer?.cancel();
    _parkUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Made async
    fb_service.authStateChanges.listen(_onAuthStateChanged);
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_hasUnsavedChanges &&
          _currentUser != null &&
          !_isManuallySaving &&
          !_isManuallyLoading) {
        print("[GameProvider] Auto-saving changes...");
        _performActualSave();
      }
    });
  }

  Future<void> _onAuthStateChanged(User? user) async {
    print("[GameProvider] _onAuthStateChanged triggered. User: ${user?.uid}");
    if (_authLoading &&
        _currentUser != null &&
        user != null &&
        _currentUser!.uid == user.uid) {
      print("[GameProvider] Auth state unchanged for same user, returning.");
      return;
    }

    _authLoading = true;
    notifyListeners();

    if (user != null) {
      print("[GameProvider] User signed in: ${user.uid}. Loading data...");
      _currentUser = user;
      _isDataLoadingAfterLogin = true;
      notifyListeners();

      final data = await _storageService.getUserData(user.uid);
      if (data != null) {
        print("[GameProvider] User data found, loading state.");
        _loadStateFromMap(data);
        _hasUnsavedChanges = false; // Data is in sync with cloud after load
        _handleDailyReset(); // Handle daily reset logic which includes potential content generation
      } else {
        print("[GameProvider] No user data found, resetting to initial state.");
        await _resetToInitialState(); // Make reset async if it involves async ops
        _lastLoginDate = helper.getTodayDateString(); // Set login date for new user
        _hasUnsavedChanges = true; // Mark as changed to trigger initial save
        if (settings.dailyAutoGenerateContent) {
          // Use new setting name
          print("[GameProvider] Initial content generation for new user.");
          // Don't await this if it blocks UI too much, let it run in background
          _aiGenerationActions
              .generateGameContent(_playerLevel,
                  isManual: false, isInitial: true, contentType: "all")
              .catchError((e) {
            print("Error during initial content generation: $e");
          }).whenComplete(() => _performActualSave()); // Save after initial content is generated
        } else {
          await _performActualSave(); // Save immediately if no initial content generation
        }
        _handleDailyReset(); // Call daily reset even for new user to set up daily state
      }
      _isChatbotMemoryInitialized = false; // Reset flag on new login/data load
      initializeChatbotMemory(); // Initialize chatbot memory after data load

      if (_currentUser?.displayName == null ||
          _currentUser!.displayName!.trim().isEmpty) {
        print("[GameProvider] Username is missing for current user.");
        _isUsernameMissing = true;
      } else {
        _isUsernameMissing = false;
      }
      _isDataLoadingAfterLogin = false;
    } else {
      print("[GameProvider] User signed out or null. Resetting state.");
      _currentUser = null;
      await _resetToInitialState(); // Make reset async
      _isDataLoadingAfterLogin = false;
      _hasUnsavedChanges = false;
      _isChatbotMemoryInitialized = false;
    }

    _authLoading = false;
    notifyListeners();
    print(
        "[GameProvider] _onAuthStateChanged finished. AuthLoading: $_authLoading, IsDataLoadingAfterLogin: $_isDataLoadingAfterLogin");
  }

  Map<String, dynamic> _gameStateToMap() {
    return {
      'lastLoginDate': _lastLoginDate,
      'coins': _coins,
      'xp': _xp,
      'playerLevel': _playerLevel,
      'playerEnergy': _playerEnergy,
      'mainTasks': _mainTasks.map((mt) => mt.toJson()).toList(),
      'completedByDay': _completedByDay,
      'artifacts': _artifacts.map((a) => a.toJson()).toList(),
      'artifactTemplatesList':
          _artifactTemplatesList.map((at) => at.toJson()).toList(),
      'enemyTemplatesList':
          _enemyTemplatesList.map((et) => et.toJson()).toList(),
      'gameLocationsList': _gameLocationsList
          .map((gl) => gl.toJson())
          .toList(), // Save locations
      'runeTemplatesList': _runeTemplatesList.map((rt) => rt.toJson()).toList(),
      'ownedRunes': _ownedRunes.map((or) => or.toJson()).toList(),
      'playerGameStats':
          _playerGameStats.map((key, stat) => MapEntry(key, stat.toJson())),
      'equippedItems': _equippedItems,
      'equippedRunes': _equippedRunes,
      'defeatedEnemyIds': _defeatedEnemyIds,
      'clearedLocationIds': _clearedLocationIds, // Save cleared locations
      'currentGame': _currentGame.toJson(),
      'settings': settings.toJson(),
      'currentView': _currentView,
      'selectedTaskId': _selectedTaskId,
      'apiKeyIndex': _apiKeyIndex,
      'activeTimers':
          _activeTimers.map((key, value) => MapEntry(key, value.toJson())),
      'lastSuccessfulSaveTimestamp':
          _lastSuccessfulSaveTimestamp?.toIso8601String(),
      // Park Management Data
      'dinosaurSpeciesList':
          _dinosaurSpeciesList.map((ds) => ds.toJson()).toList(),
      'buildingTemplatesList':
          _buildingTemplatesList.map((bt) => bt.toJson()).toList(),
      'ownedBuildings': _ownedBuildings.map((ob) => ob.toJson()).toList(),
      'ownedDinosaurs': _ownedDinosaurs.map((od) => od.toJson()).toList(),
      'fossilRecords': _fossilRecords.map((fr) => fr.toJson()).toList(),
      'parkManager': _parkManager.toJson(),
      // Chatbot Data
      'chatbotMemory': _chatbotMemory.toJson(),
    };
  }

  void _loadStateFromMap(Map<String, dynamic> data) {
    print("[GameProvider] Loading state from map: ${data.keys.toList()}");
    _lastLoginDate = data['lastLoginDate'] as String?;
    _coins = (data['coins'] as num? ?? 100).toDouble();
    _xp = (data['xp'] as num? ?? 0).toDouble();
    _playerLevel = data['playerLevel'] as int? ?? 1;
    _playerEnergy =
        (data['playerEnergy'] as num? ?? baseMaxPlayerEnergy).toDouble();

    _mainTasks = (data['mainTasks'] as List<dynamic>?)
            ?.map((mtJson) => MainTask.fromJson(mtJson as Map<String, dynamic>))
            .toList() ??
        initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();

    _completedByDay = data['completedByDay'] as Map<String, dynamic>? ?? {};
    _completedByDay.forEach((date, dayDataMap) {
      if (dayDataMap is Map<String, dynamic>) {
        dayDataMap.putIfAbsent('taskTimes', () => <String, int>{});
        dayDataMap.putIfAbsent(
            'subtasksCompleted', () => <Map<String, dynamic>>[]);
        dayDataMap.putIfAbsent(
            'checkpointsCompleted', () => <Map<String, dynamic>>[]);
        dayDataMap.putIfAbsent(
            'emotionLogs', () => <Map<String, dynamic>>[]); // Initialize emotionLogs
      }
    });

    _artifacts = (data['artifacts'] as List<dynamic>?)
            ?.map((aJson) =>
                OwnedArtifact.fromJson(aJson as Map<String, dynamic>))
            .toList() ??
        [];

    _artifactTemplatesList = (data['artifactTemplatesList'] as List<dynamic>?)
            ?.map((atJson) =>
                ArtifactTemplate.fromJson(atJson as Map<String, dynamic>))
            .toList() ??
        initialArtifactTemplates; // Use initial if not present

    _enemyTemplatesList = (data['enemyTemplatesList'] as List<dynamic>?)
            ?.map((etJson) =>
                EnemyTemplate.fromJson(etJson as Map<String, dynamic>))
            .toList() ??
        initialEnemyTemplates; // Use initial if not present

    _gameLocationsList = (data['gameLocationsList'] as List<dynamic>?)
            ?.map((glJson) =>
                GameLocation.fromJson(glJson as Map<String, dynamic>))
            .toList() ??
        initialGameLocations; // Use initial if not present

    _runeTemplatesList = (data['runeTemplatesList'] as List<dynamic>?)
            ?.map((rtJson) => Rune.fromJson(rtJson as Map<String, dynamic>))
            .toList() ??
        [];
    _ownedRunes = (data['ownedRunes'] as List<dynamic>?)
            ?.map(
                (orJson) => OwnedRune.fromJson(orJson as Map<String, dynamic>))
            .toList() ??
        [];

    final statsData = data['playerGameStats'] as Map<String, dynamic>?;
    _playerGameStats = {
      ...Map.from(basePlayerGameStats.map((key, value) => MapEntry(
          key,
          PlayerStat(
              name: value.name,
              description: value.description,
              icon: value.icon,
              value: value.value,
              base: value.base)))),
    };
    _ensureBonusXpModStat();

    if (statsData != null) {
      statsData.forEach((String key, dynamic statJsonValue) {
        if (_playerGameStats.containsKey(key) &&
            statJsonValue is Map<String, dynamic>) {
          _playerGameStats[key] = PlayerStat.fromJson(statJsonValue);
        } else if (!_playerGameStats.containsKey(key) &&
            statJsonValue is Map<String, dynamic> &&
            key == 'bonusXPMod') {
          _playerGameStats[key] = PlayerStat.fromJson(statJsonValue);
        }
      });
    }

    _equippedItems = Map<String, String?>.from(
        data['equippedItems'] as Map<dynamic, dynamic>? ??
            {'weapon': null, 'armor': null, 'talisman': null});
    _equippedRunes = Map<String, String?>.from(
        data['equippedRunes'] as Map<dynamic, dynamic>? ??
            {'rune_slot_1': null, 'rune_slot_2': null});
    _defeatedEnemyIds = (data['defeatedEnemyIds'] as List<dynamic>?)
            ?.map((id) => id as String)
            .toList() ??
        [];
    _clearedLocationIds = (data['clearedLocationIds'] as List<dynamic>?)
            ?.map((id) => id as String)
            .toList() ??
        []; // Load cleared locations

    _currentGame = data['currentGame'] != null
        ? CurrentGame.fromJson(
            data['currentGame'] as Map<String, dynamic>, _enemyTemplatesList)
        : CurrentGame(
            playerCurrentHp: _playerGameStats['vitality']!.value,
            currentPlaceKey: _gameLocationsList.isNotEmpty
                ? _gameLocationsList.first.id
                : null);

    // Ensure currentPlaceKey is valid
    if (_currentGame.currentPlaceKey == null && _gameLocationsList.isNotEmpty) {
      _currentGame.currentPlaceKey = _gameLocationsList.first.id;
    } else if (_currentGame.currentPlaceKey != null &&
        !_gameLocationsList
            .any((loc) => loc.id == _currentGame.currentPlaceKey)) {
      _currentGame.currentPlaceKey =
          _gameLocationsList.isNotEmpty ? _gameLocationsList.first.id : null;
    }

    _settings = data['settings'] != null
        ? GameSettings.fromJson(data['settings'] as Map<String, dynamic>)
        : GameSettings();

    _currentView = data['currentView'] as String? ?? 'task-details';
    _selectedTaskId = data['selectedTaskId'] as String? ??
        (_mainTasks.isNotEmpty ? _mainTasks[0].id : null);
    _apiKeyIndex = data['apiKeyIndex'] as int? ?? 0;

    _activeTimers = (data['activeTimers'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key,
                ActiveTimerInfo.fromJson(value as Map<String, dynamic>))) ??
        {};

    final timestampString = data['lastSuccessfulSaveTimestamp'] as String?;
    _lastSuccessfulSaveTimestamp =
        timestampString != null ? DateTime.tryParse(timestampString) : null;

    // Park Management Data Loading
    _dinosaurSpeciesList = (data['dinosaurSpeciesList'] as List<dynamic>?)
            ?.map((dsJson) =>
                DinosaurSpecies.fromJson(dsJson as Map<String, dynamic>))
            .toList() ??
        initialDinosaurSpecies;
    _buildingTemplatesList = (data['buildingTemplatesList'] as List<dynamic>?)
            ?.map((btJson) =>
                BuildingTemplate.fromJson(btJson as Map<String, dynamic>))
            .toList() ??
        initialBuildingTemplates;
    _ownedBuildings = (data['ownedBuildings'] as List<dynamic>?)
            ?.map((obJson) =>
                OwnedBuilding.fromJson(obJson as Map<String, dynamic>))
            .toList() ??
        [];
    _ownedDinosaurs = (data['ownedDinosaurs'] as List<dynamic>?)
            ?.map((odJson) =>
                OwnedDinosaur.fromJson(odJson as Map<String, dynamic>))
            .toList() ??
        [];
    _fossilRecords = (data['fossilRecords'] as List<dynamic>?)
            ?.map((frJson) =>
                FossilRecord.fromJson(frJson as Map<String, dynamic>))
            .toList() ??
        [];
    // Ensure fossil records list matches species list
    if (_fossilRecords.length != _dinosaurSpeciesList.length) {
      _fossilRecords = _dinosaurSpeciesList
          .map((species) => _fossilRecords.firstWhere(
              (fr) => fr.speciesId == species.id,
              orElse: () => FossilRecord(speciesId: species.id)))
          .toList();
    }

    _parkManager = data['parkManager'] != null
        ? ParkManager.fromJson(data['parkManager'] as Map<String, dynamic>)
        : ParkManager();

    // Chatbot data loading
    _chatbotMemory = data['chatbotMemory'] != null
        ? ChatbotMemory.fromJson(data['chatbotMemory'] as Map<String, dynamic>)
        : ChatbotMemory();
    _isChatbotMemoryInitialized = true; // Mark as initialized after loading

    _recalculatePlayerLevel();
    _updatePlayerStatsFromItemsAndRunes();
    _parkActions.recalculateParkStats(); // Recalculate park stats after loading
    print(
        "[GameProvider] State loaded. Current XP: $_xp, Level: $_playerLevel");
  }

  Future<void> _resetToInitialState() async {
    // Make async
    print("[GameProvider] Resetting to initial state.");
    _lastLoginDate = null;
    _coins = 100;
    _xp = 0;
    _playerLevel = 1;
    _playerEnergy = baseMaxPlayerEnergy;
    _mainTasks =
        initialMainTaskTemplates.map((t) => MainTask.fromTemplate(t)).toList();
    _completedByDay = {};
    _artifacts = [];

    // Potentially load these from assets async if they become large
    _artifactTemplatesList = List.from(initialArtifactTemplates);
    _enemyTemplatesList = List.from(initialEnemyTemplates);
    _gameLocationsList = List.from(initialGameLocations);

    _runeTemplatesList = [];
    _ownedRunes = [];
    _playerGameStats = {
      ...Map.from(basePlayerGameStats.map((key, value) => MapEntry(
          key,
          PlayerStat(
              name: value.name,
              description: value.description,
              icon: value.icon,
              value: value.value,
              base: value.base)))),
    };
    _ensureBonusXpModStat();
    _equippedItems = {'weapon': null, 'armor': null, 'talisman': null};
    _equippedRunes = {'rune_slot_1': null, 'rune_slot_2': null};
    _defeatedEnemyIds = [];
    _clearedLocationIds = []; // Reset cleared locations
    _currentGame = CurrentGame(
        playerCurrentHp: _playerGameStats['vitality']!.value,
        currentPlaceKey:
            _gameLocationsList.isNotEmpty ? _gameLocationsList.first.id : null);
    _settings = GameSettings();
    _currentView = 'task-details';
    _selectedTaskId = _mainTasks.isNotEmpty ? _mainTasks[0].id : null;
    _apiKeyIndex = 0;
    _activeTimers = {};
    _isUsernameMissing = false;
    _lastSuccessfulSaveTimestamp = null;

    // Park Management Reset
    _dinosaurSpeciesList = List.from(initialDinosaurSpecies);
    _buildingTemplatesList = List.from(initialBuildingTemplates);
    _ownedBuildings = [];
    _ownedDinosaurs = [];
    _fossilRecords = _dinosaurSpeciesList
        .map((species) => FossilRecord(speciesId: species.id))
        .toList();
    _parkManager = ParkManager(
        parkDollars: 50000,
        parkEnergy: _playerEnergy,
        maxParkEnergy:
            calculatedMaxEnergy); // Start with some dollars and link park energy to player energy
    // Chatbot Reset
    _chatbotMemory = ChatbotMemory();
    _isChatbotMemoryInitialized = true;

    _hasUnsavedChanges = true;

    final rustySword = _artifactTemplatesList
        .firstWhereOrNull((art) => art.id == "art_rusty_sword");
    if (rustySword != null) {
      _artifacts.add(OwnedArtifact(
          uniqueId: "owned_${rustySword.id}_init",
          templateId: rustySword.id,
          currentLevel: 1));
      _equippedItems['weapon'] = "owned_${rustySword.id}_init";
    }
    final leatherJerkin = _artifactTemplatesList
        .firstWhereOrNull((art) => art.id == "art_leather_jerkin");
    if (leatherJerkin != null) {
      _artifacts.add(OwnedArtifact(
          uniqueId: "owned_${leatherJerkin.id}_init",
          templateId: leatherJerkin.id,
          currentLevel: 1));
      _equippedItems['armor'] = "owned_${leatherJerkin.id}_init";
    }
    _updatePlayerStatsFromItemsAndRunes();
    _parkActions.recalculateParkStats(); // Recalculate park stats after reset
    print("[GameProvider] Initial state reset complete.");
  }

  Future<void> _performActualSave() async {
    if (_currentUser != null) {
      print(
          "[GameProvider] Performing actual save to Firestore for user ${_currentUser!.uid}");
      final success = await _storageService.setUserData(_currentUser!.uid,
          _gameStateToMap()); // Changed to setUserData for full overwrite
      if (success) {
        _lastSuccessfulSaveTimestamp = DateTime.now();
        _hasUnsavedChanges = false;
        notifyListeners(); // To update UI with new save timestamp if displayed
        print(
            "[GameProvider] Save successful. Timestamp: $_lastSuccessfulSaveTimestamp");
      } else {
        print("[GameProvider] Save FAILED.");
        // Optionally, add a log to the game's UI log about save failure
        setProviderState(
            currentGame: CurrentGame(
              enemy: _currentGame.enemy,
              playerCurrentHp: _currentGame.playerCurrentHp,
              log: [
                ..._currentGame.log,
                "<span style=\"color:${AppTheme.fhAccentRed.value.toRadixString(16).substring(2)};\">Critical Error: Failed to save game data to cloud!</span>"
              ],
              currentPlaceKey: _currentGame.currentPlaceKey,
            ),
            doPersist: false, // Don't try to re-save immediately
            doNotify: true);
      }
    } else {
      print("[GameProvider] Cannot save, no current user.");
    }
  }

  Future<void> manuallySaveToCloud() async {
    if (_currentUser == null) throw Exception("Not logged in. Cannot save.");
    print("[GameProvider] Manually saving to cloud...");
    _isManuallySaving = true;
    notifyListeners();
    try {
      await _performActualSave();
    } finally {
      _isManuallySaving = false;
      notifyListeners();
      print("[GameProvider] Manual save finished.");
    }
  }

  Future<void> manuallyLoadFromCloud() async {
    if (_currentUser == null) throw Exception("Not logged in. Cannot load.");
    print("[GameProvider] Manually loading from cloud...");
    _isManuallyLoading = true;
    notifyListeners();
    try {
      final data = await _storageService.getUserData(_currentUser!.uid);
      if (data != null) {
        _loadStateFromMap(data);
        _handleDailyReset(); // Call daily reset after loading data
        // No specific auto-generation here; daily reset handles it if enabled.
        if (_currentUser?.displayName == null ||
            _currentUser!.displayName!.trim().isEmpty) {
          _isUsernameMissing = true;
        } else {
          _isUsernameMissing = false;
        }
        _hasUnsavedChanges = false; // Data is now in sync with cloud
        _isChatbotMemoryInitialized = false; // Ensure chatbot memory is re-initialized
        initializeChatbotMemory();
      } else {
        throw Exception("No data found on cloud.");
      }
    } finally {
      _isManuallyLoading = false;
      notifyListeners();
      print("[GameProvider] Manual load finished.");
    }
  }

  Future<void> loginUser(String email, String password) async {
    print("[GameProvider] Attempting login for email: $email");
    await fb_service.signInWithEmail(email, password);
  }

  Future<void> signupUser(
      String email, String password, String username) async {
    print(
        "[GameProvider] Attempting signup for email: $email, username: $username");
    _authLoading = true;
    notifyListeners();
    try {
      UserCredential userCredential =
          await fb_service.firebaseAuthInstance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = userCredential.user;
      if (_currentUser != null) {
        print(
            "[GameProvider] Signup successful, user UID: ${_currentUser!.uid}. Updating display name.");
        await _currentUser!.updateDisplayName(username);
        await _currentUser!.reload();
        _currentUser =
            fb_service.firebaseAuthInstance.currentUser; // Refresh user object

        await _resetToInitialState(); // Make reset async
        _lastLoginDate = helper.getTodayDateString();
        _hasUnsavedChanges = true; // Mark for initial save
        // Trigger initial content generation if daily auto-gen is on
        if (settings.dailyAutoGenerateContent) {
          print(
              "[GameProvider] Initial content generation for new user after signup.");
          _aiGenerationActions
              .generateGameContent(_playerLevel,
                  isManual: false, isInitial: true, contentType: "all")
              .catchError((e) {
            print("Error during signup initial content generation: $e");
          }).whenComplete(() => _performActualSave());
        } else {
          await _performActualSave();
        }
        _isChatbotMemoryInitialized =
            false; // Ensure chatbot memory is re-initialized
        initializeChatbotMemory();

        _handleDailyReset();
        _isDataLoadingAfterLogin = false;
        _isUsernameMissing = false;
        print(
            "[GameProvider] Signup and initial setup complete for user: $username");
      } else {
        throw Exception("Signup successful but user object is null.");
      }
    } catch (e) {
      _currentUser = null;
      print("[GameProvider] Signup failed: $e");
      rethrow;
    } finally {
      _authLoading = false;
      notifyListeners();
    }
  }

  Future<void> logoutUser() async {
    print("[GameProvider] Logging out user...");
    if (_hasUnsavedChanges && _currentUser != null) {
      print("[GameProvider] Saving unsaved changes before logout.");
      await _performActualSave();
    }
    try {
      await fb_service.signOut();
      print("[GameProvider] User signed out successfully.");
    } catch (e) {
      print("[GameProvider] Error during sign out: $e");
      rethrow;
    }
  }

  Future<void> changePasswordHandler(String newPassword) async {
    if (_currentUser != null) {
      print(
          "[GameProvider] Attempting to change password for user ${_currentUser!.uid}");
      await fb_service.changePassword(newPassword);
      _hasUnsavedChanges = true;
      notifyListeners();
      print("[GameProvider] Password change successful (client-side).");
    } else {
      throw Exception("No user is currently signed in.");
    }
  }

  Future<void> updateUserDisplayName(String newUsername) async {
    if (_currentUser != null) {
      print(
          "[GameProvider] Updating display name to '$newUsername' for user ${_currentUser!.uid}");
      await _currentUser!.updateDisplayName(newUsername);
      await _currentUser!.reload();
      _currentUser = fb_service.firebaseAuthInstance.currentUser;

      _isUsernameMissing = false;
      _hasUnsavedChanges = true;
      notifyListeners();
      await _performActualSave();
      print("[GameProvider] Display name updated and saved.");
    }
  }

  void setCurrentView(String view) {
    if (_currentView != view) {
      print(
          "[GameProvider] Setting current view from '$_currentView' to '$view'");
      _currentView = view;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void setSelectedTaskId(String? taskId) {
    if (_selectedTaskId != taskId) {
      print(
          "[GameProvider] Setting selected task ID from '$_selectedTaskId' to '$taskId'");
      _selectedTaskId = taskId;
      _hasUnsavedChanges = true;
      notifyListeners();
    }
  }

  void setSettings(GameSettings newSettings) {
    _settings = newSettings;
    _hasUnsavedChanges = true;
    notifyListeners();
    print(
        "[GameProvider] Settings updated. DescriptionsVisible: ${newSettings.descriptionsVisible}, DailyAutoGenerate: ${newSettings.dailyAutoGenerateContent}, Wakeup: ${newSettings.wakeupTimeHour}:${newSettings.wakeupTimeMinute}");
  }

  String romanize(int num) => num.toString(); // Changed to common numbering

  MainTask? getSelectedTask() {
    if (_selectedTaskId == null) {
      return _mainTasks.firstOrNull;
    }
    return _mainTasks.firstWhereOrNull((t) => t.id == _selectedTaskId) ??
        _mainTasks.firstOrNull;
  }

  void _recalculatePlayerLevel() {
    int newLevel = 1;
    double xpAtStartOfLvl = 0;
    while (true) {
      final double xpNeeded =
          helper.xpToNext(newLevel, xpPerLevelBase, xpLevelMultiplier);
      if (_xp >= xpAtStartOfLvl + xpNeeded) {
        xpAtStartOfLvl += xpNeeded;
        newLevel++;
      } else {
        break;
      }
    }
    if (_playerLevel != newLevel) {
      final oldLevel = _playerLevel;
      _playerLevel = newLevel;
      print(
          "[GameProvider] Player level changed from $oldLevel to $_playerLevel. XP: $_xp");
      if (_playerLevel > oldLevel) {
        _handleLevelUpEffect();
      } else {
        _hasUnsavedChanges = true;
        notifyListeners();
      }
    }
  }

  void _handleLevelUpEffect() {
    if (_currentUser == null) return;
    print(
        "[GameProvider] Player leveled up to $_playerLevel! Handling effects.");

    const double strengthIncreasePerLevel = 0.5;
    const double defenseIncreasePerLevel = 0.3;
    const double runicIncreasePerLevel = 0.25;

    _playerGameStats['vitality']!.base = basePlayerGameStats['vitality']!.base +
        ((_playerLevel - 1) * playerEnergyPerLevelVitality);
    _playerGameStats['strength']!.base = basePlayerGameStats['strength']!.base +
        ((_playerLevel - 1) * strengthIncreasePerLevel).roundToDouble();
    _playerGameStats['defense']!.base = basePlayerGameStats['defense']!.base +
        ((_playerLevel - 1) * defenseIncreasePerLevel).roundToDouble();
    _playerGameStats['runic']!.base = basePlayerGameStats['runic']!.base +
        ((_playerLevel - 1) * runicIncreasePerLevel).roundToDouble();

    _updatePlayerStatsFromItemsAndRunes();

    _playerEnergy = calculatedMaxEnergy;
    _currentGame.playerCurrentHp = _playerGameStats['vitality']!.value;

    _currentGame.log = [
      ..._currentGame.log,
      "<span style=\"color:#${(getSelectedTask()?.taskColor ?? AppTheme.fhAccentTealFixed).value.toRadixString(16).substring(2)}\">You feel a surge of power! Level up to $_playerLevel.</span>"
    ];

    _hasUnsavedChanges = true;
    notifyListeners();
  }

  String _generateWeeklySummaryForChatbot() {
    if (_completedByDay.isEmpty) {
      return "No activity logged in the past week to generate a summary.";
    }
    List<String> summaryLines = ["Last Week's Activity Summary:"];
    int totalMinutes = 0;
    int totalSubtasks = 0;
    int totalCheckpoints = 0;
    Map<String, int> mainTaskTimes = {};

    DateTime today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      DateTime dayToConsider = today.subtract(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(dayToConsider);
      if (_completedByDay.containsKey(dateKey)) {
        final dayData = _completedByDay[dateKey] as Map<String, dynamic>;
        final taskTimes = dayData['taskTimes'] as Map<String, dynamic>? ?? {};
        taskTimes.forEach((taskId, time) {
          final taskName =
              _mainTasks.firstWhereOrNull((t) => t.id == taskId)?.name ?? taskId;
          mainTaskTimes[taskName] = (mainTaskTimes[taskName] ?? 0) + (time as int);
          totalMinutes += time;
        });
        totalSubtasks += (dayData['subtasksCompleted'] as List?)?.length ?? 0;
        totalCheckpoints +=
            (dayData['checkpointsCompleted'] as List?)?.length ?? 0;
      }
    }

    if (totalMinutes > 0) {
      summaryLines.add("- Total time logged: $totalMinutes minutes.");
      mainTaskTimes.forEach((taskName, time) {
        summaryLines.add("  - On '$taskName': $time minutes.");
      });
    }
    if (totalSubtasks > 0) {
      summaryLines.add("- Sub-tasks completed: $totalSubtasks.");
    }
    if (totalCheckpoints > 0) {
      summaryLines.add("- Checkpoints cleared: $totalCheckpoints.");
    }
    
    if (summaryLines.length == 1) { // Only the title
      return "No significant activity logged in the past week to generate a summary.";
    }
    return summaryLines.join("\n");
  }


  Future<void> _handleDailyReset() async {
    if (_currentUser == null) return;
    final today = helper.getTodayDateString();
    bool hasResetRun = false;

    if (_lastLoginDate != today) {
      print(
          "[GameProvider] Daily reset triggered. Last login: $_lastLoginDate, Today: $today");
      hasResetRun = true;
      _mainTasks = _mainTasks.map((task) {
        int newStreak = task.streak;
        if (_lastLoginDate != null) {
          final yesterday = DateTime.now().subtract(const Duration(days: 1));
          final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
          if (task.dailyTimeSpent < dailyTaskGoalMinutes &&
              task.lastWorkedDate != null &&
              task.lastWorkedDate != today &&
              task.lastWorkedDate != yesterdayStr) {
            newStreak = 0;
            print(
                "[GameProvider] Task '${task.name}' streak reset due to inactivity.");
          }
        }
        return MainTask(
          id: task.id,
          name: task.name,
          description: task.description,
          theme: task.theme,
          colorHex: task.colorHex,
          streak: newStreak,
          dailyTimeSpent: 0,
          lastWorkedDate: task.lastWorkedDate,
          subTasks: task.subTasks,
        );
      }).toList();

      _playerEnergy = calculatedMaxEnergy;
      _defeatedEnemyIds = []; // Reset defeated enemies for the day
      _clearedLocationIds = []; // Reset cleared locations for the day
      _lastLoginDate = today;
      _hasUnsavedChanges = true; // Mark changes for saving
      scheduleEmotionReminders(); // Re-schedule reminders for the new day
      print(
          "[GameProvider] Daily reset applied. Player energy restored. Streaks updated.");
    }

    if (settings.dailyAutoGenerateContent &&
        hasResetRun) { // Only run auto-gen if a daily reset actually occurred
      print("[GameProvider] Daily auto-generation triggered.");
      String? currentLocationId = _currentGame.currentPlaceKey;
      bool currentRealmPacified = false;

      if (currentLocationId != null) {
        final enemiesInLocation = _enemyTemplatesList
            .where((e) => e.locationKey == currentLocationId)
            .toList();
        if (enemiesInLocation.isNotEmpty &&
            enemiesInLocation.every((e) => _defeatedEnemyIds.contains(e.id))) {
          currentRealmPacified = true;
          print("[GameProvider] Current realm '$currentLocationId' is pacified.");
        }
      }

      if (currentLocationId == null || currentRealmPacified) {
        if (currentLocationId != null && currentRealmPacified) {
          _gameLocationsList.removeWhere((loc) => loc.id == currentLocationId);
          _clearedLocationIds.removeWhere((id) => id == currentLocationId);
          _currentGame.log.add(
              "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">Realm '$currentLocationId' pacified and archived.</span>");
          print("[GameProvider] Pacified realm '$currentLocationId' removed.");
        }

        print(
            "[GameProvider] Generating a new realm due to daily reset or pacified current realm.");
        await _aiGenerationActions.generateGameContent(_playerLevel,
            isManual: false,
            isInitial: false,
            contentType: "locations",
            numLocationsToGenerate:
                1); // generate 1 new location

        // Select the newly generated or first available realm
        if (_gameLocationsList.isNotEmpty) {
          currentLocationId = _gameLocationsList
                  .where((loc) => !_clearedLocationIds.contains(loc.id))
                  .firstOrNull
                  ?.id ??
              _gameLocationsList.first.id;
        } else {
          currentLocationId = null; // No locations available
        }
        _currentGame.currentPlaceKey = currentLocationId;
        _hasUnsavedChanges = true; // Mark changes for saving
      }

      if (currentLocationId != null) {
        print("[GameProvider] Generating new enemies for realm '$currentLocationId'.");
        await _aiGenerationActions.generateGameContent(_playerLevel,
            isManual: false,
            isInitial: false,
            contentType: "enemies",
            numEnemiesToGenerate: 3,
            specificLocationKeyForEnemies:
                currentLocationId); // generate 3 enemies for current/new location
      } else {
        print(
            "[GameProvider] No active realm to populate with new threats after daily reset.");
        _currentGame.log.add(
            "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">No active realm available for new threats.</span>");
      }
    }
    if (hasResetRun) {
      // If a daily reset happened, also refresh chatbot's weekly summary.
      _chatbotMemory.lastWeeklySummary = _generateWeeklySummaryForChatbot();
      _getCompletedGoalsForChatbotMemory();
      setProviderState(chatbotMemory: _chatbotMemory, doNotify: false); // Update chatbot memory without double notification, persist will happen with notifyListeners below
      notifyListeners(); // Notify at the end if any reset or generation happened
    }
  }

  void _updatePlayerStatsFromItemsAndRunes() {
    final Map<String, PlayerStat> newStats = {
      ...Map.from(basePlayerGameStats.map((key, bs) => MapEntry(
          key,
          PlayerStat(
              name: bs.name,
              base: bs.base,
              value: bs.base,
              description: bs.description,
              icon: bs.icon)))),
    };
    _ensureBonusXpModStat();
    if (!newStats.containsKey('bonusXPMod')) {
      newStats['bonusXPMod'] = PlayerStat(
          name: 'XP CALC MOD',
          value: 0,
          base: 0,
          description: 'Internal XP modifier from gear.',
          icon: 'mdi-percent-outline');
    }

    const double strengthIncreasePerLevel = 0.5;
    const double defenseIncreasePerLevel = 0.3;
    const double runicIncreasePerLevel = 0.25;

    newStats['vitality']!.base = basePlayerGameStats['vitality']!.base +
        ((_playerLevel - 1) * playerEnergyPerLevelVitality);
    newStats['strength']!.base = basePlayerGameStats['strength']!.base +
        ((_playerLevel - 1) * strengthIncreasePerLevel).roundToDouble();
    newStats['defense']!.base = basePlayerGameStats['defense']!.base +
        ((_playerLevel - 1) * defenseIncreasePerLevel).roundToDouble();
    newStats['runic']!.base = basePlayerGameStats['runic']!.base +
        ((_playerLevel - 1) * runicIncreasePerLevel).roundToDouble();

    newStats.forEach((key, stat) {
      stat.value = stat.base;
    });

    _equippedItems.forEach((slot, uniqueId) {
      if (uniqueId != null) {
        final owned =
            _artifacts.firstWhereOrNull((art) => art.uniqueId == uniqueId);
        if (owned != null) {
          final template = _artifactTemplatesList
              .firstWhereOrNull((t) => t.id == owned.templateId);
          if (template != null && template.type != 'powerup') {
            final effective = _itemActions.getArtifactEffectiveStats(owned);
            newStats['strength']!.value += effective.baseAtt ?? 0;
            newStats['defense']!.value += effective.baseDef ?? 0;
            newStats['vitality']!.value += effective.baseHealth ?? 0;
            newStats['runic']!.value += effective.baseRunic ?? 0;
            newStats['luck']!.value += effective.baseLuck?.toDouble() ?? 0;
            newStats['cooldown']!.value +=
                effective.baseCooldown?.toDouble() ?? 0;
            newStats['bonusXPMod']!.value += effective.bonusXPMod ?? 0.0;
          }
        }
      }
    });

    _equippedRunes.forEach((slot, uniqueOwnedRuneId) {
      if (uniqueOwnedRuneId != null) {
        final ownedRune = _ownedRunes
            .firstWhereOrNull((or) => or.uniqueId == uniqueOwnedRuneId);
        if (ownedRune != null) {
          final runeTemplate = _runeTemplatesList
              .firstWhereOrNull((rt) => rt.id == ownedRune.runeId);
          if (runeTemplate != null && runeTemplate.type.contains("passive")) {
            if (runeTemplate.effectType == 'stat_boost' &&
                runeTemplate.targetStat != null &&
                newStats.containsKey(runeTemplate.targetStat!)) {
              newStats[runeTemplate.targetStat!]!.value +=
                  runeTemplate.effectValue;
            }
          }
        }
      }
    });

    newStats['luck']!.value =
        newStats['luck']!.value.clamp(0, double.infinity).toDouble();
    newStats['bonusXPMod']!.value =
        newStats['bonusXPMod']!.value.clamp(0, double.infinity).toDouble();

    _playerGameStats = newStats;

    if (_currentGame.playerCurrentHp > _playerGameStats['vitality']!.value) {
      _currentGame.playerCurrentHp = _playerGameStats['vitality']!.value;
    } else if (_currentGame.enemy == null &&
        _currentGame.playerCurrentHp < _playerGameStats['vitality']!.value) {
      _currentGame.playerCurrentHp = _playerGameStats['vitality']!.value;
    }
    print(
        "[GameProvider] Player stats updated. Vitality: ${_playerGameStats['vitality']!.value}, Strength: ${_playerGameStats['strength']!.value}");
  }

  bool isLocationUnlocked(String locationId) {
    final location =
        _gameLocationsList.firstWhereOrNull((loc) => loc.id == locationId);
    if (location == null) {
      print(
          "[GameProvider] isLocationUnlocked: Location ID '$locationId' not found.");
      return false;
    }

    if (_playerLevel < location.minPlayerLevelToUnlock) {
      return false;
    }
    return true;
  }

  Future<void> clearAllGameData() async {
    if (_currentUser == null) return;
    print(
        "[GameProvider] Clearing all game data for user ${_currentUser!.uid}");
    await _storageService.deleteUserData(_currentUser!.uid);
    await _resetToInitialState(); // Make reset async
    // After reset, if daily auto-gen is on, an initial populate will happen.
    if (settings.dailyAutoGenerateContent) {
      print("[GameProvider] Generating initial content after data purge.");
      await _aiGenerationActions.generateGameContent(_playerLevel,
          isManual: false, isInitial: true, contentType: "all");
    }
    await _performActualSave(); // Save the reset (and potentially newly generated) state.
    notifyListeners();
    print("[GameProvider] All game data cleared and reset.");
  }

  Future<void> resetPlayerLevelAndProgress() async {
    if (_currentUser == null) return;
    print("[GameProvider] Resetting player level and progress.");
    _playerLevel = 1;
    _xp = 0;
    _playerGameStats = {
      ...Map.from(basePlayerGameStats.map((key, value) => MapEntry(
          key,
          PlayerStat(
              name: value.name,
              description: value.description,
              icon: value.icon,
              value: value.value,
              base: value.base)))),
    };
    _ensureBonusXpModStat();
    _updatePlayerStatsFromItemsAndRunes();
    _playerEnergy = calculatedMaxEnergy;
    _currentGame.playerCurrentHp = _playerGameStats['vitality']!.value;
    _defeatedEnemyIds = [];
    // No specific content generation here as daily reset handles it.
    _currentGame.log = [
      ..._currentGame.log,
      "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">Player level and progress have been reset.</span>"
    ];
    _hasUnsavedChanges = true;
    notifyListeners();
    print("[GameProvider] Player level and progress reset complete.");
  }

  void clearAllArtifactsAndTemplates() {
    if (_currentUser == null) return;
    print("[GameProvider] Clearing all owned artifacts and templates.");
    setProviderState(
      artifacts: [], // Clear owned artifacts
      artifactTemplatesList: [], // Clear artifact templates
      equippedItems: {
        'weapon': null,
        'armor': null,
        'talisman': null
      }, // Unequip all
      currentGame: CurrentGame(
        enemy: _currentGame.enemy,
        playerCurrentHp: _currentGame.playerCurrentHp,
        log: [
          ..._currentGame.log,
          "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">All artifacts and blueprints purged.</span>"
        ],
        currentPlaceKey: _currentGame.currentPlaceKey,
      ),
    );
  }

  Future<void> removeAllGameLocations() async {
    if (_currentUser == null) return;
    print("[GameProvider] Removing all game locations (realms).");
    setProviderState(
      gameLocationsList: [],
      clearedLocationIds: [],
      defeatedEnemyIds: [], // Also clear defeated enemies as realms are gone
      currentGame: CurrentGame(
        enemy: null, // No active enemy if no realms
        playerCurrentHp: _currentGame.playerCurrentHp,
        log: [
          ..._currentGame.log,
          "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">All combat realms decommissioned. The Arena is now empty.</span>"
        ],
        currentPlaceKey: null, // No current place
      ),
    );
  }

  Future<void> clearDiscoverablePowerUps() async {
    if (_currentUser == null) return;
    print("[GameProvider] Clearing discoverable power-ups.");
    final List<String> ownedPowerUpTemplateIds = _artifacts
        .where((owned) {
          final template = _artifactTemplatesList
              .firstWhereOrNull((t) => t.id == owned.templateId);
          return template != null && template.type == 'powerup';
        })
        .map((owned) => owned.templateId)
        .toSet()
        .toList();

    final List<ArtifactTemplate> newArtifactTemplates =
        _artifactTemplatesList.where((template) {
      return template.type != 'powerup' ||
          ownedPowerUpTemplateIds.contains(template.id);
    }).toList();

    setProviderState(
        artifactTemplatesList: newArtifactTemplates,
        currentGame: CurrentGame(
          enemy: _currentGame.enemy,
          playerCurrentHp: _currentGame.playerCurrentHp,
          log: [
            ..._currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">Discoverable power-up schematics purged. Owned items remain.</span>"
          ],
          currentPlaceKey: _currentGame.currentPlaceKey,
        ));
  }

  Future<void> removeAllEnemyTemplates() async {
    if (_currentUser == null) return;
    print("[GameProvider] Removing all enemy templates.");
    setProviderState(
        enemyTemplatesList: [],
        currentGame: CurrentGame(
          enemy: _currentGame.enemy,
          playerCurrentHp: _currentGame.playerCurrentHp,
          log: [
            ..._currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">All enemy intelligence wiped from the database.</span>"
          ],
          currentPlaceKey: _currentGame.currentPlaceKey,
        ));
  }

  void deleteGameLocation(String locationId) {
    final newLocations =
        _gameLocationsList.where((loc) => loc.id != locationId).toList();
    final newClearedIds =
        _clearedLocationIds.where((id) => id != locationId).toList();
    String? newCurrentPlaceKey = _currentGame.currentPlaceKey;
    if (newCurrentPlaceKey == locationId) {
      newCurrentPlaceKey =
          newLocations.isNotEmpty ? newLocations.first.id : null;
    }

    setProviderState(
        gameLocationsList: newLocations,
        clearedLocationIds: newClearedIds,
        currentGame: CurrentGame(
          enemy: _currentGame.currentPlaceKey == locationId
              ? null
              : _currentGame.enemy, // Clear enemy if it was in deleted location
          playerCurrentHp: _currentGame.playerCurrentHp,
          log: [
            ..._currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">Realm '${_gameLocationsList.firstWhereOrNull((l) => l.id == locationId)?.name ?? locationId}' has been destabilized and removed.</span>"
          ],
          currentPlaceKey: newCurrentPlaceKey,
        ));
  }

  void markLocationAsCleared(String locationId) {
    final newLocations = _gameLocationsList.map((loc) {
      if (loc.id == locationId) {
        return GameLocation(
          id: loc.id,
          name: loc.name,
          description: loc.description,
          minPlayerLevelToUnlock: loc.minPlayerLevelToUnlock,
          iconEmoji: loc.iconEmoji,
          associatedTheme: loc.associatedTheme,
          bossEnemyIdToUnlockNextLocation: loc.bossEnemyIdToUnlockNextLocation,
          isCleared: true, // Mark as cleared
        );
      }
      return loc;
    }).toList();

    final newClearedLocationIds = List<String>.from(_clearedLocationIds)
      ..add(locationId);

    setProviderState(
        gameLocationsList: newLocations,
        clearedLocationIds: newClearedLocationIds,
        currentGame: CurrentGame(
          enemy: _currentGame.enemy, // Keep current enemy if any
          playerCurrentHp: currentGame.playerCurrentHp,
          log: [
            ...currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentGreen.value.toRadixString(16).substring(2)};\">Zone '${_gameLocationsList.firstWhereOrNull((loc) => loc.id == locationId)?.name ?? locationId}' has been pacified!</span>"
          ],
          currentPlaceKey: currentGame.currentPlaceKey,
        ));
  }

  // Emotion Logging
  List<EmotionLog> getEmotionLogsForDate(String date) {
    final dayData = _completedByDay[date] as Map<String, dynamic>?;
    if (dayData == null || dayData['emotionLogs'] == null) {
      return [];
    }
    return (dayData['emotionLogs'] as List<dynamic>)
        .map((logJson) => EmotionLog.fromJson(logJson as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void logEmotion(String date, int rating, [DateTime? customTimestamp]) {
    final timestamp = customTimestamp ?? DateTime.now();
    final emotionLog = EmotionLog(timestamp: timestamp, rating: rating);

    final newCompletedByDay = Map<String, dynamic>.from(_completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ??
        {
          'taskTimes': <String, int>{},
          'subtasksCompleted': <Map<String, dynamic>>[],
          'checkpointsCompleted': <Map<String, dynamic>>[],
          'emotionLogs': <Map<String, dynamic>>[]
        });

    final emotionLogsList =
        List<Map<String, dynamic>>.from(dayData['emotionLogs'] as List? ?? []);

    if (emotionLogsList.length >= 10) {
      // emotionLogsList is already sorted by timestamp in getEmotionLogsForDate, and new logs are added to keep sort
      emotionLogsList.removeAt(0); // Remove the oldest
    }
    emotionLogsList.add(emotionLog.toJson());
    // Ensure it remains sorted after adding
    emotionLogsList.sort(
        (a, b) => (a['timestamp'] as String).compareTo(b['timestamp'] as String));

    dayData['emotionLogs'] = emotionLogsList;
    newCompletedByDay[date] = dayData;

    setProviderState(completedByDay: newCompletedByDay);
    _currentGame.log.add(
        "<span style='color:${AppTheme.fhAccentPurple.value.toRadixString(16).substring(2)};'>Emotion logged: $rating/5 for $date.</span>");
    notifyListeners(); // Ensure UI updates for new log
  }

  void deleteLatestEmotionLog(String date) {
    final currentLogs = getEmotionLogsForDate(date);
    if (currentLogs.isEmpty) return;

    final newCompletedByDay = Map<String, dynamic>.from(_completedByDay);
    final dayData = Map<String, dynamic>.from(newCompletedByDay[date] ?? {});
    final emotionLogsList =
        List<Map<String, dynamic>>.from(dayData['emotionLogs'] as List? ?? []);

    if (emotionLogsList.isNotEmpty) {
      emotionLogsList.removeLast(); // Assumes logs are always sorted, last one is latest
    }

    dayData['emotionLogs'] = emotionLogsList;
    newCompletedByDay[date] = dayData;

    setProviderState(completedByDay: newCompletedByDay);
    _currentGame.log.add(
        "<span style='color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)};'>Latest emotion log for $date deleted.</span>");
    notifyListeners(); // Ensure UI updates
  }

  void setWakeupTime(TimeOfDay newTime) {
    _settings.wakeupTimeHour = newTime.hour;
    _settings.wakeupTimeMinute = newTime.minute;
    setSettings(_settings); // This will notify and mark for save
    scheduleEmotionReminders(); // Re-schedule on change
  }

  List<DateTime> calculateNotificationTimes() {
    final now = DateTime.now();
    final wakeupDateTime = DateTime(
        now.year, now.month, now.day, wakeupTime.hour, wakeupTime.minute);
    const int loggingDurationMinutes = 16 * 60;
    const int numberOfLogs = 10;
    final int intervalMinutes =
        (loggingDurationMinutes / (numberOfLogs - 1)).floor();

    List<DateTime> times = [];
    DateTime currentTime = wakeupDateTime;

    for (int i = 0; i < numberOfLogs; i++) {
      times.add(currentTime);
      currentTime = currentTime.add(Duration(minutes: intervalMinutes));
    }
    // Filter times that are in the past relative to 'now' for today's reminders.
    // For future days, all 10 times would be valid.
    if (now.day == wakeupDateTime.day) {
      return times.where((t) => t.isAfter(now)).toList();
    }
    return times; // For future days, return all calculated times
  }

  void scheduleEmotionReminders() {
    // Placeholder for actual notification scheduling
    // This would involve using a plugin like flutter_local_notifications
    // E.g., flutterLocalNotificationsPlugin.cancelAll();
    // List<DateTime> notificationTimes = calculateNotificationTimes();
    // for (var time in notificationTimes) {
    //   if (time.isAfter(DateTime.now())) {
    //     flutterLocalNotificationsPlugin.zonedSchedule(...);
    //   }
    // }
    if (kDebugMode) {
      print(
          "[GameProvider] Conceptual: Would schedule notifications for: ${calculateNotificationTimes().map((t) => DateFormat('HH:mm').format(t)).join(', ')}");
    }
  }

  Future<void> resetParkData() async {
    if (_currentUser == null) return;
    print("[GameProvider] Resetting park data for user ${_currentUser!.uid}");

    setProviderState(
        ownedBuildings: [],
        ownedDinosaurs: [],
        fossilRecords: _dinosaurSpeciesList
            .map((species) => FossilRecord(speciesId: species.id))
            .toList(),
        parkManager: ParkManager(
          parkDollars: 50000,
          parkEnergy: _playerEnergy,
          maxParkEnergy: calculatedMaxEnergy,
        ),
        currentGame: CurrentGame(
          enemy: _currentGame.enemy,
          playerCurrentHp: _currentGame.playerCurrentHp,
          log: [
            ..._currentGame.log,
            "<span style=\"color:${AppTheme.fhAccentOrange.value.toRadixString(16).substring(2)}\">Jurassic Park systems reset. All assets and progress within the park have been purged.</span>"
          ],
          currentPlaceKey: _currentGame.currentPlaceKey,
        ),
        doPersist: false, // Save will be handled by _performActualSave
        doNotify: false // Notify will be handled by _performActualSave
        );

    await _performActualSave(); // Persist the reset park state
    notifyListeners(); // Notify listeners after save
    print("[GameProvider] Park data reset and saved.");
  }


  String _generateWeeklySummary() {
    if (_completedByDay.isEmpty) {
      return "No activity logged in the past week to generate a summary.";
    }
    List<String> summaryLines = ["Last Week's Activity Summary:"];
    int totalMinutes = 0;
    int totalSubtasks = 0;
    int totalCheckpoints = 0;
    Map<String, int> mainTaskTimes = {};

    DateTime today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      DateTime dayToConsider = today.subtract(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(dayToConsider);
      if (_completedByDay.containsKey(dateKey)) {
        final dayData = _completedByDay[dateKey] as Map<String, dynamic>;
        final taskTimes = dayData['taskTimes'] as Map<String, dynamic>? ?? {};
        taskTimes.forEach((taskId, time) {
          final taskName =
              _mainTasks.firstWhereOrNull((t) => t.id == taskId)?.name ?? taskId;
          mainTaskTimes[taskName] = (mainTaskTimes[taskName] ?? 0) + (time as int);
          totalMinutes += time;
        });
        totalSubtasks += (dayData['subtasksCompleted'] as List?)?.length ?? 0;
        totalCheckpoints +=
            (dayData['checkpointsCompleted'] as List?)?.length ?? 0;
      }
    }

    if (totalMinutes > 0) {
      summaryLines.add("- Total time logged: $totalMinutes minutes.");
      mainTaskTimes.forEach((taskName, time) {
        summaryLines.add("  - On '$taskName': $time minutes.");
      });
    }
    if (totalSubtasks > 0) {
      summaryLines.add("- Sub-tasks completed: $totalSubtasks.");
    }
    if (totalCheckpoints > 0) {
      summaryLines.add("- Checkpoints cleared: $totalCheckpoints.");
    }
    
    if (summaryLines.length == 1) { // Only the title
      return "No significant activity logged in the past week to generate a summary.";
    }
    return summaryLines.join("\n");
  }


  void _getCompletedGoalsForChatbotMemory() {
    List<String> goals = [];
    DateTime today = DateTime.now();
    // Look at past 7 days for completed tasks/subtasks
    for (int i = 0; i < 7; i++) {
        DateTime dayToConsider = today.subtract(Duration(days: i));
        String dateKey = DateFormat('yyyy-MM-dd').format(dayToConsider);
        if (_completedByDay.containsKey(dateKey)) {
            final dayData = _completedByDay[dateKey] as Map<String, dynamic>;
            final subtasks = dayData['subtasksCompleted'] as List<dynamic>? ?? [];
            for (var subtaskMap in subtasks) {
                if (subtaskMap is Map<String, dynamic>) {
                    String parentTaskName = mainTasks.firstWhereOrNull((t) => t.id == subtaskMap['parentTaskId'])?.name ?? "Unknown Quest";
                    goals.add("Completed sub-task '${subtaskMap['name']}' for '$parentTaskName' on $dateKey.");
                }
            }
            final checkpoints = dayData['checkpointsCompleted'] as List<dynamic>? ?? [];
             for (var checkpointMap in checkpoints) {
                if (checkpointMap is Map<String, dynamic>) {
                    goals.add("Completed checkpoint '${checkpointMap['name']}' for '${checkpointMap['parentSubtaskName']}' on $dateKey.");
                }
            }
        }
    }
    // Limit to most recent N goals to keep memory manageable
    _chatbotMemory.dailyCompletedGoals = goals.take(10).toList();
  }

  void initializeChatbotMemory() {
    if (_isChatbotMemoryInitialized) return;
    _chatbotMemory.lastWeeklySummary = _generateWeeklySummary();
    _getCompletedGoalsForChatbotMemory();
    if (_chatbotMemory.conversationHistory.isEmpty) {
       _chatbotMemory.conversationHistory.add(ChatbotMessage(
          id: 'init_${DateTime.now().millisecondsSinceEpoch}',
          text: "Hello! I am Arcane Advisor. How can I assist you with your mission logs or goals today?",
          sender: MessageSender.bot,
          timestamp: DateTime.now()));
    }
    _isChatbotMemoryInitialized = true;
    print("[GameProvider] Chatbot memory initialized/refreshed.");
    notifyListeners();
  }

  Future<void> sendMessageToChatbot(String userMessageText) async {
    if (!_isChatbotMemoryInitialized) initializeChatbotMemory();

    final userMessage = ChatbotMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: userMessageText,
        sender: MessageSender.user,
        timestamp: DateTime.now());

    _chatbotMemory.conversationHistory.add(userMessage);
    if (_chatbotMemory.conversationHistory.length > 20) { // Keep history limited
      _chatbotMemory.conversationHistory.removeAt(0);
    }

    // Handle "Remember" command
    if (userMessageText.toLowerCase().startsWith("remember:")) {
      final itemToRemember = userMessageText.substring("remember:".length).trim();
      if (itemToRemember.isNotEmpty) {
        _chatbotMemory.userRememberedItems.add(itemToRemember);
        if(_chatbotMemory.userRememberedItems.length > 10) { // Limit remembered items
            _chatbotMemory.userRememberedItems.removeAt(0);
        }
        final botResponse = ChatbotMessage(
            id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
            text: "Okay, I will remember: \"$itemToRemember\"",
            sender: MessageSender.bot,
            timestamp: DateTime.now());
        _chatbotMemory.conversationHistory.add(botResponse);
        setProviderState(chatbotMemory: _chatbotMemory); // Persist memory
        return;
      }
    }
     if (userMessageText.toLowerCase().startsWith("forget last") || userMessageText.toLowerCase().startsWith("forget everything")) {
        bool forgetEverything = userMessageText.toLowerCase().startsWith("forget everything");
        String responseText;
        if (forgetEverything) {
            _chatbotMemory.userRememberedItems.clear();
            responseText = "Okay, I've cleared all previously remembered items.";
        } else if (_chatbotMemory.userRememberedItems.isNotEmpty) {
            String forgottenItem = _chatbotMemory.userRememberedItems.removeLast();
            responseText = "Okay, I've forgotten: \"$forgottenItem\"";
        } else {
            responseText = "I don't have any specific items I was asked to remember right now.";
        }
         final botResponse = ChatbotMessage(
            id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
            text: responseText,
            sender: MessageSender.bot,
            timestamp: DateTime.now());
        _chatbotMemory.conversationHistory.add(botResponse);
        setProviderState(chatbotMemory: _chatbotMemory); // Persist memory
        return;
    }


    notifyListeners(); // Show user message immediately

    try {
      final botResponseText = await _aiService.getChatbotResponse(
        memory: _chatbotMemory,
        userMessage: userMessageText,
        currentApiKeyIndex: _apiKeyIndex,
        onNewApiKeyIndex: (newIndex) => _apiKeyIndex = newIndex,
        onLog: (logMsg) => _currentGame.log.add(logMsg),
      );
      final botMessage = ChatbotMessage(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          text: botResponseText,
          sender: MessageSender.bot,
          timestamp: DateTime.now());
      _chatbotMemory.conversationHistory.add(botMessage);
    } catch (e) {
      final errorMessage = ChatbotMessage(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          text: "I'm having trouble connecting right now. Please try again later.",
          sender: MessageSender.bot,
          timestamp: DateTime.now());
      _chatbotMemory.conversationHistory.add(errorMessage);
    }
    
    setProviderState(chatbotMemory: _chatbotMemory); // Persist memory including bot response
  }


  // Delegated methods
  Future<void> generateGameContent(int level,
          {bool isManual = false,
          bool isInitial = false,
          String contentType = "all",
          int numLocationsToGenerate = 0, // Added for specific requests
          int numEnemiesToGenerate = 0, // Added
          String? specificLocationKeyForEnemies // Added
          }) =>
      _aiGenerationActions.generateGameContent(level,
          isManual: isManual,
          isInitial: isInitial,
          contentType: contentType,
          numLocationsToGenerate: numLocationsToGenerate,
          numEnemiesToGenerate: numEnemiesToGenerate,
          specificLocationKeyForEnemies: specificLocationKeyForEnemies);

  void addMainTask(
          {required String name,
          required String description,
          required String theme,
          required String colorHex}) =>
      _taskActions.addMainTask(
          name: name,
          description: description,
          theme: theme,
          colorHex: colorHex);
  void editMainTask(String taskId,
          {required String name,
          required String description,
          required String theme,
          required String colorHex}) =>
      _taskActions.editMainTask(taskId,
          name: name,
          description: description,
          theme: theme,
          colorHex: colorHex);
  void logToDailySummary(String type, Map<String, dynamic> data) =>
      _taskActions.logToDailySummary(type, data);
  String addSubtask(String mainTaskId, Map<String, dynamic> subtaskData) =>
      _taskActions.addSubtask(mainTaskId, subtaskData);
  void updateSubtask(
          String mainTaskId, String subtaskId, Map<String, dynamic> updates) =>
      _taskActions.updateSubtask(mainTaskId, subtaskId, updates);
  bool completeSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.completeSubtask(mainTaskId, subtaskId);
  void deleteSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.deleteSubtask(mainTaskId, subtaskId);
  void duplicateCompletedSubtask(String mainTaskId, String subtaskId) =>
      _taskActions.duplicateCompletedSubtask(mainTaskId, subtaskId);
  void addSubSubtask(String mainTaskId, String parentSubtaskId,
          Map<String, dynamic> subSubtaskData) =>
      _taskActions.addSubSubtask(mainTaskId, parentSubtaskId, subSubtaskData);
  void updateSubSubtask(String mainTaskId, String parentSubtaskId,
          String subSubtaskId, Map<String, dynamic> updates) =>
      _taskActions.updateSubSubtask(
          mainTaskId, parentSubtaskId, subSubtaskId, updates);
  void completeSubSubtask(
          String mainTaskId, String parentSubtaskId, String subSubtaskId) =>
      _taskActions.completeSubSubtask(
          mainTaskId, parentSubtaskId, subSubtaskId);
  void deleteSubSubtask(
          String mainTaskId, String parentSubtaskId, String subSubtaskId) =>
      _taskActions.deleteSubSubtask(mainTaskId, parentSubtaskId, subSubtaskId);

  OwnedArtifact? getArtifactByUniqueId(String uniqueId) =>
      _itemActions.getArtifactByUniqueId(uniqueId);
  ArtifactTemplate? getArtifactTemplateById(String templateId) =>
      _itemActions.getArtifactTemplateById(templateId);
  ArtifactTemplate getArtifactEffectiveStats(OwnedArtifact ownedArtifact) =>
      _itemActions.getArtifactEffectiveStats(ownedArtifact);
  void buyArtifact(String templateId) => _itemActions.buyArtifact(templateId);
  bool upgradeArtifact(String uniqueId) =>
      _itemActions.upgradeArtifact(uniqueId);
  bool sellArtifact(String uniqueId) => _itemActions.sellArtifact(uniqueId);
  void equipArtifact(String uniqueId) => _itemActions.equipArtifact(uniqueId);
  void unequipArtifact(String slot) => _itemActions.unequipArtifact(slot);
  void acquireRune(String runeId) {
    print("[GameProvider] Placeholder: Acquire Rune $runeId");
    notifyListeners();
  }

  void equipRune(String ownedRuneUniqueId, String slot) {
    print("[GameProvider] Placeholder: Equip Rune $ownedRuneUniqueId to $slot");
    _updatePlayerStatsFromItemsAndRunes();
    notifyListeners();
  }

  void unequipRune(String slot) {
    print("[GameProvider] Placeholder: Unequip Rune from $slot");
    _updatePlayerStatsFromItemsAndRunes();
    notifyListeners();
  }

  void startGame(String enemyId) => _combatActions.startGame(enemyId);
  void handleFight() => _combatActions.handleFight();
  void usePowerUp(String uniqueId) => _combatActions.usePowerUp(uniqueId);
  void forfeitMatch() => _combatActions.forfeitMatch();
  void checkAndClearLocationIfAllEnemiesDefeated(String locationId) =>
      _combatActions.checkAndClearLocationIfAllEnemiesDefeated(locationId);

  Future<void> triggerAISubquestGeneration(MainTask mainTask,
          String generationMode, String userInput, int numSubquests) =>
      _aiGenerationActions.triggerAISubquestGeneration(
          mainTask, generationMode, userInput, numSubquests);

  void startTimer(String id, String type, String mainTaskId) =>
      _timerActions.startTimer(id, type, mainTaskId);
  void pauseTimer(String id) => _timerActions.pauseTimer(id);
  void logTimerAndReset(String id) => _timerActions.logTimerAndReset(id);

  // Park Actions Delegation
  bool canAffordBuilding(BuildingTemplate buildingTemplate) =>
      _parkActions.canAffordBuilding(buildingTemplate);
  void buyAndPlaceBuilding(String buildingTemplateId) =>
      _parkActions.buyAndPlaceBuilding(buildingTemplateId);
  void sellBuilding(String ownedBuildingUniqueId) =>
      _parkActions.sellBuilding(ownedBuildingUniqueId);
  void excavateFossil(String speciesId) =>
      _parkActions.excavateFossil(speciesId);
  void incubateDinosaur(String speciesId) =>
      _parkActions.incubateDinosaur(speciesId);
  void addDinosaurToEnclosure(
          String dinosaurUniqueId, String enclosureUniqueId) =>
      _parkActions.addDinosaurToEnclosure(dinosaurUniqueId, enclosureUniqueId);
  void feedDinosaursInEnclosure(String enclosureUniqueId, int amount) =>
      _parkActions.feedDinosaursInEnclosure(enclosureUniqueId, amount);
  void toggleBuildingOperationalStatus(String ownedBuildingUniqueId) =>
      _parkActions.toggleBuildingOperationalStatus(ownedBuildingUniqueId);
  void skipOneMinute() =>
      _parkActions.skipOneMinute(); // New skip minute method

  void setProviderState({
    String? lastLoginDate,
    double? coins,
    double? xp,
    double? playerEnergy,
    List<MainTask>? mainTasks,
    Map<String, dynamic>? completedByDay,
    List<OwnedArtifact>? artifacts,
    List<ArtifactTemplate>? artifactTemplatesList,
    List<EnemyTemplate>? enemyTemplatesList,
    List<GameLocation>? gameLocationsList,
    List<Rune>? runeTemplatesList,
    List<OwnedRune>? ownedRunes,
    Map<String, PlayerStat>? playerGameStats,
    Map<String, String?>? equippedItems,
    Map<String, String?>? equippedRunes,
    List<String>? defeatedEnemyIds,
    List<String>? clearedLocationIds, // Add for setProviderState
    CurrentGame? currentGame,
    Map<String, ActiveTimerInfo>? activeTimers,
    DateTime? lastSuccessfulSaveTimestamp,
    bool? isUsernameMissing,
    // Park Management
    List<DinosaurSpecies>? dinosaurSpeciesList,
    List<BuildingTemplate>? buildingTemplatesList,
    List<OwnedBuilding>? ownedBuildings,
    List<OwnedDinosaur>? ownedDinosaurs,
    List<FossilRecord>? fossilRecords,
    ParkManager? parkManager,
    // Chatbot
    ChatbotMemory? chatbotMemory,
    bool doNotify = true,
    bool doPersist = true,
  }) {
    bool changed = false;
    int oldLevel = _playerLevel;

    if (lastLoginDate != null && _lastLoginDate != lastLoginDate) {
      _lastLoginDate = lastLoginDate;
      changed = true;
    }
    if (coins != null && _coins != coins) {
      _coins = coins;
      changed = true;
    }

    if (xp != null && _xp != xp) {
      _xp = xp;
      _recalculatePlayerLevel();
      changed = true;
    }

    if (playerEnergy != null && _playerEnergy != playerEnergy) {
      _playerEnergy = playerEnergy.clamp(0, calculatedMaxEnergy);
      changed = true;
    }

    // For lists and maps, ensure a change is detected if the reference changes or content changes
    if (mainTasks != null && !listEquals(_mainTasks, mainTasks)) {
      _mainTasks =
          List.from(mainTasks); // Create new list to ensure change detection
      changed = true;
    }
    if (completedByDay != null && !mapEquals(_completedByDay, completedByDay)) {
      _completedByDay = Map.from(completedByDay);
      changed = true;
    }

    bool itemsOrRunesOrEquippedChanged = false;
    if (artifacts != null && !listEquals(_artifacts, artifacts)) {
      _artifacts = List.from(artifacts);
      itemsOrRunesOrEquippedChanged = true;
      changed = true;
    }
    if (artifactTemplatesList != null &&
        !listEquals(_artifactTemplatesList, artifactTemplatesList)) {
      _artifactTemplatesList = List.from(artifactTemplatesList);
      changed = true;
    }
    if (enemyTemplatesList != null &&
        !listEquals(_enemyTemplatesList, enemyTemplatesList)) {
      _enemyTemplatesList = List.from(enemyTemplatesList);
      changed = true;
    }
    if (gameLocationsList != null &&
        !listEquals(_gameLocationsList, gameLocationsList)) {
      _gameLocationsList = List.from(gameLocationsList);
      changed = true;
    }
    if (clearedLocationIds != null &&
        !listEquals(_clearedLocationIds, clearedLocationIds)) {
      _clearedLocationIds = List.from(clearedLocationIds);
      changed = true;
    }
    if (runeTemplatesList != null &&
        !listEquals(_runeTemplatesList, runeTemplatesList)) {
      _runeTemplatesList = List.from(runeTemplatesList);
      changed = true;
    }
    if (ownedRunes != null && !listEquals(_ownedRunes, ownedRunes)) {
      _ownedRunes = List.from(ownedRunes);
      itemsOrRunesOrEquippedChanged = true;
      changed = true;
    }

    if (playerGameStats != null &&
        !mapEquals(_playerGameStats, playerGameStats)) {
      playerGameStats.forEach((key, newStat) {
        if (_playerGameStats.containsKey(key)) {
          _playerGameStats[key]!.base = newStat.base;
          _playerGameStats[key]!.value =
              newStat.value; // Ensure value is also updated
        } else {
          _playerGameStats[key] = newStat;
        }
      });
      _ensureBonusXpModStat();
      itemsOrRunesOrEquippedChanged = true;
      changed = true;
    }

    if (equippedItems != null && !mapEquals(_equippedItems, equippedItems)) {
      _equippedItems = Map.from(equippedItems);
      itemsOrRunesOrEquippedChanged = true;
      changed = true;
    }
    if (equippedRunes != null && !mapEquals(_equippedRunes, equippedRunes)) {
      _equippedRunes = Map.from(equippedRunes);
      itemsOrRunesOrEquippedChanged = true;
      changed = true;
    }

    if (itemsOrRunesOrEquippedChanged || oldLevel != _playerLevel) {
      _updatePlayerStatsFromItemsAndRunes();
    }

    if (defeatedEnemyIds != null &&
        !listEquals(_defeatedEnemyIds, defeatedEnemyIds)) {
      _defeatedEnemyIds = List.from(defeatedEnemyIds);
      changed = true;
    }
    if (currentGame != null && _currentGame != currentGame) {
      // This comparison might need to be deeper
      _currentGame = currentGame; // Assume currentGame is a new instance
      if (_playerGameStats['vitality'] != null &&
          _currentGame.playerCurrentHp > _playerGameStats['vitality']!.value) {
        _currentGame.playerCurrentHp = _playerGameStats['vitality']!.value;
      }
      changed = true;
    }
    if (activeTimers != null && !mapEquals(_activeTimers, activeTimers)) {
      _activeTimers = Map.from(activeTimers);
      changed = true;
    }
    if (lastSuccessfulSaveTimestamp != null &&
        _lastSuccessfulSaveTimestamp != lastSuccessfulSaveTimestamp) {
      _lastSuccessfulSaveTimestamp = lastSuccessfulSaveTimestamp;
      changed = true;
    }
    if (isUsernameMissing != null && _isUsernameMissing != isUsernameMissing) {
      _isUsernameMissing = isUsernameMissing;
      changed = true;
    }

    // Park Management State Updates
    if (dinosaurSpeciesList != null &&
        !listEquals(_dinosaurSpeciesList, dinosaurSpeciesList)) {
      _dinosaurSpeciesList = List.from(dinosaurSpeciesList);
      changed = true;
    }
    if (buildingTemplatesList != null &&
        !listEquals(_buildingTemplatesList, buildingTemplatesList)) {
      _buildingTemplatesList = List.from(buildingTemplatesList);
      changed = true;
    }
    if (ownedBuildings != null &&
        !listEquals(_ownedBuildings, ownedBuildings)) {
      _ownedBuildings = List.from(ownedBuildings);
      changed = true;
    }
    if (ownedDinosaurs != null &&
        !listEquals(_ownedDinosaurs, ownedDinosaurs)) {
      _ownedDinosaurs = List.from(ownedDinosaurs);
      changed = true;
    }
    if (fossilRecords != null && !listEquals(_fossilRecords, fossilRecords)) {
      _fossilRecords = List.from(fossilRecords);
      changed = true;
    }
    if (parkManager != null && _parkManager != parkManager) {
      // Simple comparison, might need deep compare if ParkManager becomes complex
      _parkManager = parkManager;
      // When ParkManager state is updated, ensure player energy is consistent if used for park ops
      if (_parkManager.parkEnergy != _playerEnergy ||
          _parkManager.maxParkEnergy != calculatedMaxEnergy) {
        _parkManager.parkEnergy = _playerEnergy;
        _parkManager.maxParkEnergy = calculatedMaxEnergy;
      }
      changed = true;
    }
    // Chatbot state update
    if (chatbotMemory != null && _chatbotMemory != chatbotMemory) {
      _chatbotMemory = chatbotMemory;
      changed = true;
    }

    if (changed) {
      if (kDebugMode && doNotify) {
        print(
            "[GameProvider] setProviderState detected changes, will notify. Persist: $doPersist.");
      }
      if (doPersist) _hasUnsavedChanges = true;
      if (doNotify) notifyListeners();
    }
  }

  void setProviderAIGlobalLoading(bool isLoading,
      {double progress = 0.0, String statusMessage = ""}) {
    bool changed = false;
    if (_isGeneratingGlobalContent != isLoading) {
      _isGeneratingGlobalContent = isLoading;
      changed = true;
    }
    if (_aiGenerationProgress != progress) {
      _aiGenerationProgress = progress;
      changed = true;
    }
    if (_aiGenerationStatusMessage != statusMessage) {
      _aiGenerationStatusMessage = statusMessage;
      changed = true;
    }
    if (changed) {
      print(
          "[GameProvider] AI Global Loading set to: $isLoading, Progress: $progress, Message: $statusMessage");
      notifyListeners();
    }
  }

  void setProviderAISubquestLoading(bool isLoading) {
    if (_isGeneratingSubquestsForTask != isLoading) {
      _isGeneratingSubquestsForTask = isLoading;
      print("[GameProvider] AI Subquest Loading set to: $isLoading");
      notifyListeners();
    }
  }

  void setProviderApiKeyIndex(int index) {
    if (_apiKeyIndex != index) {
      _apiKeyIndex = index;
      print("[GameProvider] API Key Index set to: $index");
      // No need to notify listeners for this internal state unless UI depends on it directly
    }
  }
}