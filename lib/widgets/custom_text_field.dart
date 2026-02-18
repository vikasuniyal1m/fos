import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final InputBorder? border;
  final InputBorder? enabledBorder;
  final InputBorder? focusedBorder;
  final bool filled;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final int? maxLength;
  final int? maxLines;
  final void Function(String)? onChanged;
  final void Function()? onEditingComplete;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final ValueChanged<String>? onSubmitted;

  const CustomTextField({
    Key? key,
    this.controller,
    this.hintText,
    this.style,
    this.hintStyle,
    this.border,
    this.enabledBorder,
    this.focusedBorder,
    this.filled = false,
    this.fillColor,
    this.contentPadding,
    this.maxLength,
    this.maxLines = 1,
    this.onChanged,
    this.onEditingComplete,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.onSubmitted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: style,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle,
        border: border,
        enabledBorder: enabledBorder,
        focusedBorder: focusedBorder,
        filled: filled,
        fillColor: fillColor,
        contentPadding: contentPadding,
        suffixIcon: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () {
            // Dismiss the keyboard
            FocusManager.instance.primaryFocus?.unfocus();
          },
          color: Colors.grey,
        ),
        prefixIcon: prefixIcon,
      ),
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.done,
    );
  }
}