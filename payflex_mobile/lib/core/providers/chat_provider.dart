import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/mobile_api_service.dart';
import 'auth_provider.dart';

class Message {
  final int? id;
  final String text;
  final String senderRole;
  final DateTime timestamp;
  final String? attachmentUrl;
  final String? attachmentKind;
  final String? attachmentName;
  final String? localFilePath;

  Message({
    this.id,
    required this.text,
    required this.senderRole,
    required this.timestamp,
    this.attachmentUrl,
    this.attachmentKind,
    this.attachmentName,
    this.localFilePath,
  });

  bool get hasAttachment =>
      (attachmentUrl != null && attachmentUrl!.isNotEmpty) ||
      (localFilePath != null && localFilePath!.isNotEmpty);

  factory Message.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    int? idVal;
    if (rawId is num) idVal = rawId.toInt();
    final ts = DateTime.tryParse('${map['timestamp'] ?? ''}');
    final attachmentUrl = map['attachment_url']?.toString();
    return Message(
      id: idVal,
      text: '${map['text'] ?? ''}',
      senderRole: '${map['sender_role'] ?? 'user'}',
      timestamp: ts ?? DateTime.now(),
      attachmentUrl: attachmentUrl != null && attachmentUrl.isNotEmpty ? attachmentUrl : null,
      attachmentKind: map['attachment_kind']?.toString(),
      attachmentName: map['attachment_name']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          senderRole == other.senderRole &&
          timestamp == other.timestamp &&
          attachmentUrl == other.attachmentUrl &&
          attachmentKind == other.attachmentKind &&
          attachmentName == other.attachmentName &&
          localFilePath == other.localFilePath;

  @override
  int get hashCode => Object.hash(
        id,
        text,
        senderRole,
        timestamp,
        attachmentUrl,
        attachmentKind,
        attachmentName,
        localFilePath,
      );
}

bool _sameMessageList(List<Message> a, List<Message> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class ChatNotifier extends Notifier<List<Message>> {
  final MobileApiService _api = MobileApiService();
  Timer? _pollTimer;
  bool _loading = false;

  @override
  List<Message> build() {
    ref.onDispose(stopPolling);
    return [];
  }

  /// Rafraîchissement périodique tant que l’écran chat est ouvert (~3 s).
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => loadMessages(silent: true));
    loadMessages();
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> loadMessages({bool silent = false}) async {
    if (_loading) return;
    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (!auth.isAuthenticated || uid == null || phone == null || pin == null || pin.isEmpty) {
      state = [];
      return;
    }
    _loading = true;
    try {
      final maps = await _api.fetchSupportChatHistory(userId: uid, phone: phone, pin: pin);
      final next = maps.map(Message.fromMap).toList();
      if (!_sameMessageList(state, next)) {
        state = next;
      }
    } finally {
      _loading = false;
    }
  }

  Future<bool> sendAttachment(File file, {String? caption}) async {
    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (!auth.isAuthenticated || uid == null || phone == null || pin == null || pin.isEmpty) {
      return false;
    }

    final optimistic = Message(
      text: caption?.trim().isNotEmpty == true ? caption!.trim() : 'Envoi du fichier…',
      senderRole: 'user',
      timestamp: DateTime.now(),
      localFilePath: file.path,
      attachmentKind: _guessAttachmentKind(file.path),
      attachmentName: file.path.split(Platform.pathSeparator).last,
    );
    state = [...state, optimistic];

    final ok = await _api.sendSupportChatAttachment(
      userId: uid,
      phone: phone,
      pin: pin,
      file: file,
      caption: caption,
    );
    if (ok) {
      await loadMessages();
      return true;
    }
    state = state.where((m) => m != optimistic).toList();
    return false;
  }

  static String? _guessAttachmentKind(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.heic')) {
      return 'image';
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.amr') ||
        lower.endsWith('.3gp')) {
      return 'audio';
    }
    return 'document';
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (!auth.isAuthenticated || uid == null || phone == null || pin == null || pin.isEmpty) {
      return;
    }

    final optimistic = Message(
      text: trimmed,
      senderRole: 'user',
      timestamp: DateTime.now(),
    );
    state = [...state, optimistic];

    final ok = await _api.sendSupportChatMessage(userId: uid, phone: phone, pin: pin, body: trimmed);
    if (ok) {
      await loadMessages();
    } else {
      state = state.where((m) => m != optimistic).toList();
    }
  }

  Future<bool> deleteMessage(int messageId) async {
    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (!auth.isAuthenticated || uid == null || phone == null || pin == null || pin.isEmpty) {
      return false;
    }
    final ok = await _api.deleteSupportChatMessage(
      userId: uid,
      phone: phone,
      pin: pin,
      messageId: messageId,
    );
    if (ok) {
      state = state.where((m) => m.id != messageId).toList();
    }
    return ok;
  }

  Future<bool> deleteThread() async {
    final auth = ref.read(authProvider);
    final uid = auth.userId;
    final phone = auth.phone;
    final pin = auth.pin;
    if (!auth.isAuthenticated || uid == null || phone == null || pin == null || pin.isEmpty) {
      return false;
    }
    final ok = await _api.deleteSupportChatThread(userId: uid, phone: phone, pin: pin);
    if (ok) {
      state = [];
    }
    return ok;
  }
}

final chatProvider = NotifierProvider<ChatNotifier, List<Message>>(ChatNotifier.new);
