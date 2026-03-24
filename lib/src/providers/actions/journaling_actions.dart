import 'package:flutter/foundation.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class JournalingActions {
  final AppProvider _provider;

  JournalingActions(this._provider);

  String _getLogsText() {
    return _provider.reflectionLogs
        .map((l) => "[${l.timestamp.toIso8601String()}] ${l.trigger}: ${l.emotion} - ${l.reason}")
        .join('\n');
  }

  Future<void> extractAndSavePeople() async {
    final logsText = _getLogsText();
    if (logsText.isEmpty) return;

    _provider.setLoadingTask("Extracting Entities...");

    try {
      // Intentionally using liteModels for extraction per prompt instructions
      final results = await _provider.aiService.extractPeopleFromReflections(
        logsText: logsText,
        modelCandidates: _provider.settings.liteModels, 
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[PeopleExtraction] $msg"),
      );

      final currentPeople = List<PersonInfo>.from(_provider.chatbotMemory.people);

      for (var data in results) {
        final name = data['name'] as String?;
        final relation = data['relation'] as String?;
        if (name == null || name.isEmpty) continue;

        final existingIndex = currentPeople.indexWhere((p) => p.name.toLowerCase() == name.toLowerCase());
        if (existingIndex != -1) {
          if (relation != null) {
            currentPeople[existingIndex].relation = relation;
          }
        } else {
          currentPeople.add(PersonInfo(
            id: const Uuid().v4(),
            name: name,
            relation: relation ?? 'Acquaintance',
          ));
        }
      }

      _provider.chatbotMemory.people = currentPeople;
      _provider.markDirty('settings');
      _provider.scheduleRealtimeSync();
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      _provider.notifyListeners();

    } catch (e) {
      debugPrint("Error extracting people: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  Future<void> extractAndSaveAssets() async {
    final logsText = _getLogsText();
    if (logsText.isEmpty) return;

    _provider.setLoadingTask("Extracting Assets...");

    try {
      final results = await _provider.aiService.extractAssetsFromReflections(
        logsText: logsText,
        modelCandidates: _provider.settings.heavyModels, 
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[AssetExtraction] $msg"),
      );

      final currentAssets = List<GratitudeItem>.from(_provider.chatbotMemory.gratitudeList);
      bool changed = false;

      for (var data in results) {
        final name = data['name'] as String?;
        final type = data['type'] as String? ?? 'resource';
        final why = data['why'] as String? ?? '';
        final what = data['what'] as String? ?? '';
        if (name == null || name.isEmpty) continue;

        final existingIdx = currentAssets.indexWhere((a) => a.name.toLowerCase() == name.toLowerCase());
        if (existingIdx != -1) {
          if (why.isNotEmpty && !currentAssets[existingIdx].why.contains(why)) {
            currentAssets[existingIdx].why += (currentAssets[existingIdx].why.isEmpty ? "" : " ") + why;
            changed = true;
          }
          if (what.isNotEmpty && !currentAssets[existingIdx].what.contains(what)) {
             currentAssets[existingIdx].what += (currentAssets[existingIdx].what.isEmpty ? "" : " ") + what;
             changed = true;
          }
        } else {
          currentAssets.insert(0, GratitudeItem(
            id: const Uuid().v4(),
            type: type,
            name: name,
            why: why,
            what: what,
          ));
          changed = true;
        }
      }

      if (changed) {
        _provider.updateGratitudeList(currentAssets);
        _provider.scheduleRealtimeSync();
      }

    } catch (e) {
      debugPrint("Error extracting assets: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  Future<void> generatePersonDetails(String personId) async {
    final personIndex = _provider.chatbotMemory.people.indexWhere((p) => p.id == personId);
    if (personIndex == -1) return;

    final person = _provider.chatbotMemory.people[personIndex];
    final logsText = _getLogsText();

    _provider.setLoadingTask("Analyzing Profile...");

    try {
      final result = await _provider.aiService.generatePersonDetails(
        personName: person.name,
        logsText: logsText,
        modelCandidates: _provider.settings.heavyModels, // Using Pro Models
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[PersonDetails] $msg"),
      );

      // Save the entire JSON structure as a string so UI can parse it
      _provider.chatbotMemory.people[personIndex].details = jsonEncode(result);
      _provider.chatbotMemory.people[personIndex].lastUpdated = DateTime.now();
      _provider.markDirty('settings');
      _provider.scheduleRealtimeSync();
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      _provider.notifyListeners();
      
    } catch (e) {
      debugPrint("Error generating person details: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  Future<Map<String, dynamic>> runQuickTherapy(String reason, String feeling, String action, {bool requestComms = false}) async {
    final logsText = _getLogsText();
    final peopleContext = _provider.chatbotMemory.people.map((p) => "${p.name} (${p.relation})").join(', ');

    _provider.setLoadingTask("Formulating Strategy...");

    try {
      final result = await _provider.aiService.runQuickTherapy(
        reason: reason,
        feeling: feeling,
        action: action,
        logsText: logsText,
        peopleContext: peopleContext.isEmpty ? "None" : peopleContext,
        requestComms: requestComms,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[QuickTherapy] $msg"),
      );

      return result;
    } catch (e) {
      debugPrint("Error running quick therapy: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  Future<String> simulateEvent(String situation) async {
    final logsText = _getLogsText();

    _provider.setLoadingTask("Simulating Event...");

    try {
      final result = await _provider.aiService.simulateEvent(
        situation: situation,
        logsText: logsText,
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[EventSim] $msg"),
      );

      return result['simulation'] as String? ?? "Simulation failed to generate usable data.";
    } catch (e) {
      debugPrint("Error simulating event: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  void simulateTalk(PersonInfo person, String? customChatHistory) {
    final customContext = """
    You are roleplaying as ${person.name}, who is my ${person.relation}.
    Do NOT break character. Do not refer to yourself as an AI.
    Here is a psychological profile based on my past logs:
    ${person.details ?? 'No additional details available.'}
    
    ${customChatHistory != null && customChatHistory.isNotEmpty ? "Here is a recent chat history for context to understand their speech pattern:\n$customChatHistory" : ""}
    """;

    _provider.createNoraSession(
      title: "SIM: ${person.name}",
      tone: "Simulated",
      startDate: DateTime.now(),
      endDate: DateTime.now(),
      customContext: customContext,
    );
  }
}