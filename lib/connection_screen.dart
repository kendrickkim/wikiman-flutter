import 'package:flutter/material.dart';

import 'connection_settings.dart';
import 'wikiman_auth_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    required this.initialSettings,
    required this.onConnect,
    this.initialError = '',
    super.key,
  });

  final ConnectionSettings initialSettings;
  final Future<void> Function(ConnectionSettings settings) onConnect;
  final String initialError;

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();
  bool _connecting = false;
  bool _showPassword = false;
  late bool _autoLogin;
  late String _error;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialSettings.url);
    _usernameController = TextEditingController(
      text: widget.initialSettings.username,
    );
    _passwordController = TextEditingController(
      text: widget.initialSettings.password,
    );
    _autoLogin = widget.initialSettings.autoLogin;
    _error = widget.initialError;
  }

  @override
  void didUpdateWidget(covariant ConnectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSettings.autoLogin !=
            widget.initialSettings.autoLogin &&
        !_connecting) {
      _autoLogin = widget.initialSettings.autoLogin;
    }
    if (widget.initialError.isNotEmpty &&
        widget.initialError != oldWidget.initialError) {
      _error = widget.initialError;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _connecting = true;
      _error = '';
    });
    try {
      await widget.onConnect(
        ConnectionSettings(
          url: _urlController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          autoLogin: _autoLogin,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        if (error is WikimanAuthException && error.invalidCredentials) {
          _autoLogin = false;
        } else {
          _autoLogin = widget.initialSettings.autoLogin;
        }
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wikiman 접속')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 64,
                        height: 64,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '접속 정보',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '관리자 계정으로 로그인할 Wikiman을 선택해 주세요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _urlController,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Wikiman URL',
                        hintText: 'https://wiki.example.com',
                        prefixIcon: Icon(Icons.language),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Wikiman URL을 입력해 주세요.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '아이디',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? '아이디를 입력해 주세요.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _connect(),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 표시',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? '비밀번호를 입력해 주세요.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _autoLogin,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('자동 로그인'),
                      subtitle: const Text(
                        '앱을 다시 열면 저장된 정보로 바로 접속합니다.',
                      ),
                      onChanged: _connecting
                          ? null
                          : (value) =>
                                setState(() => _autoLogin = value ?? false),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _connecting ? null : _connect,
                      icon: _connecting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_connecting ? '접속 중…' : '접속'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '접속 정보는 기기의 보안 저장소에 보관됩니다.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
