import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

/// Ports contact.html. The original form had no submit handler (a plain
/// browser form post to nowhere); here it shows a confirmation locally.
/// Wire this to an email service or Supabase table if replies are needed.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.reset();
    _nameController.clear();
    _emailController.clear();
    _messageController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Thanks for reaching out — we'll get back to you soon.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/contact',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Text('Contact Us', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Have questions? Reach out to us using the form below.',
            style: TextStyle(color: AppColors.mutedText),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your Name'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Your Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: 'Your Message'),
                  maxLines: 5,
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Enter a message' : null,
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: _submit, child: const Text('Send Message')),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.panelSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Visit Us', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(AppConfig.storeLocation, style: const TextStyle(color: AppColors.mutedText)),
                Text('Email: ${AppConfig.storeEmail}', style: const TextStyle(color: AppColors.mutedText)),
                Text('Phone: ${AppConfig.storePhone}', style: const TextStyle(color: AppColors.mutedText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
