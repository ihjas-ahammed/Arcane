import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:arcane/src/widgets/valorant/valorant_text_field.dart';
import 'package:arcane/src/widgets/valorant/valorant_button.dart';
import 'package:arcane/src/widgets/valorant/valorant_dropdown.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class CreateProjectSheet extends StatefulWidget {
  const CreateProjectSheet({super.key});

  @override
  State<CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<CreateProjectSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? _selectedMainTaskId;
  
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _selectedMainTaskId = provider.selectedTaskId ?? provider.mainTasks.firstOrNull?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedImages.add(picked);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return Container(
      color: AppTheme.fhBgDeepDark,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24, 
            right: 24, 
            top: 24, 
            bottom: MediaQuery.of(context).viewInsets.bottom + 24
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(width: 4, height: 24, color: AppTheme.fhAccentRed),
                    const SizedBox(width: 12),
                    Text(
                      "INITIATE PROJECT", 
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: AppTheme.fontDisplay,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: AppTheme.fhTextPrimary
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Mission Selector
                ValorantDropdown<String>(
                  label: "LINK TO MISSION",
                  value: _selectedMainTaskId,
                  items: provider.mainTasks.map((task) {
                    return DropdownMenuItem(
                      value: task.id,
                      child: Text(task.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedMainTaskId = val),
                ),
                
                const SizedBox(height: 24),
                
                // Project Name
                ValorantTextField(
                  controller: _nameController,
                  label: "PROJECT CODENAME",
                  hint: "e.g. OPERATION PHOENIX",
                  autofocus: true,
                ),
                
                const SizedBox(height: 24),
                
                // Description
                ValorantTextField(
                  controller: _descController,
                  label: "BRIEFING / OBJECTIVES",
                  hint: "Describe the primary goal...",
                  maxLines: 3,
                ),
                
                const SizedBox(height: 24),
                
                // AI Multi-modal Attachments
                const Text("ATTACHMENTS (FOR AI GENERATION)", style: TextStyle(color: AppTheme.fhTextSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text("CAMERA"),
                      onPressed: () => _pickImage(ImageSource.camera),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.fhAccentTeal),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 16),
                      label: const Text("GALLERY"),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      style: OutlinedButton.styleFrom(foregroundColor: AppTheme.fhAccentPurple),
                    ),
                  ],
                ),
                
                if (_selectedImages.isNotEmpty) ...[
                   const SizedBox(height: 16),
                   SizedBox(
                     height: 80,
                     child: ListView.builder(
                       scrollDirection: Axis.horizontal,
                       itemCount: _selectedImages.length,
                       itemBuilder: (context, index) {
                         return Stack(
                           children: [
                             Container(
                               margin: const EdgeInsets.only(right: 12, top: 8),
                               width: 60, height: 60,
                               decoration: BoxDecoration(
                                 border: Border.all(color: AppTheme.fhBorderColor),
                                 image: DecorationImage(
                                   image: FileImage(File(_selectedImages[index].path)),
                                   fit: BoxFit.cover
                                 )
                               ),
                             ),
                             Positioned(
                               top: 0, right: 0,
                               child: InkWell(
                                 onTap: () => _removeImage(index),
                                 child: Container(
                                   padding: const EdgeInsets.all(2),
                                   decoration: const BoxDecoration(color: AppTheme.fhAccentRed, shape: BoxShape.circle),
                                   child: const Icon(Icons.close, size: 12, color: Colors.white),
                                 ),
                               ),
                             )
                           ],
                         );
                       },
                     ),
                   ),
                ],
                
                const SizedBox(height: 40),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ValorantButton(
                        label: "ABORT",
                        isPrimary: false,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ValorantButton(
                        label: provider.isGeneratingSubquests ? "PROCESSING..." : "DEPLOY",
                        isPrimary: true,
                        onPressed: provider.isGeneratingSubquests ? null : () async {
                          if (_nameController.text.isNotEmpty && _selectedMainTaskId != null) {
                            
                            // If description has content, it means we might want AI generation
                            if (_descController.text.isNotEmpty || _selectedImages.isNotEmpty) {
                              final prompt = "${_nameController.text}. Details: ${_descController.text}";
                              
                              // We don't pop immediately because we await the AI task if generating with context
                              await provider.projectActions.generateProjectStructure(
                                _selectedMainTaskId!, 
                                prompt, 
                                images: _selectedImages.isNotEmpty ? _selectedImages : null
                              );
                              if (mounted) Navigator.pop(context);
                            } else {
                              // Basic manual creation
                              provider.projectActions.addProject(
                                _nameController.text, 
                                _descController.text,
                                mainTaskId: _selectedMainTaskId
                              );
                              Navigator.pop(context);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}