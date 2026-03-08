import 'package:flutter/material.dart';
import 'package:arcane/src/theme/person_info_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class PersonCoreStats extends StatelessWidget {
  final String relation;
  final String status;
  final String updatedStr;
  final String role;

  const PersonCoreStats({
    super.key,
    required this.relation,
    required this.status,
    required this.updatedStr,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Core Stats"),
        _buildDataRow("Relation", relation),
        _buildDataRow("Status", status),
        _buildDataRow("Updated", updatedStr),
        _buildDataRow("Role", role),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 15.0),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.spideyCyan,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [PersonInfoTheme.spideyCyanDim, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4.0),
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x0DFFFFFF)), // rgba(255,255,255,0.05)
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.textGrey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              color: PersonInfoTheme.textWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}