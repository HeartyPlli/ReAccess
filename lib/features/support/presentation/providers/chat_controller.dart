import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);

class ChatController extends Notifier<ChatState> {
  bool _disposed = false;
  @override
  ChatState build() {
    ref.onDispose(() => _disposed = true);
    _restore();
    return const ChatState();
  }

  Future<void> _restore() async {
    final restored = await ref.read(chatRepositoryProvider).restore();
    if (!_disposed) state = restored;
  }

  Future<void> _save() async {
    try {
      await ref.read(chatRepositoryProvider).save(state);
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          storageWarning: 'This browser could not save your chat. It will only last for this visit.',
        );
      }
    }
  }

  void _append(ChatMessage message) {
    final messages = [...state.messages, message];
    state = state.copyWith(
      messages: messages.length > 80
          ? messages.sublist(messages.length - 80)
          : messages,
    );
  }

  Future<void> consentToAi() async {
    state = state.copyWith(aiConsent: true);
    await _save();
  }

  Future<void> send(String value) async {
    final text = value.trim();
    if (state.loading ||
        state.busy ||
        text.isEmpty ||
        text.length > 1000 ||
        state.ticketId != null) {
      return;
    }
    final repo = ref.read(chatRepositoryProvider);
    final faq = repo.faqFor(text);
    if (faq == null && !state.aiConsent) return;
    state = state.copyWith(busy: true, offerHandoff: false);
    _append(ChatMessage(role: ChatRole.user, text: text));
    await _save();
    try {
      if (faq != null) {
        _append(ChatMessage(role: ChatRole.assistant, text: faq.answer));
      } else {
        final reply = await repo.ask(text);
        if (_disposed) return;
        _append(
          ChatMessage(
            role: ChatRole.assistant,
            text: reply['message'] as String,
          ),
        );
        state = state.copyWith(offerHandoff: reply['handoff'] == true);
      }
    } catch (_) {
      if (_disposed) return;
      _append(
        ChatMessage(
          role: ChatRole.notice,
          text: 'The assistant is unavailable right now. You can try sending this conversation to the CISO Office, or visit the office directly.',
        ),
      );
      state = state.copyWith(offerHandoff: true);
    } finally {
      if (!_disposed) {
        state = state.copyWith(busy: false);
        await _save();
      }
    }
  }

  Future<void> handoff(String personId) async {
    if (state.busy || state.messages.isEmpty || state.ticketId != null) return;
    state = state.copyWith(busy: true);
    try {
      final result = await ref
          .read(chatRepositoryProvider)
          .escalate(state, personId);
      if (_disposed) return;
      state = state.copyWith(
        ticketId: result['ticketId'] as String,
        ticketToken: result['token'] as String,
        offerHandoff: false,
      );
      _append(
        ChatMessage(
          role: ChatRole.notice,
          text: 'Your conversation has been sent to the CISO Office. Their reply will appear here. Keep this browser history to check for a reply.',
        ),
      );
    } on AppException catch (error) {
      if (!_disposed) {
        state = state.copyWith(error: error.message);
      }
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          error: 'Your message was not sent to the office. Please try again later or visit the CISO Office.',
        );
      }
    } finally {
      if (!_disposed) {
        final error = state.error;
        state = state.copyWith(busy: false, error: error);
        await _save();
      }
    }
  }

  Future<void> checkReply() async {
    if (state.busy || state.ticketId == null) return;
    state = state.copyWith(busy: true);
    try {
      final response = await ref.read(chatRepositoryProvider).status(state);
      if (_disposed) return;
      final reply = response['reply'] as String?;
      if (reply != null && reply != state.lastReply) {
        _append(ChatMessage(role: ChatRole.office, text: reply));
        state = state.copyWith(lastReply: reply);
      } else if (reply == null) {
        state = state.copyWith(
          error: 'Your question is still waiting for an office reply.',
        );
      }
    } on AppException catch (e) {
      if (!_disposed) state = state.copyWith(error: e.message);
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(error: 'Unable to check for a reply right now.');
      }
    } finally {
      if (!_disposed) {
        final error = state.error;
        state = state.copyWith(busy: false, error: error);
        await _save();
      }
    }
  }

  Future<void> clear() async {
    if (state.busy || state.loading) return;
    state = const ChatState(loading: false, busy: true);
    try {
      await ref.read(chatRepositoryProvider).clear();
      if (!_disposed) state = const ChatState(loading: false);
    } catch (_) {
      if (!_disposed) {
        state = const ChatState(
          loading: false,
          storageWarning: 'Could not erase browser storage. Clear this site data in your browser settings.',
        );
      }
    }
  }
}
