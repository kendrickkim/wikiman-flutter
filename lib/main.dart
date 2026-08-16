import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_intent_package/share_intent_package.dart';

import 'connection_screen.dart';
import 'connection_settings.dart';
import 'credential_store.dart';
import 'share_upload_service.dart';
import 'wikiman_auth_service.dart';
import 'wikiman_webview_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WikimanApp());
}

class WikimanApp extends StatefulWidget {
  const WikimanApp({super.key});

  @override
  State<WikimanApp> createState() => _WikimanAppState();
}

class _WikimanAppState extends State<WikimanApp> {
  final CredentialStore _credentialStore = CredentialStore();
  final WikimanAuthService _authService = WikimanAuthService();
  final ShareUploadService _shareUploadService = ShareUploadService();
  final ValueNotifier<String?> _sharedDraft = ValueNotifier(null);
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  ConnectionSettings? _settings;
  WikimanSession? _session;
  StreamSubscription<SharedData>? _shareSubscription;
  SharedData? _pendingShare;
  bool _processingShare = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initSharing();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _sharedDraft.dispose();
    super.dispose();
  }

  Future<void> _initSharing() async {
    await ShareIntentPackage.instance.init();
    _shareSubscription = ShareIntentPackage.instance.getMediaStream().listen(
      _receiveShare,
    );
    final initial = await ShareIntentPackage.instance.getInitialSharing();
    if (initial != null) _receiveShare(initial);
  }

  Future<void> _loadSettings() async {
    final settings = await _credentialStore.read();
    if (!mounted) return;
    setState(() => _settings = settings);
  }

  Future<void> _connect(ConnectionSettings settings) async {
    final session = await _authService.login(settings);
    await _credentialStore.write(session.settings);
    if (!mounted) return;
    setState(() {
      _settings = session.settings;
      _session = session;
    });
    _processPendingShare();
  }

  void _changeConnection() {
    setState(() => _session = null);
  }

  void _receiveShare(SharedData data) {
    if (!data.hasContent) return;
    _pendingShare = data;
    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessage('공유 내용을 받았습니다. 관리자 계정으로 접속해 주세요.');
      });
      return;
    }
    _processPendingShare();
  }

  Future<void> _processPendingShare() async {
    final session = _session;
    final pendingShare = _pendingShare;
    if (_processingShare || session == null || pendingShare == null) return;
    _processingShare = true;
    var failed = false;
    _pendingShare = null;
    try {
      final draft = await _shareUploadService.createDraft(
        session,
        pendingShare,
      );
      if (draft.isEmpty) {
        _showMessage('공유된 내용이 없습니다.');
      } else {
        _sharedDraft.value = draft;
        _showMessage('공유 내용을 간단 포스트에 입력했습니다.');
      }
    } catch (error) {
      failed = true;
      _pendingShare = pendingShare;
      _showMessage(error.toString());
    } finally {
      _processingShare = false;
      if (!failed && _pendingShare != null && _session != null) {
        _processPendingShare();
      }
    }
  }

  void _showMessage(String message) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wikiman',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff60a5fa),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final settings = _settings;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session;
    if (session != null) {
      return WikimanWebViewScreen(
        session: session,
        sharedDraft: _sharedDraft,
        onChangeConnection: _changeConnection,
      );
    }
    return ConnectionScreen(initialSettings: settings, onConnect: _connect);
  }
}
