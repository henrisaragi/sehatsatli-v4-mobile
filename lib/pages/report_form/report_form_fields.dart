import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Small form building blocks shared by the laporan wizard pages.
class FormTextArea extends StatelessWidget {
  const FormTextArea({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint = 'Tulis di sini...',
    this.required = false,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormLabel(label, required: required),
        SizedBox(height: 6.0),
        Container(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.alternate),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: TextFormField(
            initialValue: value,
            minLines: 3,
            maxLines: 6,
            onChanged: onChanged,
            style: theme.bodyMedium,
            decoration: InputDecoration(border: InputBorder.none, hintText: hint),
          ),
        ),
      ],
    );
  }
}

class FormLabel extends StatelessWidget {
  const FormLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required) TextSpan(text: ' *', style: TextStyle(color: theme.error)),
        ],
      ),
      style: theme.labelMedium.override(
        color: theme.primaryText,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class FormSwitchRow extends StatelessWidget {
  const FormSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      children: [
        Expanded(child: Text(label, style: theme.bodyMedium)),
        Switch(value: value, onChanged: onChanged, activeColor: theme.primary),
      ],
    );
  }
}

class FormSubmitButton extends StatelessWidget {
  const FormSubmitButton({
    super.key,
    required this.label,
    required this.isSaving,
    required this.onPressed,
  });

  final String label;
  final bool isSaving;

  /// Null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return ElevatedButton(
      onPressed: isSaving ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primary,
        foregroundColor: theme.onPrimary,
        padding: EdgeInsets.symmetric(vertical: 14.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
      child: isSaving
          ? SizedBox(
              width: 18.0,
              height: 18.0,
              child: CircularProgressIndicator(strokeWidth: 2.0, color: theme.onPrimary),
            )
          : Text(label),
    );
  }
}

/// Read-only label/value pair for completed stages.
class FormReadonlyRow extends StatelessWidget {
  const FormReadonlyRow({super.key, required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.bodySmall.override(color: theme.secondaryText)),
          SizedBox(height: 2.0),
          Text(
            (value == null || value!.trim().isEmpty) ? '-' : value!,
            style: theme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Shown under a disabled submit button.
/// Under a disabled submit button: which fields still block it.
class FormMissingHint extends StatelessWidget {
  const FormMissingHint({super.key, required this.missing});

  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: 8.0),
      child: Text(
        'Belum lengkap: ${missing.join(', ')}.',
        textAlign: TextAlign.center,
        style: theme.bodySmall.override(color: theme.error),
      ),
    );
  }
}
