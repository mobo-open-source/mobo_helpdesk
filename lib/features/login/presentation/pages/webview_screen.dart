import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

/// A full-featured WebView screen for displaying web content within the app.
///
/// This screen uses [WebViewController] to load and manage web pages,
/// providing a native wrapper around web content with enhanced UX features.
///
/// Key features:
/// - Loads and displays a given URL inside a WebView
/// - Supports navigation (back/forward)
/// - Displays loading progress indicator
/// - Pull-to-refresh functionality
/// - Error handling with retry and fallback UI
/// - Custom AppBar with navigation controls
///
/// The screen also manages:
/// - WebView lifecycle events (start, finish, error)
/// - Navigation history handling
/// - Responsive error UI when page loading fails
///
/// This is typically used for:
/// - External web content rendering
/// - Authentication flows
/// - Reset password or external service pages
class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool isLoading = true;
  String? _errorMessage;
  int _loadingProgress = 0;
  Completer<void>? _refreshCompleter;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            _refreshCompleter?.complete();
            _refreshCompleter = null;
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
              _errorMessage = 'Failed to load page: ${error.description}';
            });
            _refreshCompleter?.completeError(error);
            _refreshCompleter = null;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _refresh() {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    _controller.reload();
  }

  /// Navigates back in WebView history.
  /// If no history, closes the screen.
  void _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    } else {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  void _goForward() async {
    if (await _controller.canGoForward()) {
      _controller.goForward();
    }
  }

  Future<bool> _handleWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        await _handleWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          leading: IconButton(
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else {
                if (mounted) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              }
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 20,
              color: Colors.black87,
            ),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _goBack,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft02,
                color: isDark ? Colors.white : Colors.black,
              ),
              tooltip: 'Back',
            ),
            IconButton(
              onPressed: _goForward,
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight02,
                size: 20,
                color: isDark ? Colors.white : Colors.black,
              ),
              tooltip: 'Forward',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_errorMessage == null && _loadingProgress < 100)
              LinearProgressIndicator(
                value: _loadingProgress == 0 ? null : _loadingProgress / 100.0,
                minHeight: 3,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshCompleter = Completer<void>();
                  _refresh();
                  try {
                    await _refreshCompleter!.future.timeout(
                      const Duration(seconds: 12),
                    );
                  } catch (_) {
                  } finally {
                    _refreshCompleter = null;
                  }
                },
                color: Theme.of(context).primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: _errorMessage != null
                        ? _buildErrorWidget()
                        : WebViewWidget(controller: _controller),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAlertCircle,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Page',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred while loading the page.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    size: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  label: Text(
                    'Go Back',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    size: 16,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  label: Text(
                    'Try Again',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
