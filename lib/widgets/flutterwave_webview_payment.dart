import 'package:flutter/material.dart';

// Conditional import - only use webview_flutter when available
// This file is only used for Flutterwave payments on mobile
// Desktop builds don't need this functionality

// Stub implementation when webview_flutter is not available
class FlutterwaveWebViewPayment extends StatefulWidget {
  final String paymentUrl;
  final String redirectUrl;
  final Function(Map<String, dynamic>) onSuccess;
  final Function(String) onError;
  final VoidCallback onCancel;

  const FlutterwaveWebViewPayment({
    Key? key,
    required this.paymentUrl,
    required this.redirectUrl,
    required this.onSuccess,
    required this.onError,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<FlutterwaveWebViewPayment> createState() => _FlutterwaveWebViewPaymentState();
}

class _FlutterwaveWebViewPaymentState extends State<FlutterwaveWebViewPayment> {
  @override
  void initState() {
    super.initState();
    // Show error immediately - webview not available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onError('WebView not available on this platform. Please use mobile app for payments.');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Not Available'),
        backgroundColor: const Color(0xFFF5A623),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.payment,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                'Payment Not Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'WebView payments are only available on mobile devices. Please use the mobile app to complete your payment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: widget.onCancel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text(
                  'Go Back',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
