import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stripe_sdk_plus/src/stripe_error.dart';
import 'package:stripe_sdk_plus/src/ui/stripe_ui.dart';

import '../stripe.dart';
import 'models.dart';
import 'progress_bar.dart';
import 'stores/payment_method_store.dart';
import 'widgets/payment_method_selector.dart';

class CheckoutPage extends StatefulWidget {
  final Future<IntentClientSecret> Function() createPaymentIntent;
  final void Function(BuildContext context, Map<String, dynamic> paymentIntent)
      onPaymentSuccess;
  final void Function(BuildContext context, Map<String, dynamic> paymentIntent)
      onPaymentFailed;
  final void Function(BuildContext context, StripeApiException e)
      onPaymentError;

  CheckoutPage({
    Key? key,
    required this.createPaymentIntent,
    void Function(BuildContext context, Map<String, dynamic> paymentIntent)?
        onPaymentSuccess,
    void Function(BuildContext context, Map<String, dynamic> paymentIntent)?
        onPaymentFailed,
    void Function(BuildContext, StripeApiException)? onPaymentError,
  })  : onPaymentSuccess = onPaymentSuccess ?? StripeUiOptions.onPaymentSuccess,
        onPaymentFailed = onPaymentFailed ?? StripeUiOptions.onPaymentFailed,
        onPaymentError = onPaymentError ?? StripeUiOptions.onPaymentError,
        super(key: key);

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

// ignore: deprecated_member_use_from_same_package
class _CheckoutPageState extends State<CheckoutPage> {
  final PaymentMethodStore paymentMethodStore = PaymentMethodStore.instance;

  String? _selectedPaymentMethod;
  late Future<IntentClientSecret> _clientSecretFuture;
  late Future<Map<String, dynamic>> paymentIntentFuture;

  @override
  void initState() {
    _clientSecretFuture = widget.createPaymentIntent();
    paymentIntentFuture = _clientSecretFuture.then((value) =>
        Stripe.instance.api.retrievePaymentIntent(value.clientSecret));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Center(
            child: PaymentMethodSelector(
              paymentMethodStore: paymentMethodStore,
              initialPaymentMethodId: null,
              onChanged: (value) => setState(
                () {
                  _selectedPaymentMethod = value;
                  debugPrint("Selected paymentMethod changed: $value");
                },
              ),
            ),
          ),
          FutureBuilder<Map<String, dynamic>>(
              future: paymentIntentFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint(snapshot.error.toString());
                }
                if (snapshot.hasData) {
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: StripeUiOptions.payButtonBuilder(
                        context,
                        snapshot.data!,
                        _selectedPaymentMethod == null
                            ? null
                            : _createAttemptPaymentFunction(
                                context, _clientSecretFuture)),
                  );
                } else {
                  return _selectedPaymentMethod == null
                      ? const SizedBox.shrink()
                      : const Center(
                          child: CircularProgressIndicator(),
                        );
                }
              })
        ],
      ),
    );
  }

  void Function() _createAttemptPaymentFunction(
      BuildContext context, Future<IntentClientSecret> paymentIntentFuture) {
    return () async {
      showProgressDialog(context);
      // ignore: body_might_complete_normally_catch_error
      final initialPaymentIntent =
          // ignore: body_might_complete_normally_catch_error
          await paymentIntentFuture.catchError((error) {
        hideProgressDialog(context);
      });
      try {
        final confirmedPaymentIntent = await Stripe.instance.confirmPayment(
            initialPaymentIntent.clientSecret, context,
            paymentMethodId: _selectedPaymentMethod);
        if (confirmedPaymentIntent['status'] == 'succeeded') {
          widget.onPaymentSuccess(context, confirmedPaymentIntent);
          hideProgressDialog(context);
        } else {
          widget.onPaymentFailed(context, confirmedPaymentIntent);
          hideProgressDialog(context);
        }
      } catch (e) {
        hideProgressDialog(context);
        debugPrint(e.toString());
        if (e is StripeApiException) {
          widget.onPaymentError(context, e);
        } else {
          rethrow;
        }
      }
    };
  }
}
