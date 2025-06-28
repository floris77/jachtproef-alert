import 'package:flutter/material.dart';
import 'responsive_helper.dart';

class ResponsiveDialogs {
  static const Color kMainColor = Color(0xFF535B22);

  /// Creates a responsive AlertDialog with proper text sizing for all screen sizes
  static AlertDialog createResponsiveAlertDialog({
    required BuildContext context,
    Widget? title,
    Widget? content,
    List<Widget>? actions,
    bool barrierDismissible = true,
    ShapeBorder? shape,
  }) {
    return AlertDialog(
      shape: shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: title,
      content: content,
      actions: actions,
      titlePadding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 20.0)),
      contentPadding: EdgeInsets.fromLTRB(
        ResponsiveHelper.getSpacing(context, 20.0),
        ResponsiveHelper.getSpacing(context, 12.0),
        ResponsiveHelper.getSpacing(context, 20.0),
        ResponsiveHelper.getSpacing(context, 16.0),
      ),
      actionsPadding: EdgeInsets.fromLTRB(
        ResponsiveHelper.getSpacing(context, 20.0),
        0,
        ResponsiveHelper.getSpacing(context, 20.0),
        ResponsiveHelper.getSpacing(context, 16.0),
      ),
    );
  }

  /// Creates a responsive title with icon for dialogs
  static Widget createResponsiveDialogTitle({
    required BuildContext context,
    required String title,
    required IconData icon,
    Color? iconColor,
    Color? backgroundColor,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 8.0)),
          decoration: BoxDecoration(
            color: (backgroundColor ?? kMainColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: iconColor ?? kMainColor,
            size: ResponsiveHelper.getIconSize(context, 24.0),
          ),
        ),
        SizedBox(width: ResponsiveHelper.getSpacing(context, 12.0)),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveHelper.getSubtitleFontSize(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Creates responsive dialog content with proper text sizing
  static Widget createResponsiveDialogContent({
    required BuildContext context,
    required String message,
    List<String>? benefits,
    Widget? additionalContent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            fontSize: ResponsiveHelper.getBodyFontSize(context),
            height: 1.4,
          ),
        ),
        if (benefits != null && benefits.isNotEmpty) ...[
          SizedBox(height: ResponsiveHelper.getSpacing(context, 16.0)),
          Text(
            'Voordelen:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getBodyFontSize(context),
            ),
          ),
          SizedBox(height: ResponsiveHelper.getSpacing(context, 8.0)),
          ...benefits.map((benefit) => Padding(
            padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, 2.0)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: ResponsiveHelper.getIconSize(context, 20.0),
                ),
                SizedBox(width: ResponsiveHelper.getSpacing(context, 8.0)),
                Expanded(
                  child: Text(
                    benefit,
                    style: TextStyle(
                      fontSize: ResponsiveHelper.getCaptionFontSize(context),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
        if (additionalContent != null) ...[
          SizedBox(height: ResponsiveHelper.getSpacing(context, 16.0)),
          additionalContent,
        ],
      ],
    );
  }

  /// Creates responsive dialog action buttons
  static List<Widget> createResponsiveDialogActions({
    required BuildContext context,
    String? cancelText,
    String? confirmText,
    VoidCallback? onCancel,
    VoidCallback? onConfirm,
    Color? confirmButtonColor,
    bool isDangerous = false,
  }) {
    return [
      if (cancelText != null)
        TextButton(
          onPressed: onCancel,
          child: Text(
            cancelText,
            style: TextStyle(
              color: isDangerous ? Colors.grey : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getCaptionFontSize(context),
            ),
          ),
        ),
      if (confirmText != null)
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmButtonColor ?? (isDangerous ? Colors.red : kMainColor),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: ResponsiveHelper.getButtonPadding(context),
          ),
          child: Text(
            confirmText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getCaptionFontSize(context),
            ),
          ),
        ),
    ];
  }

  /// Creates a responsive information box for dialogs
  static Widget createResponsiveInfoBox({
    required BuildContext context,
    required String title,
    required List<String> steps,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getSpacing(context, 12.0)),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getCaptionFontSize(context),
            ),
          ),
          SizedBox(height: ResponsiveHelper.getSpacing(context, 4.0)),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final step = entry.value;
            return Padding(
              padding: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, 1.0)),
              child: Text(
                '$index. $step',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                  height: 1.2,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Shows a responsive permission dialog
  static Future<bool> showPermissionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required List<String> benefits,
    String cancelText = 'Niet Nu',
    String confirmText = 'Toestaan',
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return createResponsiveAlertDialog(
          context: context,
          title: createResponsiveDialogTitle(
            context: context,
            title: title,
            icon: icon,
          ),
          content: createResponsiveDialogContent(
            context: context,
            message: message,
            benefits: benefits,
          ),
          actions: createResponsiveDialogActions(
            context: context,
            cancelText: cancelText,
            confirmText: confirmText,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        );
      },
    ) ?? false;
  }

  /// Shows a responsive settings dialog
  static Future<void> showSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
    required List<String> steps,
    String buttonText = 'Ga naar Instellingen',
    VoidCallback? onSettingsPressed,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return createResponsiveAlertDialog(
          context: context,
          title: createResponsiveDialogTitle(
            context: context,
            title: title,
            icon: Icons.settings,
            iconColor: Colors.orange,
          ),
          content: createResponsiveDialogContent(
            context: context,
            message: message,
            additionalContent: createResponsiveInfoBox(
              context: context,
              title: 'Stappen:',
              steps: steps,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Annuleren',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onSettingsPressed?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: ResponsiveHelper.getButtonPadding(context),
              ),
              child: Text(
                buttonText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveHelper.getCaptionFontSize(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Shows a responsive confirmation dialog
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    IconData icon = Icons.warning,
    String cancelText = 'Annuleren',
    String confirmText = 'Bevestigen',
    bool isDangerous = false,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => createResponsiveAlertDialog(
        context: context,
        title: createResponsiveDialogTitle(
          context: context,
          title: title,
          icon: icon,
          iconColor: isDangerous ? Colors.red : kMainColor,
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: ResponsiveHelper.getBodyFontSize(context),
            height: 1.4,
          ),
        ),
        actions: createResponsiveDialogActions(
          context: context,
          cancelText: cancelText,
          confirmText: confirmText,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
          isDangerous: isDangerous,
        ),
      ),
    ) ?? false;
  }
} 