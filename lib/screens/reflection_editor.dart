import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:arcane/theme/valorant_theme.dart';
import 'package:arcane/widgets/valorant_container.dart';
import 'package:arcane/widgets/valorant_button.dart';

class ReflectionEditor extends StatefulWidget {
  const ReflectionEditor({super.key});

  @override
  State<ReflectionEditor> createState() => _ReflectionEditorState();
}

class _ReflectionEditorState extends State<ReflectionEditor> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ValorantColors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: ValorantColors.white.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back,
                        color: ValorantColors.white),
                  ),
                  const Gap(8),
                  Text("TACTICAL BRIEFING // EDIT",
                      style: ValorantTextStyles.header),
                ],
              ),
            ),

            // Editor Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ListView(
                  children: [
                    _buildLabel("SUBJECT / TITLE"),
                    ValorantContainer(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _titleController,
                        style: ValorantTextStyles.subHeader,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "ENTER SUBJECT...",
                          hintStyle: TextStyle(color: ValorantColors.muted),
                        ),
                      ),
                    ),
                    const Gap(24),
                    _buildLabel("MISSION REPORT"),
                    ValorantContainer(
                      height: 300,
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        style: ValorantTextStyles.body,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Enter analysis data here...",
                          hintStyle: TextStyle(color: ValorantColors.muted),
                        ),
                      ),
                    ),
                    const Gap(24),
                    Row(
                      children: [
                        Expanded(
                          child: ValorantButton(
                            label: "DISCARD",
                            isPrimary: false,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: ValorantButton(
                            label: "CONFIRM",
                            isPrimary: true,
                            onPressed: () {
                              // Save logic here
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: ValorantTextStyles.label.copyWith(color: ValorantColors.red),
      ),
    );
  }
}
