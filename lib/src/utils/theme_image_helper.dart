import 'package:flutter/material.dart';

class ThemeImageHelper {
  // Curated Unsplash images that match the "Arcane/Valorant" or specific life themes
  static const Map<String, String> _themeImages = {
    // Task Themes
    'tech': 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&q=80', // Circuitry
    'knowledge': 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?auto=format&fit=crop&q=80', // Library/Books
    'learning': 'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&q=80', // Education
    'discipline': 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&q=80', // Gym/Weights
    'order': 'https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b?auto=format&fit=crop&q=80', // Clean Desk
    'health': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&q=80', // Runner
    'finance': 'https://images.unsplash.com/photo-1611974765270-ca1258634369?auto=format&fit=crop&q=80', // Stock/Graph
    'creative': 'https://images.unsplash.com/photo-1513364776144-60967b0f800f?auto=format&fit=crop&q=80', // Art/Paint
    'exploration': 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&q=80', // Landscape
    'social': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&q=80', // Friends
    'nature': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?auto=format&fit=crop&q=80', // Forest
    'general': 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80', // Abstract Tech

    // Values (Fallback to similar themes if specific not found)
    'family': 'https://images.unsplash.com/photo-1511895426328-dc8714191300?auto=format&fit=crop&q=80',
    'partners': 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&q=80',
    'friendships': 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?auto=format&fit=crop&q=80',
    'work': 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&q=80',
    'education': 'https://images.unsplash.com/photo-1523050854058-8df90110c9f1?auto=format&fit=crop&q=80',
    'fun': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&q=80',
    'spirituality': 'https://images.unsplash.com/photo-1507692049790-de58293a469d?auto=format&fit=crop&q=80',
    'community': 'https://images.unsplash.com/photo-1559027615-cd4628902d4a?auto=format&fit=crop&q=80',
    // 'nature' & 'health' reused from above
  };

  static const String _defaultImage = 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&q=80'; // Abstract Cyber

  static String getHeaderImage(String themeOrKey) {
    return _themeImages[themeOrKey.toLowerCase()] ?? _defaultImage;
  }

  static ImageProvider getProvider(String themeOrKey) {
    return NetworkImage(getHeaderImage(themeOrKey));
  }
}