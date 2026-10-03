/// Circle card payment form widget for the PayRogen Flutter SDK.
///
/// Matches the web form (circle-card-form.tsx) exactly — same fields,
/// same validation, same data sent to the server. Country dropdown with
/// all Circle-supported countries, state/province dropdown for US/CA.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../circle_service.dart';

/// Callback when Circle payment is completed successfully.
typedef OnCirclePaymentComplete = void Function(CirclePaymentResult result);

/// Callback when Circle payment fails.
typedef OnCirclePaymentError = void Function(String error);

/// Circle-supported countries (ISO 3166-1 alpha-2).
/// Countries requiring a 2-char district (state/province): US, CA.
class _Country {
  final String code;
  final String name;
  final bool requiresDistrict;
  const _Country(this.code, this.name, {this.requiresDistrict = false});
}

const _countries = <_Country>[
  _Country('US', 'United States', requiresDistrict: true),
  _Country('CA', 'Canada', requiresDistrict: true),
  _Country('GB', 'United Kingdom'),
  _Country('NG', 'Nigeria'),
  _Country('GH', 'Ghana'),
  _Country('KE', 'Kenya'),
  _Country('ZA', 'South Africa'),
  _Country('DE', 'Germany'),
  _Country('FR', 'France'),
  _Country('ES', 'Spain'),
  _Country('IT', 'Italy'),
  _Country('NL', 'Netherlands'),
  _Country('PT', 'Portugal'),
  _Country('IE', 'Ireland'),
  _Country('SE', 'Sweden'),
  _Country('NO', 'Norway'),
  _Country('DK', 'Denmark'),
  _Country('FI', 'Finland'),
  _Country('CH', 'Switzerland'),
  _Country('AT', 'Austria'),
  _Country('BE', 'Belgium'),
  _Country('PL', 'Poland'),
  _Country('CZ', 'Czechia'),
  _Country('RO', 'Romania'),
  _Country('HU', 'Hungary'),
  _Country('BG', 'Bulgaria'),
  _Country('HR', 'Croatia'),
  _Country('AU', 'Australia'),
  _Country('NZ', 'New Zealand'),
  _Country('JP', 'Japan'),
  _Country('SG', 'Singapore'),
  _Country('HK', 'Hong Kong'),
  _Country('KR', 'Republic of Korea'),
  _Country('TW', 'Taiwan'),
  _Country('IL', 'Israel'),
  _Country('AE', 'United Arab Emirates'),
  _Country('SA', 'Saudi Arabia'),
  _Country('BR', 'Brazil'),
  _Country('MX', 'Mexico'),
  _Country('CO', 'Colombia'),
  _Country('AR', 'Argentina'),
  _Country('CL', 'Chile'),
  _Country('PE', 'Peru'),
  _Country('EG', 'Egypt'),
  _Country('MA', 'Morocco'),
  _Country('TN', 'Tunisia'),
  _Country('PH', 'Philippines'),
  _Country('TH', 'Thailand'),
  _Country('MY', 'Malaysia'),
  _Country('ID', 'Indonesia'),
  _Country('VN', 'Vietnam'),
  _Country('IN', 'India'),
  _Country('TR', 'Turkey'),
];

/// US states + DC (51 total).
const _usStates = <String, String>{
  'AL': 'Alabama', 'AK': 'Alaska', 'AZ': 'Arizona', 'AR': 'Arkansas',
  'CA': 'California', 'CO': 'Colorado', 'CT': 'Connecticut', 'DE': 'Delaware',
  'DC': 'District of Columbia', 'FL': 'Florida', 'GA': 'Georgia', 'HI': 'Hawaii',
  'ID': 'Idaho', 'IL': 'Illinois', 'IN': 'Indiana', 'IA': 'Iowa',
  'KS': 'Kansas', 'KY': 'Kentucky', 'LA': 'Louisiana', 'ME': 'Maine',
  'MD': 'Maryland', 'MA': 'Massachusetts', 'MI': 'Michigan', 'MN': 'Minnesota',
  'MS': 'Mississippi', 'MO': 'Missouri', 'MT': 'Montana', 'NE': 'Nebraska',
  'NV': 'Nevada', 'NH': 'New Hampshire', 'NJ': 'New Jersey', 'NM': 'New Mexico',
  'NY': 'New York', 'NC': 'North Carolina', 'ND': 'North Dakota', 'OH': 'Ohio',
  'OK': 'Oklahoma', 'OR': 'Oregon', 'PA': 'Pennsylvania', 'RI': 'Rhode Island',
  'SC': 'South Carolina', 'SD': 'South Dakota', 'TN': 'Tennessee', 'TX': 'Texas',
  'UT': 'Utah', 'VT': 'Vermont', 'VA': 'Virginia', 'WA': 'Washington',
  'WV': 'West Virginia', 'WI': 'Wisconsin', 'WY': 'Wyoming',
};

