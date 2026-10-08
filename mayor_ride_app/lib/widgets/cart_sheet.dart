import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/cart_item.dart';
import '../models/shop_order.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/session_provider.dart';
import '../services/checkout/paystack_checkout.dart';
import '../theme/app_theme.dart';
import 'money.dart';
import 'network_or_asset_image.dart';

/// Ports the `#cartDrawer` markup and checkout flow from cart.js: line items,
/// the delivery/pickup switch, the running total, and the Paystack button.
Future<void> showCartSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CartSheet(),
  );
}

class _CartSheet extends StatefulWidget {
  const _CartSheet();

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _locationController = TextEditingController();
  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _locationController.text = context.read<CartProvider>().deliveryLocation;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    final orders = context.read<OrderProvider>();
    final session = context.read<SessionProvider>();
    final user = session.currentUser;

    if (cart.isEmpty || user == null) return;

    if (cart.needsDeliveryLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your delivery location before continuing.'),
        ),
      );
      return;
    }

    setState(() => _checkingOut = true);

    final result = await startPaystackCheckout(
      context,
      PaystackRequest(
        email: user.email,
        amount: cart.grandTotal,
        customerName: user.name,
        collectionMethod: cart.deliveryMethod.value,
        deliveryLocation: cart.deliveryLocation,
      ),
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _checkingOut = false);
      final message = result.status == PaystackStatus.cancelled
          ? result.message!
          : (result.message ?? 'Payment could not be started. Please try again.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final order = cart.buildOrder(user: user, reference: result.reference!);
    await orders.submit(order);
    await cart.clear();

    if (!mounted) return;
    setState(() => _checkingOut = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment completed. Your order has been placed.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final session = context.watch<SessionProvider>();
    final orders = context.watch<OrderProvider>();
    final userOrders = session.currentUser == null
        ? const <ShopOrder>[]
        : orders.ordersFor(session.currentUser!.id);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.lightBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Eyebrow('Your ride kit'),
                      SizedBox(height: 4),
                      Text('Shopping cart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cart.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Your cart is waiting for its first piece of gear.',
                  style: TextStyle(color: AppColors.mutedText),
                ),
              )
            else
              ...cart.items.map((item) => _CartLine(item: item)),

            if (userOrders.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Your orders', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...userOrders.map((order) => _OrderStatusRow(order: order)),
            ],

            const SizedBox(height: 20),
            const Divider(color: AppColors.line),
            const SizedBox(height: 12),
            _SummaryLine(label: 'Subtotal', value: cart.subtotal),
            const SizedBox(height: 10),
            const Text('Collection method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            RadioGroup<DeliveryMethod>(
              groupValue: cart.deliveryMethod,
              onChanged: (value) => cart.setDeliveryMethod(value!),
              child: Column(
                children: [
                  RadioListTile<DeliveryMethod>(
                    value: DeliveryMethod.delivery,
                    title: Text('Delivery  ·  ${formatMoney(AppConfig.deliveryFee)}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  RadioListTile<DeliveryMethod>(
                    value: DeliveryMethod.pickup,
                    title: Text('Pickup  ·  ${formatMoney(AppConfig.pickupFee)}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),
            if (cart.deliveryMethod == DeliveryMethod.delivery) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _locationController,
                onChanged: cart.setDeliveryLocation,
                decoration: const InputDecoration(
                  labelText: 'Delivery location (required for delivery)',
                  hintText: 'Town, area, and delivery address',
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SummaryLine(label: 'Service cost', value: cart.serviceFee),
            const SizedBox(height: 8),
            _SummaryLine(label: 'Grand total', value: cart.grandTotal, emphasize: true),
            const SizedBox(height: 6),
            const Text(
              'Pay securely with card, bank transfer, or mobile money.',
              style: TextStyle(color: AppColors.mutedText, fontSize: 12),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: (cart.isEmpty || _checkingOut) ? null : _checkout,
              child: _checkingOut
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay with Paystack'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: NetworkOrAssetImage(
              source: item.image,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(formatMoney(item.price), style: const TextStyle(color: AppColors.mutedText)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _StepperButton(icon: Icons.remove, onTap: () => cart.decrease(item.id)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('${item.quantity}'),
                    ),
                    _StepperButton(icon: Icons.add, onTap: () => cart.increase(item.id)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => cart.remove(item.id),
                      child: const Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(icon, size: 14),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.emphasize = false});

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)
        : const TextStyle(fontWeight: FontWeight.w600);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: emphasize ? style : const TextStyle(color: AppColors.mutedText)),
        Text(formatMoney(value), style: style),
      ],
    );
  }
}

class _OrderStatusRow extends StatelessWidget {
  const _OrderStatusRow({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order ${order.shortId}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                _formatDate(order.paidAt),
                style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
              ),
            ],
          ),
          _StatusBadge(delivered: order.deliveryConfirmed),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.delivered});

  final bool delivered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: delivered ? AppColors.success.withValues(alpha: 0.18) : AppColors.primary.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        delivered ? 'Delivered' : 'Payment confirmed',
        style: TextStyle(
          color: delivered ? AppColors.success : AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
