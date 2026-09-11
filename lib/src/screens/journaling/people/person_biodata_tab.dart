import 'package:flutter/material.dart';
import 'package:missions/src/theme/person_info_theme.dart';
import 'package:missions/src/widgets/valorant/valorant_button.dart';
import 'people_common_widgets.dart';

class PersonBiodataTab extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController relationController;
  final TextEditingController ageController;
  final TextEditingController genderController;
  final TextEditingController occupationController;
  final TextEditingController locationController;
  final TextEditingController birthdayController;
  final TextEditingController contactController;
  final VoidCallback onSave;

  const PersonBiodataTab({
    super.key,
    required this.nameController,
    required this.relationController,
    required this.ageController,
    required this.genderController,
    required this.occupationController,
    required this.locationController,
    required this.birthdayController,
    required this.contactController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PersonSectionHeader(text: "ARCHIVE BIODATA SPECIFICATIONS"),

          const PersonFieldLabel(label: "FULL ARCHIVE NAME"),
          CyberpunkTextField(controller: nameController),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PersonFieldLabel(label: "RELATION TYPE"),
                    CyberpunkTextField(controller: relationController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PersonFieldLabel(label: "BIOLOGICAL AGE"),
                    CyberpunkTextField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PersonFieldLabel(label: "GENDER"),
                    CyberpunkTextField(controller: genderController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PersonFieldLabel(label: "OCCUPATION / ROLE"),
                    CyberpunkTextField(controller: occupationController),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const PersonFieldLabel(label: "BASE LOCATION / FIELD DEPOT"),
          CyberpunkTextField(controller: locationController),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PersonFieldLabel(label: "BIRTHDAY / SPECIAL DATE"),
                    CyberpunkTextField(controller: birthdayController),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PersonFieldLabel(label: "CONTACT ADDRESS / SOCIAL GRID"),
                    CyberpunkTextField(controller: contactController),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SAVE BIODATA BUTTON
          SizedBox(
            width: double.infinity,
            child: ValorantButton(
              label: "COMMIT BIODATA ARCHIVES",
              isPrimary: true,
              color: PersonInfoTheme.spideyCyan,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}
