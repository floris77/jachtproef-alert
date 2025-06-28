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

  @override
  Widget build(BuildContext context) {
    // Robustly handle date and registration fields
    String regText = '';
    if (proef['regText'] != null) {
      regText = proef['regText'].toString();
    } else if (proef['registration_text'] != null) {
      regText = proef['registration_text'].toString();
    } else if (proef['raw'] != null && proef['raw']['registration_text'] != null) {
      regText = proef['raw']['registration_text'].toString();
    }

    var dateRaw = proef['date'] ?? (proef['raw'] != null ? proef['raw']['date'] : null);
    String dateStr = 'Datum onbekend';
    if (dateRaw != null) {
      DateTime? dateTime;
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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status badge with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (onFavoriteToggle != null)
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey[400],
                        size: 20,
                      ),
                      onPressed: onFavoriteToggle,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Organizer name (title)
              Text(
                proef['organizer']?.toString() ?? 'Onbekende organisator',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF535B22),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              
              // Info rows with better spacing
              _buildInfoRow(Icons.location_on_outlined, proef['location']?.toString() ?? 'Locatie onbekend'),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.calendar_today_outlined, dateStr),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.category_outlined, proef['type']?.toString() ?? 'Type onbekend'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon, 
          size: 16, 
          color: Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700], 
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
} 