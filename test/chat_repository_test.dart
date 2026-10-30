import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reaccess_hub/core/network/api_client.dart';
import 'package:reaccess_hub/core/network/auth_token_store.dart';
import 'package:reaccess_hub/features/support/data/chat_repository.dart';
import 'package:reaccess_hub/features/support/domain/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatRepository repository;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = ChatRepository(ApiClient(AuthTokenStore()));
  });
  test('history and ticket restore without a login', () async {
    await repository.save(
      ChatState(
        loading: false,
        messages: [
          ChatMessage(role: ChatRole.user, text: 'Help with recovery'),
        ],
        ticketId: 'ticket',
        ticketToken: 'visitor-only-capability',
      ),
    );
    final restored = await repository.restore();
    expect(restored.messages.single.text, 'Help with recovery');
    expect(restored.ticketToken, 'visitor-only-capability');
    await repository.clear();
    expect((await repository.restore()).messages, isEmpty);
  });
  test('expired history is removed', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ChatRepository.storageKey,
      jsonEncode({
        'savedAt': DateTime.now()
            .subtract(const Duration(days: 31))
            .toIso8601String(),
        'messages': [],
      }),
    );
    expect((await repository.restore()).messages, isEmpty);
    expect(prefs.containsKey(ChatRepository.storageKey), isFalse);
  });
  test('corrupt history cannot break the homepage', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ChatRepository.storageKey, 'invalid-json');
    expect((await repository.restore()).loading, isFalse);
    expect((await repository.restore()).storageWarning, isNotNull);
  });
}
