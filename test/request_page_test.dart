import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reaccess_hub/core/network/api_client.dart';
import 'package:reaccess_hub/core/network/auth_token_store.dart';
import 'package:reaccess_hub/core/errors/app_exception.dart';
import 'package:reaccess_hub/features/requests/data/request_repository.dart';
import 'package:reaccess_hub/features/requests/presentation/request_page.dart';
import 'package:request_contract/request_contract.dart';

class FakeRepository extends RequestRepository {
  FakeRepository() : super(ApiClient(AuthTokenStore()));
  bool fail = false;
  RequestData? saved;
  @override
  Future<RequestSettings> settings() async => const RequestSettings(
    institutions: institutePrograms,
    studentRequestLimit: 2,
  );

  @override
  Future<Verification> verify(RequestData data) async {
    if (fail) throw AppException('Information could not be verified.');
    return Verification(
      'test-token',
      2,
      studentRequestLimit: data.personKind == PersonKind.student ? 2 : 0,
      requiresFormalLetter: data.personKind == PersonKind.student,
    );
  }

  @override
  Future<String> submit(RequestData data, String token) async {
    saved = data;
    return 'REQ-${data.personKind.prefix}-2026-09-0001';
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.enterText(find.byKey(ValueKey(key)), value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dependent programs and invalid fields fit a narrow screen', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestRepositoryProvider.overrideWithValue(FakeRepository()),
        ],
        child: const MaterialApp(home: RequestPage(person: PersonKind.student)),
      ),
    );
    await tap(tester, find.text('SSPR Enrollment'));
    await tap(tester, find.text('Next'));
    final disabled = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('program:')),
    );
    expect(disabled.onChanged, isNull);
    await enter(tester, 'personId', '12X');
    expect(find.text('Enter a valid 6-digit Student ID.'), findsOneWidget);
    await enter(tester, 'gmail', 'not-an-email');
    expect(find.textContaining('Enter a valid Gmail address'), findsOneWidget);
    const institute = 'Institute of Business and Financial Services';
    await tap(tester, find.byKey(const ValueKey('institute:')));
    await tap(tester, find.text(institute).last);
    await tap(tester, find.byKey(const ValueKey('program:')));
    await tap(tester, find.text(institutePrograms[institute]!.first).last);
    expect(tester.takeException(), isNull);
    final field = find.byKey(
      ValueKey('program:${institutePrograms[institute]!.first}'),
    );
    expect(tester.getSize(field).height, greaterThan(70));
    await tap(
      tester,
      find.byKey(
        const ValueKey(
          'institute:Institute of Business and Financial Services',
        ),
      ),
    );
    await tap(tester, find.text('Institute of Health Sciences').last);
    expect(find.text('Diploma in Midwifery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final person in PersonKind.values) {
    for (final kind in RequestKind.values) {
      testWidgets(
        '${person.label} ${kind.label} completes all stages at mobile width',
        (tester) async {
          tester.view
            ..physicalSize = const Size(390, 900)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = FakeRepository();
          await tester.pumpWidget(
            ProviderScope(
              overrides: [requestRepositoryProvider.overrideWithValue(repo)],
              child: MaterialApp(home: RequestPage(person: person)),
            ),
          );
          await tap(tester, find.text(kind.label));
          await tap(tester, find.text('Next'));
          await enter(tester, 'firstName', 'juan');
          await enter(tester, 'lastName', 'cruz');
          await enter(
            tester,
            'personId',
            person == PersonKind.student ? '123456' : 'AB1234',
          );
          await tap(tester, find.byKey(const ValueKey('institute:')));
          await tap(tester, find.text(institutePrograms.keys.first).last);
          if (person == PersonKind.faculty) {
            await tap(tester, find.byKey(const ValueKey('position:')));
            await tap(tester, find.text('Full Time').last);
          } else {
            expect(
              find.text(institutePrograms.values.first.single),
              findsOneWidget,
            );
          }
          if (kind != RequestKind.sspr) {
            await enter(tester, 'schoolEmail', 'cruzjuan@gadtc.edu.ph');
          }
          if (kind != RequestKind.update) {
            await enter(tester, 'contact', '09123456789');
            await enter(tester, 'gmail', 'juan@gmail.com');
          }
          await tap(tester, find.text('Next'));
          expect(find.text('Juan Cruz'), findsOneWidget);
          if (person == PersonKind.student && kind == RequestKind.sspr) {
            repo.fail = true;
            await tap(tester, find.text('Verify Identity'));
            expect(
              find.text('Information could not be verified.'),
              findsOneWidget,
            );
            expect(find.text('Submit Request'), findsNothing);
            repo.fail = false;
          }
          await tap(tester, find.text('Verify Identity'));
          if (person == PersonKind.faculty && kind != RequestKind.sspr) {
            expect(find.text('Previous requests submitted: 2'), findsOneWidget);
          }
          if (person == PersonKind.student) {
            expect(
              find.text('Request 3 for this service · limit 2'),
              findsOneWidget,
            );
          }
          if (kind == RequestKind.recovery) {
            await enter(tester, 'reason', 'Unable to access my account');
          }
          if (kind == RequestKind.update) {
            await tap(tester, find.text('Review'));
            expect(
              find.textContaining('Enter an alternative Gmail'),
              findsOneWidget,
            );
            await enter(tester, 'newContact', '09123456789');
          }
          await tap(tester, find.text('Review'));
          await tap(tester, find.text('Submit Request'));
          expect(find.text('Request Submitted!'), findsOneWidget);
          expect(repo.saved!.personKind, person);
          expect(repo.saved!.requestKind, kind);
          expect(repo.saved!['firstName'], 'Juan');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
