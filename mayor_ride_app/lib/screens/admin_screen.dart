import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/product.dart';
import '../models/shop_order.dart';
import '../providers/catalog_provider.dart';
import '../providers/order_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/money.dart';
import '../widgets/network_or_asset_image.dart';

/// Ports admin.html/admin.js: metrics, financial report, product manager
/// (add/edit/delete with URL or file-upload image), completed payments with
/// a delivery toggle, and the cart-activity feed. Gated to `role == 'admin'`,
/// same rule enforceAdminAccess() used.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _productFormKey = GlobalKey<_ProductFormPanelState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().markActivitySeen();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    if (!session.isAdmin) {
      return AppShell(
        currentRoute: '/admin',
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            children: [
              const Text('Admin access required', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              const Text(
                'Please log in with the admin account to manage products.',
                style: TextStyle(color: AppColors.mutedText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Use email: ${AppConfig.adminEmail} and password: admin123',
                style: const TextStyle(color: AppColors.mutedText),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return AppShell(
      currentRoute: '/admin',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _MetricsRow(),
          const SizedBox(height: 24),
          _ReportPanel(),
          const SizedBox(height: 24),
          _ProductFormPanel(key: _productFormKey),
          const SizedBox(height: 24),
          _ProductListPanel(formKey: _productFormKey),
          const SizedBox(height: 24),
          _OrderListPanel(),
          const SizedBox(height: 24),
          _CartActivityPanel(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 700 ? 4 : 2;

    final metrics = [
      ('Total received', formatMoney(orders.totalReceived)),
      ('Completed orders', '${orders.completedOrderCount}'),
      ('Items sold', '${orders.itemsSoldCount}'),
      ('Pending delivery', '${orders.pendingDeliveryCount}'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final (label, value) = metrics[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panelSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: AppColors.mutedText, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final items = orders.itemsPurchased;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Financial Reports',
            subtitle: 'Completed payments, purchased items, and customer delivery locations.',
          ),
          if (items.isEmpty)
            const Text('Completed payment reports will appear here.', style: TextStyle(color: AppColors.mutedText))
          else ...[
            const Text('Items purchased', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final entry in items.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProductFormPanel extends StatefulWidget {
  const _ProductFormPanel({super.key});

  @override
  State<_ProductFormPanel> createState() => _ProductFormPanelState();
}

class _ProductFormPanelState extends State<_ProductFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _editId;
  String? _existingImage;
  Uint8List? _pickedImageBytes;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void startEdit(Product product) {
    setState(() {
      _editId = product.id;
      _existingImage = product.image;
      _pickedImageBytes = null;
      _nameController.text = product.name;
      _categoryController.text = product.category;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toString();
      _imageUrlController.text = product.image.startsWith('data:') ? '' : product.image;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editId = null;
      _existingImage = null;
      _pickedImageBytes = null;
      _formKey.currentState?.reset();
      _nameController.clear();
      _categoryController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _imageUrlController.clear();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedImageBytes = bytes);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final imageUrl = _imageUrlController.text.trim();
    String image;
    if (_pickedImageBytes != null) {
      image = 'data:image/jpeg;base64,${base64Encode(_pickedImageBytes!)}';
    } else if (imageUrl.isNotEmpty) {
      image = imageUrl;
    } else if (_existingImage != null && _existingImage!.isNotEmpty) {
      image = _existingImage!;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a product photo URL or choose a file to upload.')),
      );
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all product details before saving.')),
      );
      return;
    }

    final product = Product(
      id: _editId ?? 'prod-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _categoryController.text.trim(),
      description: _descriptionController.text.trim(),
      price: price,
      image: image,
    );

    setState(() => _saving = true);
    await context.read<CatalogProvider>().saveProduct(product);
    if (!mounted) return;
    setState(() => _saving = false);

    final wasEdit = _editId != null;
    _cancelEdit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(wasEdit ? 'Product updated successfully.' : 'Product saved successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(
              title: 'Product Manager',
              subtitle: 'Upload new item photos, set prices, and manage the live shop catalog.',
            ),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Product name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(labelText: 'Price (GHS)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || double.tryParse(v.trim()) == null) ? 'Enter a valid price' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL',
                hintText: 'https://example.com/product.jpg',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.upload_outlined, size: 18),
                  label: const Text('Upload photo'),
                ),
                const SizedBox(width: 12),
                if (_pickedImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_pickedImageBytes!, width: 44, height: 44, fit: BoxFit.cover),
                  )
                else if (_existingImage != null && _existingImage!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: NetworkOrAssetImage(source: _existingImage!, width: 44, height: 44),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editId == null ? 'Save Product' : 'Update Product'),
                ),
                if (_editId != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: _cancelEdit, child: const Text('Cancel Edit')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductListPanel extends StatelessWidget {
  const _ProductListPanel({required this.formKey});

  final GlobalKey<_ProductFormPanelState> formKey;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final formState = formKey.currentState;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(title: 'Current Products'),
          if (catalog.products.isEmpty)
            const Text('No products yet. Add your first product from the form above.',
                style: TextStyle(color: AppColors.mutedText))
          else
            for (final product in catalog.products)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: NetworkOrAssetImage(source: product.image, width: 56, height: 56),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(product.category, style: const TextStyle(color: AppColors.mutedText, fontSize: 12)),
                          Text(formatMoney(product.price), style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => formState?.startEdit(product),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove product?'),
                            content: Text('Remove ${product.name} from the shop?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                            ],
                          ),
                        );
                        if (confirmed == true && context.mounted) {
                          await context.read<CatalogProvider>().deleteProduct(product.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _OrderListPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            title: 'Completed Payments',
            subtitle: 'Review paid orders and confirm delivery when the package reaches the customer.',
          ),
          if (orders.orders.isEmpty)
            const Text('No completed payments yet.', style: TextStyle(color: AppColors.mutedText))
          else
            for (final order in orders.orders) _OrderRow(order: order),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final ShopOrder order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Order ${order.shortId}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (order.deliveryConfirmed ? AppColors.success : AppColors.primary)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.deliveryConfirmed ? 'Delivered' : 'Paid',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: order.deliveryConfirmed ? AppColors.success : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${order.userName} · ${order.userEmail}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            order.items.map((item) => '${item.name} x${item.quantity}').join(', '),
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Paid ${order.paidAt.day}/${order.paidAt.month}/${order.paidAt.year} · '
            '${order.deliveryMethod.label} · ${formatMoney(order.total)}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Location: ${order.deliveryLocation.isEmpty ? 'Pickup' : order.deliveryLocation}',
            style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: order.deliveryConfirmed,
                onChanged: (value) =>
                    context.read<OrderProvider>().setDeliveryConfirmed(order.id, value ?? false),
              ),
              const Text('Delivery confirmed', style: TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartActivityPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>();
    final activity = orders.cartActivity;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(title: 'Cart Activity'),
          if (activity.isEmpty)
            const Text('No recent cart activity.', style: TextStyle(color: AppColors.mutedText))
          else
            for (final entry in activity.take(20))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 8),
                      child: Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.accent),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: entry.userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const TextSpan(text: ' added '),
                                TextSpan(text: entry.productName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                TextSpan(text: ' x${entry.quantity}'),
                              ],
                            ),
                          ),
                          Text(
                            '${entry.addedAt.day}/${entry.addedAt.month}/${entry.addedAt.year} · ${entry.userEmail}',
                            style: const TextStyle(color: AppColors.mutedText, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
