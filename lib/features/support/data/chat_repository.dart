import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../public_site/domain/entities/help_content.dart';
import '../../../core/network/api_client.dart';
import '../domain/chat_message.dart';

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

class ChatRepository {
  ChatRepository(this.api);
  final ApiClient api;
  static const storageKey = 'reaccess.chat.v1';

  Future<ChatState> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(storageKey);
      if (raw == null) return const ChatState(loading: false);
      if (raw.length > 250000) throw const FormatException();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final saved = DateTime.parse(json['savedAt'] as String);
      if (DateTime.now().difference(saved) > const Duration(days: 30)) {
        await preferences.remove(storageKey);
        return const ChatState(loading: false);
      }
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final messages = (json['messages'] as List)
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((m) => m.createdAt.isAfter(cutoff) && m.text.length <= 4000)
          .toList();
      return ChatState(
        loading: false,
        messages: messages.length > 80
            ? messages.sublist(messages.length - 80)
            : messages,
        offerHandoff: json['offerHandoff'] == true,
        aiConsent: json['aiConsent'] == true,
        ticketId: json['ticketId'] as String?,
        ticketToken: json['ticketToken'] as String?,
        lastReply: json['lastReply'] as String?,
      );
    } catch (_) {
      return const ChatState(
        loading: false,
        storageWarning: 'Saved chat could not be restored. Browser storage may be unavailable.',
      );
    }
  }

  Future<void> save(ChatState state) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      storageKey,
      jsonEncode({
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'messages': state.messages.map((m) => m.toJson()).toList(),
        'offerHandoff': state.offerHandoff,
        'aiConsent': state.aiConsent,
        'ticketId': state.ticketId,
        'ticketToken': state.ticketToken,
        'lastReply': state.lastReply,
      }),
    );
    if (!saved) throw StateError('Storage unavailable');
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(storageKey);
  }

  HelpQuestion? faqFor(String text) {
    final normalized = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final faq in helpQuestions) {
      if (faq.question.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') ==
          normalized) {
        return faq;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> ask(String text) async =>
      (await api.post<Map<String, dynamic>>(
        '/public/chat/message',
        data: {'message': text},
      )).data!;
  Future<Map<String, dynamic>> escalate(
    ChatState state,
    String personId,
  ) async => (await api.post<Map<String, dynamic>>(
    '/public/chat/handoff',
    data: {
      'consent': true,
      'personId': personId.trim().toUpperCase(),
      'messages': state.messages
          .skip(state.messages.length > 20 ? state.messages.length - 20 : 0)
          .map((m) => {'role': m.role.name, 'text': m.text})
          .toList(),
    },
  )).data!;
  Future<Map<String, dynamic>> status(ChatState state) async =>
      (await api.post<Map<String, dynamic>>(
        '/public/chat/status',
        data: {'ticketId': state.ticketId, 'token': state.ticketToken},
      )).data!;
}
