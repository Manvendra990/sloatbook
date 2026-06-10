import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slotbooking/data/theam/app_theam.dart';

/// A row of 6 OTP digit boxes.
///
/// Usage:
/// ```dart
/// OtpInput(
///   onCompleted: (otp) => _verifyOtp(otp),
///   onChanged: (otp) => setState(() => _otp = otp),
/// )
/// ```
class OtpInput extends StatefulWidget {
  /// Called when all 6 digits are filled. Receives the full OTP string.
  final ValueChanged<String>? onCompleted;

  /// Called on every keystroke with the current partial/full OTP string.
  final ValueChanged<String>? onChanged;

  /// Externally clear the boxes by incrementing this key's value.
  final int resetTrigger;

  const OtpInput({
    super.key,
    this.onCompleted,
    this.onChanged,
    this.resetTrigger = 0,
  });

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void didUpdateWidget(OtpInput old) {
    super.didUpdateWidget(old);
    if (widget.resetTrigger != old.resetTrigger) {
      _clearAll();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _clearAll() {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
    setState(() {});
    widget.onChanged?.call('');
  }

  void requestFirstFocus() => _focusNodes[0].requestFocus();

  String get _current => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String val) {
    if (val.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
    final otp = _current;
    widget.onChanged?.call(otp);
    if (otp.length == 6) widget.onCompleted?.call(otp);
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        6,
        (i) => _OtpBox(
          controller: _controllers[i],
          focusNode: _focusNodes[i],
          onChanged: (val) => _onChanged(i, val),
          onBackspace: () => _onBackspace(i),
        ),
      ),
    );
  }
}

// ── Single OTP digit box ──────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: controller.text.isNotEmpty
                ? AppTheme.lightRed
                : AppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: controller.text.isNotEmpty
                    ? AppTheme.primaryRed
                    : Colors.grey.shade200,
                width: controller.text.isNotEmpty ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryRed,
                width: 2,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
