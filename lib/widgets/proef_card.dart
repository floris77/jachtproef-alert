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
      return Colors.green;
    } else if (regText.toLowerCase().startsWith('vanaf ')) {
      return Colors.orange;
    } else if (regText.toLowerCase().contains('niet mogelijk') || 
               regText.toLowerCase().contains('niet meer mogelijk')) {
      return Colors.red;
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
        dateStr = DateFormat('d MMMM yyyy', 'nl_NL').format(dateTime);
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(regText).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getStatusText(regText),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(regText),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (onFavoriteToggle != null)
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey,
                      ),
                      onPressed: onFavoriteToggle,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                proef['organizer']?.toString() ?? 'Onbekende organisator',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF535B22),
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on, proef['location']?.toString() ?? 'Locatie onbekend'),
              const SizedBox(height: 4),
              _buildInfoRow(Icons.calendar_today, dateStr),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.category, proef['type']?.toString() ?? 'Type onbekend'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ],
    );
  }
} 