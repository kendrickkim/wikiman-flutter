import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'wikiman_auth_service.dart';
import 'wikiman_native_command.dart';
import 'wikiman_native_media.dart';

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

const _backgroundMessagePrefix = 'background:';

class _WikimanWebViewScreenState extends State<WikimanWebViewScreen> {
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  late final WikimanNativeMedia _media;
  late WebViewController _controller;
  Key _webViewKey = UniqueKey();
  int _progress = 0;
  bool _pageReady = false;
  Color? _pageBackground;
  Color? _headerBackground;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _media = WikimanNativeMedia(session: widget.session, emit: _emitNative);
    _controller = _createController();
    widget.sharedDraft.addListener(_deliverSharedDraft);
    _openWikiman();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pageReady) {
      _syncSafeAreaInsets();
    }
  }

  @override
  void dispose() {
    widget.sharedDraft.removeListener(_deliverSharedDraft);
    _media.dispose();
    super.dispose();
  }

  WebViewController _createController() {
    final controller = WebViewController(
      onPermissionRequest: (request) async {
        final needsMic = request.types.contains(
          WebViewPermissionResourceType.microphone,
        );
        final needsCamera = request.types.contains(
          WebViewPermissionResourceType.camera,
        );
        if (needsMic && !await Permission.microphone.request().isGranted) {
          request.deny();
          return;
        }
        if (needsCamera && !await Permission.camera.request().isGranted) {
          request.deny();
          return;
        }
        request.grant();
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_appUserAgent)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'WikimanApp',
        onMessageReceived: (message) {
          _handleNativeMessage(message.message);
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
            await _injectNativeBridge();
            await _syncSafeAreaInsets();
            await _watchPageBackground();
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
    _bindAndroidFileSelector(controller);
    return controller;
  }

  void _bindAndroidFileSelector(WebViewController controller) {
    if (controller.platform is! AndroidWebViewController) return;
    final android = controller.platform as AndroidWebViewController;
    android.setOnShowFileSelector((params) async {
      final allowMultiple = params.mode == FileSelectorMode.openMultiple;
      var type = FileType.any;
      final accepts = params.acceptTypes
          .map((item) => item.toLowerCase())
          .where((item) => item.isNotEmpty)
          .toList();
      if (accepts.isNotEmpty && accepts.every((item) => item.startsWith('image/'))) {
        type = FileType.image;
      } else if (accepts.isNotEmpty &&
          accepts.every((item) => item.startsWith('audio/'))) {
        type = FileType.audio;
      }
      final files = allowMultiple
          ? await FilePicker.pickFiles(type: type)
          : [
              ?await FilePicker.pickFile(type: type),
            ];
      return [
        for (final file in files)
          if (file.path != null && file.path!.isNotEmpty)
            Uri.file(file.path!).toString()
          else if (file.uri.toString().isNotEmpty)
            file.uri.toString(),
      ];
    });
  }

  void _handleNativeMessage(String message) {
    switch (parseWikimanNativeMessage(message)) {
      case WikimanNativeCommand.changeConnection:
        widget.onChangeConnection();
      case WikimanNativeCommand.goHome:
        _goHome();
      case WikimanNativeCommand.speechStart:
        _media.startSpeech();
      case WikimanNativeCommand.speechStop:
        _media.stopSpeech();
      case WikimanNativeCommand.recordStart:
        _media.startRecording();
      case WikimanNativeCommand.recordStop:
        _media.stopRecording();
      case WikimanNativeCommand.background:
        _applyPageBackground(message.substring(_backgroundMessagePrefix.length));
      case WikimanNativeCommand.logout:
      case WikimanNativeCommand.unknown:
        break;
    }
  }

  Future<void> _goHome() async {
    await _media.stopSpeech();
    await _media.stopRecording(upload: false);
    if (!mounted) return;
    setState(() {
      _pageReady = false;
      _progress = 0;
      _webViewKey = UniqueKey();
      _controller = _createController();
    });
    _media.updateEmit(_emitNative);
    await _openWikiman();
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
      final value = result.toString();
      return value == '1' || value == '"1"';
    } catch (_) {
      return false;
    }
  }

  Future<void> _injectNativeBridge() async {
    await _controller.runJavaScript(r'''
      window.__wikimanNativeEmit = function (payload) {
        try {
          var detail = payload;
          if (typeof payload === 'string') detail = JSON.parse(payload);
          window.dispatchEvent(new CustomEvent('wikiman-native', { detail: detail }));
        } catch (e) {}
      };
    ''');
  }

  Future<void> _emitNative(Map<String, dynamic> payload) async {
    if (!_pageReady) return;
    final encoded = jsonEncode(payload);
    await _controller.runJavaScript(
      'window.__wikimanNativeEmit && window.__wikimanNativeEmit($encoded);',
    );
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

  Future<void> _syncSafeAreaInsets() async {
    if (!mounted) return;
    final padding = MediaQuery.paddingOf(context);
    await _controller.runJavaScript('''
      (function () {
        var root = document.documentElement;
        root.style.setProperty('--wikiman-safe-top', '${padding.top}px');
        root.style.setProperty('--wikiman-safe-bottom', '${padding.bottom}px');
        root.style.setProperty('--wikiman-safe-left', '${padding.left}px');
        root.style.setProperty('--wikiman-safe-right', '${padding.right}px');
      })();
    ''');
  }

  Future<void> _watchPageBackground() async {
    await _controller.runJavaScript(r'''
      (function () {
        if (window.__wikimanReportBackground) {
          window.__wikimanReportBackground();
          return;
        }
        var canvas = document.createElement('canvas').getContext('2d');
        function normalize(color) {
          if (!canvas) return color;
          canvas.fillStyle = '#000000';
          canvas.fillStyle = color;
          return canvas.fillStyle;
        }
        function opaque(color) {
          if (!color || color === 'transparent') return false;
          var parts = color.match(/[\d.]+/g);
          return !(parts && parts.length > 3 && parseFloat(parts[3]) === 0);
        }
        function read(selectors) {
          for (var i = 0; i < selectors.length; i++) {
            var element = document.querySelector(selectors[i]);
            if (!element) continue;
            var color = getComputedStyle(element).backgroundColor;
            if (opaque(color)) return normalize(color);
          }
          return '';
        }
        function report() {
          var payload = JSON.stringify({
            page: read(['body', 'html']),
            header: read(['.wiki-header', '.q-header']),
          });
          if (payload !== window.__wikimanBackground) {
            window.__wikimanBackground = payload;
            WikimanApp.postMessage('background:' + payload);
          }
        }
        var pending = null;
        function schedule() {
          if (pending) clearTimeout(pending);
          pending = setTimeout(function () {
            pending = null;
            report();
          }, 200);
        }
        window.__wikimanReportBackground = report;
        new MutationObserver(schedule).observe(document.documentElement, {
          attributes: true,
          attributeFilter: ['class', 'style', 'data-theme'],
          childList: true,
          subtree: true,
        });
        report();
      })();
    ''');
  }

  void _applyPageBackground(String payload) {
    final Map<String, dynamic> colors;
    try {
      colors = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final page = _parseCssColor('${colors['page']}') ?? _pageBackground;
    final header = _parseCssColor('${colors['header']}') ?? _headerBackground;
    if (!mounted ||
        (page == _pageBackground && header == _headerBackground)) {
      return;
    }
    setState(() {
      _pageBackground = page;
      _headerBackground = header;
    });
  }

  Color? _parseCssColor(String value) {
    final text = value.trim();
    if (text.startsWith('#')) {
      var digits = text.substring(1);
      if (digits.length == 3 || digits.length == 4) {
        digits = digits.split('').map((digit) => '$digit$digit').join();
      }
      if (digits.length == 8) {
        digits = '${digits.substring(6)}${digits.substring(0, 6)}';
      } else if (digits.length == 6) {
        digits = 'ff$digits';
      } else {
        return null;
      }
      final argb = int.tryParse(digits, radix: 16);
      return argb == null ? null : Color(argb);
    }
    final numbers = RegExp(
      r'[\d.]+',
    ).allMatches(text).map((match) => match.group(0)!).toList();
    if (numbers.length < 3) return null;
    final red = int.tryParse(numbers[0]);
    final green = int.tryParse(numbers[1]);
    final blue = int.tryParse(numbers[2]);
    if (red == null || green == null || blue == null) return null;
    final alpha = numbers.length > 3
        ? (double.tryParse(numbers[3]) ?? 1) * 255
        : 255.0;
    return Color.fromARGB(alpha.round().clamp(0, 255), red, green, blue);
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
    final background =
        _pageBackground ?? Theme.of(context).colorScheme.surface;
    final header = _headerBackground ?? background;
    final darkHeader = header.computeLuminance() < 0.5;
    final darkBackground = background.computeLuminance() < 0.5;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarBrightness: darkHeader ? Brightness.dark : Brightness.light,
          statusBarIconBrightness: darkHeader
              ? Brightness.light
              : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
          systemNavigationBarIconBrightness: darkBackground
              ? Brightness.light
              : Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: background,
          body: Stack(
            children: [
              Positioned.fill(
                child: WebViewWidget(key: _webViewKey, controller: _controller),
              ),
              if (_progress < 100)
                Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(value: _progress / 100),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
