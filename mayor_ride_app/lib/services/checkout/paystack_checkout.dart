/// Single entry point for Paystack checkout.
///
/// Mobile opens the Paystack popup inside a WebView; web calls the popup
/// script that `web/index.html` already loads. Both implementations expose
/// `startPaystackCheckout` and return a [PaystackResult].
library;

export 'paystack_request.dart';
export 'paystack_checkout_mobile.dart'
    if (dart.library.js_interop) 'paystack_checkout_web.dart';
