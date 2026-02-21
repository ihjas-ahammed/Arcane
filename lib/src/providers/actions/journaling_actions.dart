import 'package:flutter/foundation.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/models/chatbot_models.dart';
import 'package:uuid/uuid.dart';

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
        modelCandidates: _provider.settings.liteModels,
        currentApiKeyIndex: _provider.apiKeyIndex,
        customApiKeys: _provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => _provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint("[PersonDetails] $msg"),
      );

      final details = result['details'] as String?;
      if (details != null) {
        _provider.chatbotMemory.people[personIndex].details = details;
        _provider.chatbotMemory.people[personIndex].lastUpdated = DateTime.now();
        _provider.markDirty('settings');
        _provider.scheduleRealtimeSync();
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        _provider.notifyListeners();
      }
    } catch (e) {
      debugPrint("Error generating person details: $e");
      rethrow;
    } finally {
      _provider.setLoadingTask(null);
    }
  }

  Future<Map<String, dynamic>> runQuickTherapy(String reason, String feeling, String action) async {
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