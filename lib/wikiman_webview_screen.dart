import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'wikiman_auth_service.dart';

class WikimanWebViewScreen extends StatefulWidget {
  const WikimanWebViewScreen({
    required this.session,
    required this.sharedDraft,
    required this.onChangeConnection,
    super.key,
  });

  final WikimanSession session;
  final ValueNotifier<String?> sharedDraft;
  final VoidCallback onChangeConnection;

  @override
  State<WikimanWebViewScreen> createState() => _WikimanWebViewScreenState();
}

class _WikimanWebViewScreenState extends State<WikimanWebViewScreen> {
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WebViewController _controller;
  int _progress = 0;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_appUserAgent)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'WikimanApp',
        onMessageReceived: (message) {
          if (message.message == 'logout' ||
              message.message == 'changeConnection') {
            widget.onChangeConnection();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _pageReady = false;
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (_) async {
            _pageReady = true;
            if (mounted) setState(() => _progress = 100);
            final sessionReady = await _isNativeSessionReady();
            await _injectSession();
            if (sessionReady) await _deliverSharedDraft();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true || !mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('페이지를 불러오지 못했습니다: ${error.description}')),
            );
          },
        ),
      );
    widget.sharedDraft.addListener(_deliverSharedDraft);
    _openWikiman();
  }

  @override
  void dispose() {
    widget.sharedDraft.removeListener(_deliverSharedDraft);
    super.dispose();
  }

  String get _appUserAgent {
    if (Platform.isIOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
          'Mobile/15E148 Safari/604.1 WikimanApp/1.0';
    }
    return 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 '
        'WikimanApp/1.0';
  }

  Future<void> _openWikiman() async {
    final uri = Uri.parse(widget.session.settings.url);
    await _cookieManager.clearCookies();
    await _cookieManager.setCookie(
      WebViewCookie(
        name: 'wikiman_token',
        value: Uri.encodeComponent(widget.session.token),
        domain: uri.host,
        path: '/',
      ),
    );
    await _controller.loadRequest(uri);
  }

  Future<bool> _isNativeSessionReady() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        "sessionStorage.getItem('wikiman_native_session_ready')",
      );
      final value = result?.toString() ?? '';
      return value == '1' || value == '"1"';
    } catch (_) {
      return false;
    }
  }

  Future<void> _injectSession() async {
    final token = jsonEncode(widget.session.token);
    final cookieValue = Uri.encodeComponent(widget.session.token);
    await _controller.runJavaScript('''
      (function () {
        var token = $token;
        var existing = localStorage.getItem('wikiman_token');
        localStorage.setItem('wikiman_token', token);
        document.cookie = 'wikiman_token=$cookieValue; Path=/; Max-Age=604800; SameSite=Lax';
        if (existing !== token) {
          sessionStorage.setItem('wikiman_native_session_ready', '1');
          location.reload();
        } else {
          sessionStorage.setItem('wikiman_native_session_ready', '1');
        }
      })();
    ''');
  }

  Future<void> _deliverSharedDraft() async {
    final draft = widget.sharedDraft.value;
    if (!_pageReady || draft == null || draft.trim().isEmpty) return;
    widget.sharedDraft.value = null;
    final encoded = jsonEncode(draft);
    await _controller.runJavaScript('''
      localStorage.setItem('wikiman_shared_draft', $encoded);
      window.location.href = new URL('/quick-posts/new', window.location.origin).href;
    ''');
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_progress < 100)
                LinearProgressIndicator(value: _progress / 100),
            ],
          ),
        ),
      ),
    );
  }
}
