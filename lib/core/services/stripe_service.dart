import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';
import '../../shared/widgets/wc_components.dart';

class StripeService {
  static const String publishableKey =
      'pk_test_51TdOz9F7aCK9uZy21I3hQBEOQOMN9mwYYTsaE2E0O179BBr2eiktRvGXU3j3So55Wl5PNPbhShOfOkGoCpHzRN9E00dqv56iSV';

  // ── Payment server URL ────────────────────────────────────────────────────
  //
  // DEBUG / local testing
  //   Run:  cd stripe-server && node server.js
  //   The local Express server listens on port 3000 and uses the Stripe
  //   test key — no Firebase deployment or Blaze plan required.
  //
  // RELEASE / production
  //   Deploy Cloud Functions:  firebase deploy --only functions
  //   Requires Firebase Blaze plan (outbound network calls to Stripe).
  //
  static String get _baseUrl => kDebugMode
      ? 'http://localhost:3000'
      : 'https://us-central1-workconnect-02.cloudfunctions.net';

  static Future<void> initialize() async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Fetches a PaymentIntent then presents the payment UI.
  /// Web  → custom card-input dialog (platform views unsupported on web).
  /// Mobile → native Stripe PaymentSheet.
  /// Returns true on success, false if cancelled.
  ///
  /// Throws a user-friendly [Exception] when the payment server is
  /// unreachable (not deployed / CORS / Spark plan restriction).
  static Future<bool> processCardPayment({
    required double amount,
    required String jobId,
    required String customerId,
    required BuildContext context,
  }) async {
    final amountInCents = (amount * 100).round();

    late http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_baseUrl/createPaymentIntent'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amount':     amountInCents,
              'currency':   'usd',
              'jobId':      jobId,
              'customerId': customerId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      // Network error, CORS block, or timeout — server not reachable.
      throw Exception(
        'Card payment is unavailable right now.\n\n'
        'This usually means the payment server has not been deployed yet. '
        'Run  firebase deploy --only functions  and ensure your Firebase '
        'project is on the Blaze plan (required for outbound API calls).\n\n'
        'You can still complete this job using cash payment.',
      );
    }

    if (response.statusCode != 200) {
      final body = response.body;
      // Give a clear message for common server-side failures.
      if (body.contains('BILLING_DISABLED') || response.statusCode == 403) {
        throw Exception(
          'Card payment requires the Firebase Blaze plan. '
          'Please upgrade at console.firebase.google.com, or use cash payment.',
        );
      }
      throw Exception('Payment server error (${response.statusCode}): $body');
    }

    final clientSecret =
        (jsonDecode(response.body) as Map<String, dynamic>)['clientSecret']
            as String;

    if (kIsWeb) {
      if (!context.mounted) return false;
      return _showWebCardDialog(context, clientSecret, amount);
    } else {
      return _presentPaymentSheet(clientSecret);
    }
  }

  // ── Mobile PaymentSheet ────────────────────────────────────────────────────

  static Future<bool> _presentPaymentSheet(String clientSecret) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'WorkConnect',
        style: ThemeMode.light,
      ),
    );
    try {
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) return false;
      rethrow;
    }
  }

  // ── Web card dialog (no platform views) ───────────────────────────────────

  static Future<bool> _showWebCardDialog(
    BuildContext context,
    String clientSecret,
    double amount,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _WebCardDialog(clientSecret: clientSecret, amount: amount),
    );
    return result ?? false;
  }

  // ── Confirm PaymentIntent via backend ─────────────────────────────────────

  static Future<bool> confirmPaymentIntent({
    required String clientSecret,
    required String paymentMethodId,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/confirmPayment'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'clientSecret': clientSecret,
        'paymentMethodId': paymentMethodId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Confirmation failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['success'] == true;
  }
}

// ── Web card dialog ───────────────────────────────────────────────────────────

class _WebCardDialog extends StatefulWidget {
  const _WebCardDialog({required this.clientSecret, required this.amount});
  final String clientSecret;
  final double amount;

  @override
  State<_WebCardDialog> createState() => _WebCardDialogState();
}

class _WebCardDialogState extends State<_WebCardDialog> {
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvcCtrl    = TextEditingController();
  final _nameCtrl   = TextEditingController();
  bool    _loading = false;
  String? _error;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvcCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final rawNumber  = _numberCtrl.text.replaceAll(' ', '');
    final expiry     = _expiryCtrl.text.split('/');
    final month      = expiry.isNotEmpty ? expiry[0].trim() : '';
    final yearShort  = expiry.length > 1 ? expiry[1].trim() : '';
    final year       = yearShort.length == 2 ? '20$yearShort' : yearShort;
    final cvc        = _cvcCtrl.text.trim();

    if (rawNumber.length < 16 || month.isEmpty || year.length != 4 || cvc.length < 3) {
      setState(() => _error = 'Please fill in all card details correctly.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Step 1 — create PaymentMethod via Stripe (publishable key is safe client-side)
      final pmRes = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_methods'),
        headers: {
          'Authorization': 'Bearer ${StripeService.publishableKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'type': 'card',
          'card[number]':    rawNumber,
          'card[exp_month]': month,
          'card[exp_year]':  year,
          'card[cvc]':       cvc,
        },
      );

      if (pmRes.statusCode != 200) {
        final err = jsonDecode(pmRes.body) as Map<String, dynamic>;
        throw Exception((err['error'] as Map?)?['message'] ?? 'Invalid card details');
      }

      final pmId = (jsonDecode(pmRes.body) as Map<String, dynamic>)['id'] as String;

      // Step 2 — confirm PaymentIntent via Cloud Function
      final ok = await StripeService.confirmPaymentIntent(
        clientSecret: widget.clientSecret,
        paymentMethodId: pmId,
      );

      if (ok && mounted) {
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Payment was not completed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.successLight, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Icon(Icons.credit_card_rounded, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Secure Card Payment',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Text('Amount: \$${widget.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ]),

              const SizedBox(height: 20),
              Container(height: 1, color: AppColors.borderLight),
              const SizedBox(height: 16),

              // Cardholder name
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // Card number
              TextField(
                controller: _numberCtrl,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '4242 4242 4242 4242',
                  prefixIcon: Icon(Icons.credit_card_rounded),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberFormatter(),
                ],
                maxLength: 19,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              ),
              const SizedBox(height: 12),

              // Expiry + CVC
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _expiryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Expiry (MM/YY)',
                      hintText: '12/28',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _ExpiryFormatter(),
                    ],
                    maxLength: 5,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvcCtrl,
                    decoration: const InputDecoration(
                      labelText: 'CVC',
                      hintText: '123',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
              ]),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 10),
                WcNotice(message: _error!, color: AppColors.error, icon: Icons.error_outline_rounded),
              ],

              const SizedBox(height: 12),

              // Test card hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.25), width: 1),
                ),
                child: const Text(
                  'Test card: 4242 4242 4242 4242  ·  12/28  ·  123',
                  style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(children: [
                Expanded(
                  child: WcOutlinedButton(
                    label: 'Cancel',
                    onPressed: _loading ? null : () => Navigator.of(context).pop(false),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: WcPrimaryButton(
                    label: _loading ? 'Processing…' : 'Pay \$${widget.amount.toStringAsFixed(2)}',
                    icon: _loading ? null : Icons.lock_rounded,
                    isLoading: _loading,
                    backgroundColor: AppColors.success,
                    onPressed: _loading ? null : _pay,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Input formatters ──────────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length && i < 16; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length >= 2) {
      final result = '${digits.substring(0, 2)}/${digits.substring(2)}';
      return newValue.copyWith(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
    return newValue;
  }
}
