import 'package:flutter_test/flutter_test.dart';
import 'package:request_contract/request_contract.dart';

void main() {
  test('six institutes have correctly connected programs', () {
    expect(institutePrograms.length, 6);
    expect(institutePrograms.values.map((v) => v.length).toList(), [
      1,
      1,
      3,
      5,
      4,
      2,
    ]);
    expect(
      institutePrograms.values.first.single,
      'Bachelor of Science in Computer Science',
    );
  });
  test('IDs and contact formats are validated', () {
    expect(idError('123456', PersonKind.student), isNull);
    for (final id in ['12345', '1234567', 'ABC123', '123 56']) {
      expect(idError(id, PersonKind.student), isNotNull);
    }
    for (final id in ['AB1234', 'ACB123', '1921GA', 'ABCDEF', '123456']) {
      expect(idError(id, PersonKind.faculty), isNull, reason: id);
    }
    for (final id in ['ABC12', 'ABC1234', 'AB-123', 'AB 123', 'AB_123']) {
      expect(idError(id, PersonKind.faculty), isNotNull, reason: id);
    }
    expect(gmailError('juan@gmail.com'), isNull);
    expect(gmailError('juan@example.com'), isNotNull);
    expect(phoneError('09123456789'), isNull);
    expect(phoneError('123'), isNotNull);
    expect(titleCaseName('juan dela cruz'), 'Juan Dela Cruz');
    expect(schoolEmailFor('Juan', 'Dela Cruz'), 'delacruzjuan@gadtc.edu.ph');
  });
  test('update requires at least one valid replacement contact', () {
    final raw = <String, dynamic>{
      'personKind': 'STUDENT',
      'requestKind': 'UPDATE',
      'fields': {
        'firstName': 'Juan',
        'lastName': 'Cruz',
        'personId': '123456',
        'institute': institutePrograms.keys.first,
        'program': institutePrograms.values.first.single,
        'schoolEmail': 'cruzjuan@gadtc.edu.ph',
      },
    };
    expect(RequestData.fromJson(raw).validate(details: false), isEmpty);
    expect(RequestData.fromJson(raw).validate()['alternativeGmail'], isNotNull);
    (raw['fields'] as Map)['newContact'] = '09123456789';
    expect(RequestData.fromJson(raw).validate(), isEmpty);
    (raw['fields'] as Map)['alternativeGmail'] = 'wrong';
    expect(RequestData.fromJson(raw).validate()['alternativeGmail'], isNotNull);
  });
}
