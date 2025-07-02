import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProefCard extends StatelessWidget {
  final Map<String, dynamic> proef;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;

  const ProefCard({
    Key? key,
    required this.proef,
    required this.isFavorite,
    this.onFavoriteToggle,
    this.onTap,
  }) : super(key: key);

  Color _getStatusColor(String? regText) {
    if (regText == null) return Colors.grey;
    if (regText.toLowerCase() == 'inschrijven') {
      return const Color(0xFF4CAF50); // Green
    } else if (regText.toLowerCase().startsWith('vanaf ')) {
      return const Color(0xFFFF9800); // Orange
    } else if (regText.toLowerCase().contains('niet mogelijk') || 
               regText.toLowerCase().contains('niet meer mogelijk')) {
      return const Color(0xFFF44336); // Red
    }
    return Colors.grey;
  }

  String _getStatusText(String? regText) {
    if (regText == null) return 'ONBEKEND';
    if (regText.toLowerCase() == 'inschrijven') {
      return 'INSCHRIJVEN';
    } else if (regText.toLowerCase().startsWith('vanaf ')) {
      return 'BINNENKORT';
    } else if (regText.toLowerCase().contains('niet mogelijk') || 
               regText.toLowerCase().contains('niet meer mogelijk')) {
      return 'GESLOTEN';
    }
    return 'ONBEKEND';
  }

  IconData _getStatusIcon(String? regText) {
    if (regText == null) return Icons.help_outline;
    if (regText.toLowerCase() == 'inschrijven') {
      return Icons.check_circle_outline;
    } else if (regText.toLowerCase().startsWith('vanaf ')) {
      return Icons.schedule;
    } else if (regText.toLowerCase().contains('niet mogelijk') || 
               regText.toLowerCase().contains('niet meer mogelijk')) {
      return Icons.cancel_outlined;
    }
    return Icons.help_outline;
  }

  Color get olive => const Color(0xFF535B22);
  Color get lightOlive => const Color(0xFFE6E9D8);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 350;

    // Robustly handle date and registration fields
    String regText = '';
    if (proef['registration'] != null && proef['registration']['text'] != null) {
      regText = proef['registration']['text'].toString();
    } else if (proef['regText'] != null) {
      regText = proef['regText'].toString();
    } else if (proef['registration_text'] != null) {
      regText = proef['registration_text'].toString();
    } else if (proef['raw'] != null && proef['raw']['registration_text'] != null) {
      regText = proef['raw']['registration_text'].toString();
    }
    regText = regText.trim().toLowerCase();

    var dateRaw = proef['date'] ?? (proef['raw'] != null ? proef['raw']['date'] : null);
    String dateStr = 'Datum onbekend';
    DateTime? dateTime;
    if (dateRaw != null) {
      if (dateRaw is Timestamp) {
        dateTime = dateRaw.toDate();
      } else if (dateRaw is DateTime) {
        dateTime = dateRaw;
      } else if (dateRaw is String) {
        try {
          dateTime = DateTime.parse(dateRaw);
        } catch (_) {}
      }
      if (dateTime != null) {
        dateStr = DateFormat('d MMM yyyy', 'nl_NL').format(dateTime);
      }
    }

    final statusColor = _getStatusColor(regText);
    final statusText = _getStatusText(regText);
    final statusIcon = _getStatusIcon(regText);
    final type = proef['type']?.toString().trim() ?? '';
    final showType = type.isNotEmpty && type.toLowerCase() != 'onbekend' && type.toLowerCase() != 'unknown';
    final isClosed = statusText == 'GESLOTEN';
    final isVeldwedstrijd = type.toLowerCase().contains('veldwedstrijd');
    final organizer = proef['organizer']?.toString() ?? 'Onbekende organisator';
    final location = proef['location']?.toString() ?? 'Locatie onbekend';
    final showDateAndLocation = dateStr != 'Datum onbekend' && location != 'Locatie onbekend';
    final remark = proef['remark']?.toString();
    final showRemark = remark != null && remark.isNotEmpty;
    final showDatumPlaats = regText.toLowerCase().contains('datum en plaats');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 4 : 8, vertical: isVerySmallScreen ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isVerySmallScreen ? 14 : 22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              spreadRadius: 0,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: organizer (left), type badge (right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organizer name (left)
                  Expanded(
                    child: Text(
                      organizer,
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 12 : 20,
                        fontWeight: FontWeight.w900,
                        color: olive,
                        height: 1.18,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Type badge (right)
                  if (showType)
                    Container(
                      margin: EdgeInsets.only(left: 8, top: 2),
                      padding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 6 : 10, vertical: isVerySmallScreen ? 2 : 4),
                      decoration: BoxDecoration(
                        color: lightOlive,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: olive,
                          fontWeight: FontWeight.bold,
                          fontSize: isVerySmallScreen ? 10 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Date row
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: isVerySmallScreen ? 15 : 18, color: olive),
                  const SizedBox(width: 7),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: isVerySmallScreen ? 12 : 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Location row (always full width, not truncated)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: isVerySmallScreen ? 15 : 18, color: olive),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        location,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: isVerySmallScreen ? 12 : 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.05,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Italic olive text for 'Datum en plaats...' or remark
              if (showDatumPlaats)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    regText,
                    style: TextStyle(
                      color: olive,
                      fontSize: isVerySmallScreen ? 12 : 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showRemark)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    remark!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: isVerySmallScreen ? 12 : 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.05,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Add this before the status badge at the bottom
              if (statusText == 'BINNENKORT')
                _buildBinnenkortEnrollmentInfo(regText),
              // Status badge at bottom left for all statuses
              if (statusText == 'INSCHRIJVEN' || statusText == 'BINNENKORT' || statusText == 'GESLOTEN' || statusText == 'ONBEKEND')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusText == 'INSCHRIJVEN'
                              ? const Color(0xFF4CAF50).withOpacity(0.13)
                              : statusText == 'BINNENKORT'
                                  ? const Color(0xFFFF9800).withOpacity(0.13)
                                  : statusText == 'GESLOTEN'
                                      ? const Color(0xFFF44336).withOpacity(0.13)
                                      : Colors.grey.withOpacity(0.13),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              statusText == 'INSCHRIJVEN'
                                  ? Icons.check_circle_outline
                                  : statusText == 'BINNENKORT'
                                      ? Icons.schedule
                                      : statusText == 'GESLOTEN'
                                          ? Icons.cancel_outlined
                                          : Icons.help_outline,
                              size: isVerySmallScreen ? 15 : 17,
                              color: statusText == 'INSCHRIJVEN'
                                  ? const Color(0xFF4CAF50)
                                  : statusText == 'BINNENKORT'
                                      ? const Color(0xFFFF9800)
                                      : statusText == 'GESLOTEN'
                                          ? const Color(0xFFF44336)
                                          : Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusText == 'INSCHRIJVEN'
                                  ? 'Inschrijven'
                                  : statusText == 'BINNENKORT'
                                      ? 'Binnenkort'
                                      : statusText == 'GESLOTEN'
                                          ? 'Gesloten'
                                          : 'Onbekend',
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 12 : 15,
                                fontWeight: FontWeight.w800,
                                color: statusText == 'INSCHRIJVEN'
                                    ? const Color(0xFF4CAF50)
                                    : statusText == 'BINNENKORT'
                                        ? const Color(0xFFFF9800)
                                        : statusText == 'GESLOTEN'
                                            ? const Color(0xFFF44336)
                                            : Colors.grey[700],
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

  Widget _buildBinnenkortEnrollmentInfo(String regText) {
    // regText example: 'vanaf 1 mei 2024 20:00'
    final RegExp regex = RegExp(r'^vanaf (.+)$');
    final match = regex.firstMatch(regText);
    String infoText = '';
    if (match != null) {
      String dateTimeStr = match.group(1) ?? '';
      // Try to split date and time
      final dateTimeParts = dateTimeStr.split(' ');
      String datePart = '';
      String timePart = '';
      if (dateTimeParts.length >= 3) {
        // e.g. '1 mei 2024 20:00'
        datePart = dateTimeParts.sublist(0, 3).join(' ');
        if (dateTimeParts.length > 3) {
          timePart = dateTimeParts.sublist(3).join(' ');
        }
      } else {
        datePart = dateTimeStr;
      }
      infoText = 'Inschrijving opent op $datePart';
      if (timePart.isNotEmpty) {
        infoText += ' om $timePart';
      }
    } else {
      infoText = 'Inschrijving opent binnenkort';
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          infoText,
          style: const TextStyle(
            color: Color(0xFF388E3C),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
} 