import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reaccess_hub/app.dart';
import 'package:reaccess_hub/core/network/api_client.dart';
import 'package:reaccess_hub/core/network/auth_token_store.dart';
import 'package:reaccess_hub/features/support/data/chat_repository.dart';
import 'package:reaccess_hub/features/support/domain/chat_message.dart';

class TestChat extends ChatRepository {
  TestChat() : super(ApiClient(AuthTokenStore()));
  int questions = 0, handoffs = 0;
  @override
  Future<Map<String, dynamic>> ask(String text) async {
    questions++;
    return {'message': 'Please ask the CISO Office.', 'handoff': true};
  }

  @override
  Future<Map<String, dynamic>> escalate(
    ChatState state,
    String personId,
  ) async {
    expect(personId, '123456');
    handoffs++;
    return {'ticketId': 'test-ticket', 'token': 'test-token'};
  }
}

void main() {
  testWidgets('AI and office send directly; deletion still asks confirmation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(1200, 1000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final chat = TestChat();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chatRepositoryProvider.overrideWithValue(chat)],
        child: const SchoolManagementApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open support chat'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(OutlinedButton, 'What is my school email?'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'I need some help');
    await tester.tap(find.byTooltip('Send question'));
    await tester.pumpAndSettle();
    expect(chat.questions, 1);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.ensureVisible(find.text('Ask the CISO Office'));
    await tester.tap(find.text('Ask the CISO Office'));
    await tester.pumpAndSettle();
    expect(find.text('Verify your school ID'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ID number'),
      '123456',
    );
    await tester.tap(find.text('Verify and continue'));
    await tester.pumpAndSettle();
    expect(chat.handoffs, 1);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.byTooltip('Clear chat history'));
    await tester.pumpAndSettle();
    expect(find.text('Clear this chat?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Your conversation has been sent'),
      findsOneWidget,
    );
  });
}
