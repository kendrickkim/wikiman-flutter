import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'wikiman_auth_service.dart';
import 'wikiman_upload_service.dart';

class WikimanNativeMedia {
  WikimanNativeMedia({
    required this.session,
    required Future<void> Function(Map<String, dynamic> payload) emit,
    WikimanUploadService? uploads,
    SpeechToText? speech,
    AudioRecorder? recorder,
  }) : _emit = emit,
       _uploads = uploads ?? WikimanUploadService(),
       _speech = speech ?? SpeechToText(),
       _recorder = recorder ?? AudioRecorder();

  final WikimanSession session;
  final WikimanUploadService _uploads;
  final SpeechToText _speech;
  final AudioRecorder _recorder;

  Future<void> Function(Map<String, dynamic> payload) _emit;
  bool _speechDesired = false;
  bool _speechReady = false;
  bool _recording = false;
  bool _recordBusy = false;

  void updateEmit(Future<void> Function(Map<String, dynamic> payload) emit) {
    _emit = emit;
  }

  Future<void> startSpeech() async {
    if (_speechDesired) return;
    final allowed = await Permission.microphone.request();
    if (!allowed.isGranted) {
      await _emit({'type': 'speech:error', 'code': 'not-allowed'});
      return;
    }

    _speechReady = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: (error) {
        _speechDesired = false;
        _emit({
          'type': 'speech:error',
          'code': error.permanent ? 'not-allowed' : 'unknown',
        });
      },
    );
    if (!_speechReady) {
      await _emit({'type': 'speech:error', 'code': 'audio-capture'});
      return;
    }

    _speechDesired = true;
    await _emit({'type': 'speech:started'});
    await _listenSpeech();
  }

  Future<void> stopSpeech() async {
    _speechDesired = false;
    if (_speech.isListening) {
      await _speech.stop();
    }
    await _emit({'type': 'speech:stopped'});
  }

  Future<void> startRecording() async {
    if (_recording || _recordBusy) return;
    _recordBusy = true;
    try {
      final allowed = await Permission.microphone.request();
      if (!allowed.isGranted || !await _recorder.hasPermission()) {
        await _emit({'type': 'record:error', 'code': 'permission'});
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/wikiman-recording-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recording = true;
      await _emit({'type': 'record:started'});
    } catch (_) {
      _recording = false;
      await _emit({'type': 'record:error', 'code': 'unavailable'});
    } finally {
      _recordBusy = false;
    }
  }

  Future<void> stopRecording({bool upload = true}) async {
    if (!_recording) {
      await _emit({'type': 'record:stopped'});
      return;
    }
    _recordBusy = true;
    _recording = false;
    try {
      final path = await _recorder.stop();
      if (!upload || path == null || path.isEmpty) {
        await _emit({'type': 'record:stopped'});
        return;
      }
      await _emit({'type': 'record:uploading'});
      final file = await _uploads.uploadFile(
        session,
        path,
        filename: 'recording.m4a',
        contentType: MediaType('audio', 'mp4'),
      );
      await _emit({'type': 'record:uploaded', 'file': file});
      await _emit({'type': 'record:stopped'});
    } on WikimanUploadException {
      await _emit({'type': 'record:error', 'code': 'failed'});
    } catch (_) {
      await _emit({'type': 'record:error', 'code': 'failed'});
    } finally {
      _recordBusy = false;
    }
  }

  Future<void> dispose() async {
    _speechDesired = false;
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
    try {
      if (_recording) await _recorder.stop();
    } catch (_) {}
    _recording = false;
    await _recorder.dispose();
  }

  Future<void> _listenSpeech() async {
    if (!_speechDesired || !_speechReady) return;
    await _speech.listen(
      onResult: (result) {
        if (!result.finalResult) return;
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        _emit({'type': 'speech:transcript', 'text': text});
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 8),
        localeId: 'ko_KR',
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _onSpeechStatus(String status) {
    if (!_speechDesired) return;
    if (status == 'done' || status == 'notListening') {
      _listenSpeech();
    }
  }
}
