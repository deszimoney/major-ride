import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_config.dart';
import '../../theme/app_theme.dart';
import 'paystack_request.dart';

/// Android/iOS checkout: the Paystack popup runs in a WebView and reports its
/// outcome back over a JavaScript channel.
Future<PaystackResult> startPaystackCheckout(
  BuildContext context,
  PaystackRequest request,
) async {
  if (!AppConfig.paystackReady) {
    return const PaystackResult.error(
      'Paystack is not configured yet. Add your public key in app_config.dart.',
    );
  }

  final result = await Navigator.of(context).push<PaystackResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _PaystackWebViewPage(request: request),
    ),
  );

  return result ?? const PaystackResult.cancelled();
}

class _PaystackWebViewPage extends StatefulWidget {
  const _PaystackWebViewPage({required this.request});

  final PaystackRequest request;

  @override
  State<_PaystackWebViewPage> createState() => _PaystackWebViewPageState();
}

class _PaystackWebViewPageState extends State<_PaystackWebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.darkBg)
      ..addJavaScriptChannel(
        'PaystackBridge',
        onMessageReceived: _handleBridgeMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Sub-resource failures are noisy; only a failed main frame matters.
            if (error.isForMainFrame ?? false) {
              _settle(
                const PaystackResult.error(
                  'The Paystack payment service could not be loaded. '
                  'Please check your connection and try again.',
                ),
              );
            }
          },
        ),
      )
      // A real https base URL is required: the popup script refuses to run
      // from an opaque `data:` origin.
      ..loadHtmlString(
        _buildCheckoutPage(widget.request),
        baseUrl: AppConfig.checkoutOrigin,
      );
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(message.message);
      payload = decoded is Map ? decoded.cast<String, dynamic>() : const {};
    } on FormatException {
      payload = const {};
    }

    final reference = payload['reference'] as String?;
    switch (payload['event']) {
      case 'success' when reference != null && reference.isNotEmpty:
        _settle(PaystackResult.success(reference));
      case 'cancel':
        _settle(const PaystackResult.cancelled());
      case 'error':
        _settle(
          PaystackResult.error(
            (payload['message'] as String?)?.isNotEmpty == true
                ? payload['message'] as String
                : 'Payment could not be started. Please try again.',
          ),
        );
      default:
        _settle(
          const PaystackResult.error(
            'Payment could not be confirmed. Please try again.',
          ),
        );
    }
  }

  void _settle(PaystackResult result) {
    if (_settled || !mounted) return;
    _settled = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightBg,
        title: const Text('Secure payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel payment',
          onPressed: () => _settle(const PaystackResult.cancelled()),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const ColoredBox(
              color: AppColors.darkBg,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The page hosted in the WebView. It is the Flutter equivalent of the
/// `PaystackPop().newTransaction(...)` call in cart.js.
String _buildCheckoutPage(PaystackRequest request) {
  // Escape "</script" so a customer name or delivery address containing that
  // sequence can't break out of this inline <script> block.
  final options = jsonEncode(
    request.toPopupOptions(),
  ).replaceAll('</script', r'<\/script');

  return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Secure payment</title>
<style>
  html, body {
    margin: 0;
    min-height: 100%;
    background: #102020;
    color: #f7f3ec;
    font-family: Georgia, 'Times New Roman', serif;
  }
  .status {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    padding: 24px;
    text-align: center;
    line-height: 1.6;
  }
</style>
</head>
<body>
<div class="status"><p>Opening the secure Paystack window…</p></div>
<script src="https://js.paystack.co/v2/inline.js"></script>
<script>
  (function () {
    var settled = false;

    function report(payload) {
      if (settled) return;
      settled = true;
      PaystackBridge.postMessage(JSON.stringify(payload));
    }

    function start() {
      if (typeof window.PaystackPop !== 'function') {
        report({ event: 'error', message: 'The Paystack payment service could not be loaded. Please check your connection and try again.' });
        return;
      }

      var options = $options;
      options.onSuccess = function (transaction) {
        report({ event: 'success', reference: transaction.reference });
      };
      options.onCancel = function () {
        report({ event: 'cancel' });
      };
      options.onError = function (error) {
        report({ event: 'error', message: error && error.message ? error.message : '' });
      };

      try {
        new window.PaystackPop().newTransaction(options);
      } catch (error) {
        report({ event: 'error', message: error && error.message ? error.message : '' });
      }
    }

    if (document.readyState === 'complete') start();
    else window.addEventListener('load', start);
  })();
</script>
</body>
</html>
''';
}
