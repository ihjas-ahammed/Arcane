import 'package:flutter/material.dart';
import 'package:arcane/src/theme/app_theme.dart';
import 'package:arcane/src/providers/app_provider.dart';
import 'package:provider/provider.dart';

class TimezoneSelector extends StatelessWidget {
  const TimezoneSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final currentTimezone = provider.settings.userTimezone;

    // Common Timezones (Simplified list)
    final timezones = [
      'Asia/Kolkata',
      'UTC',
      'America/New_York',
      'America/Los_Angeles',
      'Europe/London',
      'Europe/Paris',
      'Asia/Tokyo',
      'Asia/Dubai',
      'Australia/Sydney'
    ];

    if (!timezones.contains(currentTimezone)) {
      timezones.add(currentTimezone);
    }

    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Timezone',
        prefixIcon: Icon(Icons.public, size: 20),
      ),
      dropdownColor: AppTheme.fhBgMedium,
      value: currentTimezone,
      items: timezones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz))).toList(),
      onChanged: (value) {
        if (value != null) {
          provider.setSettings(provider.settings..userTimezone = value);
        }
      },
    );
  }
}