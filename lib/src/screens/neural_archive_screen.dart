import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class NeuralArchiveScreen extends StatefulWidget {
  const NeuralArchiveScreen({super.key});

  @override
  State<NeuralArchiveScreen> createState() => _NeuralArchiveScreenState();
}

class _NeuralArchiveScreenState extends State<NeuralArchiveScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _queryController = TextEditingController();
  bool _isLoading = false;
  String? _response;
  String _selectedModelType = 'Lite'; // Lite or General

  @override
  void initState() {
    super.initState();
    // Default to last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _executeQuery() async {
    if (_queryController.text.trim().isEmpty) return;
    if (_startDate == null || _endDate == null) return;

    setState(() {
      _isLoading = true;
      _response = null;
    });

    final provider = Provider.of<AppProvider>(context, listen: false);
    final logsContext = _gatherLogs(provider);

    try {
      final aiService = AIService();
      final models = _selectedModelType == 'Lite' 
          ? provider.settings.liteModels 
          : provider.settings.heavyModels;

      final result = await aiService.queryNeuralArchive(
        query: _queryController.text.trim(),
        logsContext: logsContext,
        modelCandidates: models,
        currentApiKeyIndex: provider.apiKeyIndex,
        customApiKeys: provider.settings.customApiKeys,
        onNewApiKeyIndex: (idx) => provider.setProviderApiKeyIndex(idx),
        onLog: (msg) => debugPrint(msg),
      );

      setState(() => _response = result);
    } catch (e) {
      setState(() => _response = "Error accessing archives: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _gatherLogs(AppProvider provider) {
    final sb = StringBuffer();
    // 1. Reflections
    final relevantReflections = provider.reflectionLogs.where((l) =>
        l.timestamp.isAfter(_startDate!) && 
        l.timestamp.isBefore(_endDate!.add(const Duration(days: 1))));
    
    sb.writeln("=== REFLECTION LOGS ===");
    for (var l in relevantReflections) {
      sb.writeln("[${DateFormat('yyyy-MM-dd').format(l.timestamp)}] Trigger: ${l.trigger}. Emotion: ${l.emotion}. Reason: ${l.reason}.");
    }

    // 2. Daily Summaries
    sb.writeln("\n=== DAILY SUMMARIES ===");
    provider.completedByDay.forEach((dateStr, data) {
      final date = DateTime.tryParse(dateStr);
      if (date != null && 
          date.isAfter(_startDate!) && 
          date.isBefore(_endDate!.add(const Duration(days: 1))) &&
          data is Map && data['aiSummary'] != null) {
        sb.writeln("[$dateStr] ${data['aiSummary']}");
      }
    });

    return sb.toString();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate!, end: _endDate!),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.fhAccentTeal,
            onPrimary: Colors.black,
            surface: AppTheme.fhBgDeepDark,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.fhBgDeepDark,
      appBar: AppBar(
        backgroundColor: AppTheme.fhBgDeepDark,
        title: const Text("NEURAL ARCHIVE", style: TextStyle(fontFamily: AppTheme.fontDisplay, letterSpacing: 2.0)),
        centerTitle: true,
        leading: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Controls
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.fhBgDark,
                border: Border.all(color: AppTheme.fhBorderColor.withOpacity(0.5)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDateRange,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TEMPORAL RANGE", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                "${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}",
                                style: const TextStyle(color: AppTheme.fhAccentTeal, fontFamily: 'RobotoMono', fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 30, color: Colors.white10),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedModelType,
                        dropdownColor: AppTheme.fhBgDark,
                        underline: Container(),
                        style: const TextStyle(color: AppTheme.fhTextPrimary, fontWeight: FontWeight.bold),
                        onChanged: (val) => setState(() => _selectedModelType = val!),
                        items: const [
                          DropdownMenuItem(value: 'Lite', child: Text("LITE MODEL")),
                          DropdownMenuItem(value: 'General', child: Text("GENERAL MODEL")),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: "Enter query regarding archives...",
                      hintStyle: TextStyle(color: AppTheme.fhTextSecondary.withOpacity(0.5), fontStyle: FontStyle.italic),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.3),
                      border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.fhBorderColor.withOpacity(0.3))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(color: AppTheme.fhTextPrimary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ValorantButton(
                      label: _isLoading ? "PROCESSING..." : "SEARCH ARCHIVES",
                      onPressed: _isLoading ? null : _executeQuery,
                      icon: MdiIcons.databaseSearch,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Output
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  border: Border.all(color: _response != null ? AppTheme.fhAccentPurple.withOpacity(0.5) : Colors.transparent),
                ),
                child: SingleChildScrollView(
                  child: _isLoading 
                    ? Center(child: CircularProgressIndicator(color: AppTheme.fhAccentPurple))
                    : Text(
                        _response ?? "Awaiting Input...",
                        style: TextStyle(
                          color: _response != null ? AppTheme.fhTextPrimary : AppTheme.fhTextDisabled,
                          fontSize: 14,
                          height: 1.6,
                          fontFamily: _response != null ? 'Roboto' : 'RobotoCondensed'
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}