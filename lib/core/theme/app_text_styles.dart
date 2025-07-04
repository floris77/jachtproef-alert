import 'package:flutter/cupertino.dart';

class AppTextStyles {
  static const sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.bold,
    color: CupertinoColors.systemGrey,
    letterSpacing: 0.5,
  );
  static const rowTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: CupertinoColors.label,
  );
  static const rowSubtitle = TextStyle(
    fontSize: 15,
    color: CupertinoColors.secondaryLabel,
  );
  static const destructive = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: CupertinoColors.systemRed,
  );
  static const chip = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: CupertinoColors.label,
  );
  static const small = TextStyle(
    fontSize: 12,
    color: CupertinoColors.systemGrey,
  );
} 