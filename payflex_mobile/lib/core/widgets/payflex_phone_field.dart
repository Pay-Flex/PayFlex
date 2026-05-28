import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../constants/app_colors.dart';
import '../utils/phone_input_utils.dart';

/// Champ téléphone international : drapeau + indicatif pays, **Togo (+228)** par défaut.
///
/// [completeNumberController] reçoit le numéro complet (ex. `+22890123456`) à chaque saisie.
class PayflexPhoneField extends StatefulWidget {
  const PayflexPhoneField({
    super.key,
    required this.completeNumberController,
    this.hint = 'Numéro de téléphone',
    this.validator,
    this.required = true,
    this.initialCountryCode = 'TG',
    this.textStyle,
  });

  final TextEditingController completeNumberController;
  final String hint;
  final String? Function(String?)? validator;
  final bool required;
  final String initialCountryCode;
  final TextStyle? textStyle;

  @override
  State<PayflexPhoneField> createState() => _PayflexPhoneFieldState();
}

class _PayflexPhoneFieldState extends State<PayflexPhoneField> {
  late final TextEditingController _nationalController;
  String _countryCode = 'TG';

  @override
  void initState() {
    super.initState();
    _countryCode = widget.initialCountryCode;
    _nationalController = TextEditingController();
    _applyStoredCompleteNumber(widget.completeNumberController.text);
    widget.completeNumberController.addListener(_onExternalControllerChanged);
  }

  @override
  void dispose() {
    widget.completeNumberController.removeListener(_onExternalControllerChanged);
    _nationalController.dispose();
    super.dispose();
  }

  void _onExternalControllerChanged() {
    final stored = widget.completeNumberController.text;
    if (stored.isEmpty) {
      if (_nationalController.text.isNotEmpty) {
        _nationalController.clear();
      }
      return;
    }
    final currentComplete = _buildCompleteFromParts();
    if (stored != currentComplete) {
      _applyStoredCompleteNumber(stored);
    }
  }

  void _applyStoredCompleteNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    try {
      final parsed = PhoneNumber.fromCompleteNumber(completeNumber: trimmed);
      if (!mounted) return;
      setState(() {
        _countryCode = parsed.countryISOCode;
        _nationalController.text = parsed.number;
      });
    } catch (_) {
      final digits = PayflexPhoneValidator.digitsOnly(trimmed);
      final country = countries.firstWhere(
        (c) => c.code == widget.initialCountryCode,
        orElse: () => countries.first,
      );
      String national = digits;
      final dialDigits = country.dialCode;
      if (national.startsWith(dialDigits)) {
        national = national.substring(dialDigits.length);
      }
      if (!mounted) return;
      setState(() {
        _countryCode = country.code;
        _nationalController.text = national;
      });
      widget.completeNumberController.text = '+$dialDigits$national';
    }
  }

  String _buildCompleteFromParts() {
    final country = countries.firstWhere(
      (c) => c.code == _countryCode,
      orElse: () => countries.firstWhere((c) => c.code == 'TG'),
    );
    final national = _nationalController.text.replaceAll(RegExp(r'\D'), '');
    if (national.isEmpty) return '';
    return '+${country.dialCode}$national';
  }

  void _syncCompleteNumber(String nationalDigits) {
    final country = countries.firstWhere(
      (c) => c.code == _countryCode,
      orElse: () => countries.firstWhere((c) => c.code == 'TG'),
    );
    final digits = nationalDigits.replaceAll(RegExp(r'\D'), '');
    final complete = digits.isEmpty ? '' : '+${country.dialCode}$digits';
    if (widget.completeNumberController.text != complete) {
      widget.completeNumberController.text = complete;
    }
  }

  InputDecoration _decoration() {
    return InputDecoration(
      hintText: widget.hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        GoogleFonts.inter(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500);

    return IntlPhoneField(
      controller: _nationalController,
      initialCountryCode: _countryCode,
      languageCode: 'fr',
      invalidNumberMessage: 'Numéro invalide',
      disableLengthCheck: true,
      decoration: _decoration(),
      style: style,
      dropdownTextStyle: style.copyWith(fontSize: 14),
      flagsButtonPadding: const EdgeInsets.only(left: 4, right: 4),
      dropdownIcon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.secondary),
      onCountryChanged: (country) {
        setState(() => _countryCode = country.code);
        _syncCompleteNumber(_nationalController.text);
      },
      onChanged: (phone) {
        widget.completeNumberController.text = phone.completeNumber;
      },
      validator: (value) {
        final fromField = value == null ? '' : value.toString().trim();
        final complete = widget.completeNumberController.text.trim().isNotEmpty
            ? widget.completeNumberController.text.trim()
            : fromField;
        if (widget.validator != null) {
          return widget.validator!(complete);
        }
        return PayflexPhoneValidator.validate(complete, required: widget.required);
      },
    );
  }
}
