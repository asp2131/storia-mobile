import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import 'sketch_border.dart';

class SketchTextField extends StatelessWidget {
  const SketchTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.leading,
    this.suffix,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? leading;
  final Widget? suffix;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w800,
      fontStyle: FontStyle.italic,
      color: StoriaColors.ink,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Text(label, style: labelStyle),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          onSubmitted: onSubmitted,
          cursorColor: StoriaColors.ink,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: StoriaColors.ink,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            filled: true,
            fillColor: StoriaColors.paperAlt,
            prefixIcon: leading,
            suffixIcon: suffix,
            prefixIconColor: StoriaColors.ink,
            suffixIconColor: StoriaColors.ink,
            iconColor: StoriaColors.ink,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: _border(StoriaColors.line),
            enabledBorder: _border(StoriaColors.line),
            focusedBorder: _border(StoriaColors.dustyPink),
            errorBorder: _border(StoriaColors.danger),
            focusedErrorBorder: _border(StoriaColors.danger),
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: StoriaColors.ink.withValues(alpha: 0.56),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  InputBorder _border(Color color) {
    return OutlineInputBorder(
      borderRadius: sketchBorderRadius(0.82).resolve(TextDirection.ltr),
      borderSide: BorderSide(color: color, width: 1.2),
    );
  }
}
