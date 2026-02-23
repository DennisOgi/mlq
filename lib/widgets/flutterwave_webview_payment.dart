import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
    debugPrint('🔑 Payment URL: ${widget.paymentUrl.substring(0, 80)}...');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('🔑 [FlutterwaveWebView] Loading: $progress%');
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
            // Ensure we also evaluate redirects on finish (some devices miss start)
            _handleNavigation(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ [FlutterwaveWebView] Error: ${error.description}');
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

    // Enhanced redirect detection - catch multiple patterns
    final isRedirect = url.contains(widget.redirectUrl) || 
                       url.contains('mlq://payment-callback') ||
                       url.contains('status=successful') ||
                       url.contains('status=success') ||
                       url.contains('status=failed') ||
                       url.contains('status=cancelled') ||
                       (url.contains('tx_ref=') && url.contains('transaction_id='));

    if (isRedirect) {
      debugPrint('✅ [FlutterwaveWebView] Payment callback detected');
      
      // Parse URL parameters
      final uri = Uri.parse(url);
      final status = uri.queryParameters['status'];
      final txRef = uri.queryParameters['tx_ref'];
      final transactionId = uri.queryParameters['transaction_id'];

      debugPrint('🔑 Status: $status');
      debugPrint('🔑 TxRef: $txRef');
      debugPrint('🔑 Transaction ID: $transactionId');
      debugPrint('🔑 Full URL: $url');

      if (_successDetected) {
        return; // already handled
      }

      if (status == 'successful' || status == 'success') {
        debugPrint('✅ [FlutterwaveWebView] Payment successful - returning to app');
        _successDetected = true;
        _lastTxRef = txRef ?? _lastTxRef;
        _lastTransactionId = transactionId ?? _lastTransactionId;
        widget.onSuccess({
          'status': status,
          'tx_ref': _lastTxRef ?? txRef ?? '',
          'transaction_id': _lastTransactionId ?? transactionId ?? '',
        });
        return; // Exit early to prevent further navigation
      } else if ((txRef ?? '').isNotEmpty && (transactionId ?? '').isNotEmpty) {
        // Fallback success if both refs are present but status missing
        debugPrint('✅ [FlutterwaveWebView] Payment success inferred from params');
        _successDetected = true;
        _lastTxRef = txRef;
        _lastTransactionId = transactionId;
        widget.onSuccess({
          'status': 'success',
          'tx_ref': _lastTxRef!,
          'transaction_id': _lastTransactionId!,
        });
        return;
      } else if (status == 'cancelled' || status == 'canceled') {
        debugPrint('⚠️ [FlutterwaveWebView] Payment cancelled by user');
        widget.onCancel();
        return;
      } else if (status == 'failed' || status == 'error') {
        debugPrint('❌ [FlutterwaveWebView] Payment failed');
        widget.onError('Payment failed with status: $status');
        return;
      }
    }

    // Check for cancel/close in URL path
    if (url.contains('cancelled') || url.contains('canceled') || url.contains('close')) {
      debugPrint('⚠️ [FlutterwaveWebView] Payment cancelled via URL');
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
            // If success already detected, prefer success over cancel on close
            if (_successDetected && (_lastTxRef ?? '').isNotEmpty && (_lastTransactionId ?? '').isNotEmpty) {
              widget.onSuccess({
                'status': 'success',
                'tx_ref': _lastTxRef!,
                'transaction_id': _lastTransactionId!,
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
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Payment Error',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5A623)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading payment page...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
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
