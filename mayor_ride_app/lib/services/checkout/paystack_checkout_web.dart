import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../config/app_config.dart';
import 'paystack_request.dart';

/// Web checkout: calls the same `PaystackPop` script the original website
/// used, loaded via a `<script>` tag in web/index.html.
Future<PaystackResult> startPaystackCheckout(
  BuildContext context,
  PaystackRequest request,
) async {
  if (!AppConfig.paystackReady) {
    return const PaystackResult.error(
      'Paystack is not configured yet. Add your public key in app_config.dart.',
    );
  }

  if (!_isPaystackAvailable()) {
    return const PaystackResult.error(
      'The Paystack payment service could not be loaded. Please check your '
      'connection and try again.',
    );
  }

  final completer = Completer<PaystackResult>();
  _openPaystackPopup(
    request,
    onSuccess: (reference) {
      if (!completer.isCompleted) {
        completer.complete(PaystackResult.success(reference));
      }
    },
    onCancel: () {
      if (!completer.isCompleted) {
        completer.complete(const PaystackResult.cancelled());
      }
    },
    onError: (message) {
      if (!completer.isCompleted) {
        completer.complete(
          PaystackResult.error(
            message.isEmpty
                ? 'Payment could not be started. Please try again.'
                : message,
          ),
        );
      }
    },
  );

  return completer.future;
}

bool _isPaystackAvailable() =>
    web.window.getProperty('PaystackPop'.toJS).isDefinedAndNotNull;

void _openPaystackPopup(
  PaystackRequest request, {
  required void Function(String reference) onSuccess,
  required void Function() onCancel,
  required void Function(String message) onError,
}) {
  // Built via JSON.parse rather than a hand-written @JS extension type: the
  // options shape (nested custom_fields, variable channel list) is dynamic
  // enough that round-tripping through JSON is far less error-prone than
  // matching JS's structural typing with static interop declarations.
  final json = request.toPopupOptionsJson();
  final options =
      (web.window.getProperty('JSON'.toJS) as JSObject).callMethod(
            'parse'.toJS,
            json.toJS,
          )
          as JSObject;

  options.setProperty(
    'onSuccess'.toJS,
    ((JSObject transaction) {
      final reference = transaction.getProperty('reference'.toJS) as JSString?;
      onSuccess(reference?.toDart ?? '');
    }).toJS,
  );
  options.setProperty(
    'onCancel'.toJS,
    (() {
      onCancel();
    }).toJS,
  );
  options.setProperty(
    'onError'.toJS,
    ((JSAny? error) {
      final message = error.isDefinedAndNotNull
          ? (error as JSObject).getProperty('message'.toJS) as JSString?
          : null;
      onError(message?.toDart ?? '');
    }).toJS,
  );

  final popupCtor = web.window.getProperty('PaystackPop'.toJS) as JSFunction;
  final popup = popupCtor.callAsConstructor<JSObject>();
  popup.callMethod('newTransaction'.toJS, options);
}
