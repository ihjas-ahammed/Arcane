import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:missions/src/models/update_model.dart';
import 'package:missions/src/services/update_service.dart';
import 'package:missions/src/theme/jwe_theme.dart';

class WhatsNewUpdateDialog extends StatefulWidget {
  final UpdateModel update;
  final String currentVersion;
  final UpdateService updateService;

  const WhatsNewUpdateDialog({
    super.key,
    required this.update,
    required this.currentVersion,
    required this.updateService,
  });

  static Future<void> show(
    BuildContext context, {
    required UpdateModel update,
    required String currentVersion,
    required UpdateService updateService,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WhatsNewUpdateDialog(
        update: update,
        currentVersion: currentVersion,
        updateService: updateService,
      ),
    );
  }

  @override
  State<WhatsNewUpdateDialog> createState() => _WhatsNewUpdateDialogState();
}

class _WhatsNewUpdateDialogState extends State<WhatsNewUpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  File? _cachedFile;
  int? _cachedFileSize;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final cached = await widget.updateService.getCachedApk(widget.update);
    int? size;
    if (cached != null) {
      try {
        size = await cached.length();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _cachedFile = cached;
        _cachedFileSize = size;
      });
    }
  }

  Future<void> _startDownloadAndInstall({bool forceRedownload = false}) async {
    if (!forceRedownload && _cachedFile != null) {
      final exists = await _cachedFile!.exists();
      if (exists && await _cachedFile!.length() > 1024 * 1024) {
        final success = await widget.updateService.installApk(_cachedFile!.path);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please grant package installation permission to install the update.')),
          );
        }
        return;
      }
    }

    if (_cachedFile != null) {
      try {
        await _cachedFile!.delete();
      } catch (_) {}
      setState(() {
        _cachedFile = null;
        _cachedFileSize = null;
      });
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _errorMessage = null;
    });

    try {
      final file = await widget.updateService.downloadApk(
        widget.update,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );

      int? fileSize;
      try {
        fileSize = await file.length();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _cachedFile = file;
          _cachedFileSize = fileSize;
          _isDownloading = false;
        });

        // Launch installer immediately
        final success = await widget.updateService.installApk(file.path);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Update downloaded to cache! Please confirm install.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Download failed: $e';
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isLight = JweTheme.isLight;
    final accentColor = JweTheme.accentAmber;
    final bgDark = isLight ? const Color(0xFFF7F5EE) : const Color(0xFF0F111A);

    final changelog = widget.update.changelogMarkdown ??
        '### Version ${widget.update.versionName}\n- General improvements and performance optimizations.\n- Bug fixes and stability upgrades.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
        decoration: BoxDecoration(
          color: bgDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isLight ? 0.15 : 0.3),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header HUD Bar ──────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  border: Border(bottom: BorderSide(color: accentColor.withValues(alpha: 0.4))),
                ),
                child: Row(
                  children: [
                    Icon(MdiIcons.rocketLaunchOutline, size: 20, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SYSTEM UPGRADE AVAILABLE',
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'v${widget.currentVersion}  ➔  v${widget.update.versionName}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isLight ? Colors.black87 : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: isLight ? Colors.black54 : Colors.white54),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // ── Cached Status Pill (if APK cached) ─────────────
              if (_cachedFile != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: JweTheme.accentTeal.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(MdiIcons.checkCircleOutline, size: 16, color: JweTheme.accentTeal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'APK v${widget.update.versionName} CACHED (${_cachedFileSize != null ? _formatBytes(_cachedFileSize!) : 'READY'})',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: JweTheme.accentTeal,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _isDownloading ? null : () => _startDownloadAndInstall(forceRedownload: true),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(MdiIcons.refresh, size: 12, color: JweTheme.accentTeal),
                              const SizedBox(width: 4),
                              Text(
                                'REDOWNLOAD',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: JweTheme.accentTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Changelog Markdown Content ───────────────────
              Expanded(
                child: Markdown(
                  data: changelog,
                  selectable: true,
                  padding: const EdgeInsets.all(16),
                  styleSheet: MarkdownStyleSheet(
                    h1: GoogleFonts.orbitron(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    h2: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                    h3: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isLight ? const Color(0xFF1E293B) : Colors.white,
                    ),
                    p: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      height: 1.5,
                      color: isLight ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                    listBullet: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: accentColor,
                    ),
                    code: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      backgroundColor: isLight ? const Color(0xFFE2E8F0) : const Color(0xFF1E2030),
                      color: accentColor,
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isLight ? Colors.black12 : Colors.white12,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Download Progress Indicator ─────────────────
              if (_isDownloading)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: isLight ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DOWNLOADING APK... ${(_downloadProgress * 100).toInt()}%',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                          Text(
                            '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              color: isLight ? Colors.black54 : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _downloadProgress > 0 ? _downloadProgress : null,
                          minHeight: 6,
                          backgroundColor: isLight ? Colors.black12 : Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Error Message Banner ────────────────────────
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: JweTheme.accentRed.withValues(alpha: 0.15),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: JweTheme.accentRed,
                    ),
                  ),
                ),

              // ── Bottom Action Footer ─────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isLight ? const Color(0xFFEDE9DF) : const Color(0xFF141622),
                  border: Border(top: BorderSide(color: isLight ? Colors.black12 : Colors.white12)),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'LATER',
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isLight ? Colors.black54 : Colors.white54,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_cachedFile != null) ...[
                      OutlinedButton.icon(
                        onPressed: _isDownloading ? null : () => _startDownloadAndInstall(forceRedownload: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accentColor,
                          side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(MdiIcons.refresh, size: 15, color: accentColor),
                        label: Text(
                          'REDOWNLOAD',
                          style: GoogleFonts.orbitron(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      onPressed: _isDownloading ? null : () => _startDownloadAndInstall(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cachedFile != null ? JweTheme.accentTeal : accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: Icon(
                        _cachedFile != null
                            ? MdiIcons.packageDown
                            : (_isDownloading ? Icons.hourglass_top : MdiIcons.download),
                        size: 16,
                        color: Colors.black,
                      ),
                      label: Text(
                        _cachedFile != null
                            ? 'INSTALL UPGRADE'
                            : (_isDownloading ? 'DOWNLOADING...' : 'DOWNLOAD & INSTALL'),
                        style: GoogleFonts.orbitron(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
