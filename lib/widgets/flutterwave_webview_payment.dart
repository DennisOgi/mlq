import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts Flutterwave checkout and detects redirect success/cancel.
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
  State<FlutterwaveWebViewPayment> createState() =>
      _FlutterwaveWebViewPaymentState();
}

class _FlutterwaveWebViewPaymentState extends State<FlutterwaveWebViewPayment> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _successDetected = false;
  String? _lastTxRef;
  String? _lastTransactionId;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    debugPrint('🔑 [FlutterwaveWebView] Loading payment URL');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('🔑 [FlutterwaveWebView] Loading: $progress%');
          },
          onNavigationRequest: (NavigationRequest request) {
            _handleNavigation(request.url);
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            debugPrint('🔑 [FlutterwaveWebView] Page started: $url');
            _handleNavigation(url);
          },
          onPageFinished: (String url) {
            debugPrint('🔑 [FlutterwaveWebView] Page finished: $url');
            setState(() {
              _isLoading = false;
            });
            _handleNavigation(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ [FlutterwaveWebView] Error: ${error.description}');
            // Still try to parse the failing URL — redirect hosts may 500
            // after Flutterwave appends success query params.
            final failingUrl = error.url;
            if (failingUrl != null && failingUrl.isNotEmpty) {
              _handleNavigation(failingUrl);
            }
            setState(() {
              _error = error.description;
              _isLoading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _handleNavigation(String url) {
    debugPrint('🔑 [FlutterwaveWebView] Navigating to: $url');

    final isRedirect = url.contains(widget.redirectUrl) ||
        url.contains('payment-redirect') ||
        url.contains('mlq://payment-callback') ||
        url.contains('status=successful') ||
        url.contains('status=success') ||
        url.contains('status=failed') ||
        url.contains('status=cancelled') ||
        (url.contains('tx_ref=') &&
            (url.contains('transaction_id=') || url.contains('id=')));

    if (isRedirect) {
      debugPrint('✅ [FlutterwaveWebView] Payment callback detected');

      final uri = Uri.tryParse(url);
      if (uri == null) return;
      final status = uri.queryParameters['status'];
      final txRef = uri.queryParameters['tx_ref'];
      final transactionId = uri.queryParameters['transaction_id'] ??
          uri.queryParameters['id'];

      if (_successDetected) {
        return;
      }

      if (status == 'successful' || status == 'success') {
        _successDetected = true;
        _lastTxRef = txRef ?? _lastTxRef;
        _lastTransactionId = transactionId ?? _lastTransactionId;
        widget.onSuccess({
          'status': status,
          'tx_ref': _lastTxRef ?? txRef ?? '',
          'transaction_id': _lastTransactionId ?? transactionId ?? '',
        });
        return;
      } else if ((txRef ?? '').isNotEmpty) {
        // Backend can verify by tx_ref even if transaction_id is missing.
        _successDetected = true;
        _lastTxRef = txRef;
        _lastTransactionId = transactionId ?? '';
        widget.onSuccess({
          'status': 'success',
          'tx_ref': _lastTxRef!,
          'transaction_id': _lastTransactionId!,
        });
        return;
      } else if (status == 'cancelled' || status == 'canceled') {
        widget.onCancel();
        return;
      } else if (status == 'failed' || status == 'error') {
        widget.onError('Payment failed with status: $status');
        return;
      }
    }

    if (url.contains('cancelled') ||
        url.contains('canceled') ||
        url.contains('close')) {
      widget.onCancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: const Color(0xFFF5A623),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (_successDetected && (_lastTxRef ?? '').isNotEmpty) {
              widget.onSuccess({
                'status': 'success',
                'tx_ref': _lastTxRef!,
                'transaction_id': _lastTransactionId ?? '',
              });
            } else {
              widget.onCancel();
            }
          },
        ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Error',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _initializeWebView();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFF5A623)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading payment page...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