/// Canadian provinces and territories (13 total).
const _caProvinces = <String, String>{
  'AB': 'Alberta', 'BC': 'British Columbia', 'MB': 'Manitoba',
  'NB': 'New Brunswick', 'NL': 'Newfoundland and Labrador',
  'NS': 'Nova Scotia', 'NT': 'Northwest Territories', 'NU': 'Nunavut',
  'ON': 'Ontario', 'PE': 'Prince Edward Island', 'QC': 'Quebec',
  'SK': 'Saskatchewan', 'YT': 'Yukon',
};

/// A native card entry form for Circle Payments via PayRogen.
class CircleCardForm extends StatefulWidget {
  final String gatewayBaseUrl;
  final String paymentCode;
  final String amount;
  final String email;
  final OnCirclePaymentComplete? onPaymentComplete;
  final OnCirclePaymentError? onPaymentError;
  final Color? accentColor;

  const CircleCardForm({
    super.key,
    required this.gatewayBaseUrl,
    required this.paymentCode,
    required this.amount,
    required this.email,
    this.onPaymentComplete,
    this.onPaymentError,
    this.accentColor,
  });

  @override
  State<CircleCardForm> createState() => _CircleCardFormState();
}

class _CircleCardFormState extends State<CircleCardForm> {
  final _formKey = GlobalKey<FormState>();

  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String _selectedCountry = 'US';
  String? _selectedDistrict;
  bool _isProcessing = false;
  String? _error;

  Color get _accentColor => widget.accentColor ?? const Color(0xFF4F46E5);
  _Country get _currentCountry => _countries.firstWhere((c) => c.code == _selectedCountry);
  bool get _requiresDistrict => _currentCountry.requiresDistrict;
  Map<String, String> get _districtOptions =>
      _selectedCountry == 'CA' ? _caProvinces : _usStates;
  String get _districtLabel => _selectedCountry == 'CA' ? 'Province' : 'State';

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: Colors.green[400]),
                const SizedBox(width: 8),
                Text(
                  'Secure payment powered by PayRogen',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Card Number
          _buildTextField(label: 'Card Number', controller: _cardNumberController, hint: '4007 4000 0000 0007',
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter(), LengthLimitingTextInputFormatter(19)],
            validator: (v) { final d = v?.replaceAll(' ', '') ?? ''; return d.length < 13 ? 'Enter a valid card number' : null; }),
          const SizedBox(height: 14),

          // Expiry + CVV
          Row(children: [
            Expanded(child: _buildTextField(label: 'Expiry', controller: _expiryController, hint: 'MM/YY',
              keyboardType: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter(), LengthLimitingTextInputFormatter(5)],
              validator: (v) => (v == null || !RegExp(r'^\d{2}/\d{2}$').hasMatch(v)) ? 'MM/YY' : null)),
            const SizedBox(width: 12),
            Expanded(child: _buildTextField(label: 'CVV', controller: _cvvController, hint: '123',
              keyboardType: TextInputType.number, obscure: true,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
              validator: (v) => (v == null || v.length < 3) ? 'Invalid' : null)),
          ]),
          const SizedBox(height: 14),

          // Cardholder Name
          _buildTextField(label: 'Cardholder Name', controller: _nameController, hint: 'John Doe',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null),
          const SizedBox(height: 14),

          // Email
          _buildTextField(label: 'Email', controller: _emailController, hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null),
          const SizedBox(height: 14),

          // Country dropdown
          _buildLabel('Country'),
          const SizedBox(height: 6),
          _buildDropdown<String>(
            value: _selectedCountry,
            items: _countries.map((c) => DropdownMenuItem(value: c.code, child: Text(c.name))).toList(),
            onChanged: (v) => setState(() { _selectedCountry = v ?? 'US'; _selectedDistrict = null; }),
          ),
          const SizedBox(height: 14),

          // Street Address
          _buildTextField(label: 'Street Address', controller: _addressController, hint: '123 Main St',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null),
          const SizedBox(height: 14),

          // City + State/Province (conditional) + Postal
          Row(children: [
            Expanded(flex: 2, child: _buildTextField(label: 'City', controller: _cityController, hint: 'New York',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
            if (_requiresDistrict) ...[
              const SizedBox(width: 10),
              Expanded(flex: 2, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(_districtLabel),
                  const SizedBox(height: 6),
                  _buildDropdown<String>(
                    value: _selectedDistrict,
                    hint: 'Select',
                    items: _districtOptions.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _selectedDistrict = v),
                  ),
                ],
              )),
            ],
            const SizedBox(width: 10),
            Expanded(flex: 2, child: _buildTextField(label: 'Postal Code', controller: _postalCodeController, hint: '10001',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
          ]),
          const SizedBox(height: 20),

          // Error
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),

          // Pay button
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _submitPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor, foregroundColor: Colors.white,
                disabledBackgroundColor: _accentColor.withValues(alpha: 0.5),
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _isProcessing
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text('Pay \$${widget.amount}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_rounded, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text('Card data encrypted locally • Never stored', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ])),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87));
  }

  Widget _buildTextField({
    required String label, required TextEditingController controller, required String hint,
    TextInputType? keyboardType, bool obscure = false,
    List<TextInputFormatter>? formatters, String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabel(label),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller, keyboardType: keyboardType, obscureText: obscure,
        inputFormatters: formatters, validator: validator,
        style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accentColor, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
          filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
        ),
      ),
    ]);
  }

  Widget _buildDropdown<T>({T? value, String? hint, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<T>(
      initialValue: value, hint: hint != null ? Text(hint) : null, items: items, onChanged: onChanged,
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accentColor, width: 1.5)),
        filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
      ),
      dropdownColor: isDark ? const Color(0xFF252640) : Colors.white,
      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
    );
  }

  /// Submits to the server — sends EXACT same fields as the web circle-card-form.tsx:
  /// email, card_number, cvv, key_id, public_key, cardholder_name,
  /// exp_month, exp_year, billing_city, billing_country, billing_line1,
  /// billing_district (if US/CA), billing_postal_code, idempotency_key, amount
  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiresDistrict && (_selectedDistrict == null || _selectedDistrict!.isEmpty)) {
      setState(() => _error = 'Please select a ${_districtLabel.toLowerCase()}');
      return;
    }

    setState(() { _isProcessing = true; _error = null; });

    try {
      debugPrint('[CircleCardForm] widget.gatewayBaseUrl: ${widget.gatewayBaseUrl}');
      debugPrint('[CircleCardForm] widget.paymentCode: ${widget.paymentCode}');
      final service = CircleService(
        gatewayBaseUrl: widget.gatewayBaseUrl,
        // payBaseUrl MUST be pay.payrogen.com — that's where the card-order Next.js route lives.
        // The gatewayBaseUrl points to the Go API which doesn't have /api/pay/{code}/card-order.
      );
      debugPrint('[CircleCardForm] service.payBaseUrl: ${service.payBaseUrl}');
      debugPrint('[CircleCardForm] service.gatewayBaseUrl: ${service.gatewayBaseUrl}');

      // Fetch encryption key (for key_id + public_key)
      final encKey = await service.getEncryptionKey();
      debugPrint('[CircleCardForm] encKey fetched: keyId=${encKey.keyId}, publicKey length=${encKey.publicKey.length}');

      // Parse expiry
      final parts = _expiryController.text.split('/');
      final expMonth = int.parse(parts[0]);
      final expYear = 2000 + int.parse(parts[1]);

      // Submit — same fields as web form
      final result = await service.processPayment(
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        cvv: _cvvController.text,
        keyId: encKey.keyId,
        publicKey: encKey.publicKey,
        amount: widget.amount,
        email: _emailController.text.trim(),
        cardholderName: _nameController.text.trim(),
        expMonth: expMonth,
        expYear: expYear,
        billingCity: _cityController.text.trim(),
        billingCountry: _selectedCountry,
        billingLine1: _addressController.text.trim(),
        billingPostalCode: _postalCodeController.text.trim(),
        billingDistrict: _requiresDistrict ? _selectedDistrict : null,
        paymentCode: widget.paymentCode,
      );

      widget.onPaymentComplete?.call(result);
      service.close();
    } on CircleServiceException catch (e) {
      setState(() => _error = e.message);
      widget.onPaymentError?.call(e.message);
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = 'Payment failed: $msg');
      widget.onPaymentError?.call(msg);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

/// Formats card number with spaces every 4 digits.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(text[i]);
    }
    return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
  }
}

/// Formats expiry as MM/YY.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i == 2) buf.write('/');
      buf.write(text[i]);
    }
    return TextEditingValue(text: buf.toString(), selection: TextSelection.collapsed(offset: buf.length));
  }
}
