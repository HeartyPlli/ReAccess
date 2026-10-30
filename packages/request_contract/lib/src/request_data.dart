import 'catalog.dart';

class RequestData {
  RequestData({
    required this.personKind,
    required this.requestKind,
    required Map<String, String> fields,
  }) : fields = Map.unmodifiable(fields);
  final PersonKind personKind;
  final RequestKind requestKind;
  final Map<String, String> fields;
  String operator [](String key) => fields[key] ?? '';
  String get identity => '${personKind.code}:${this['personId']}';
  bool get requiresContact => requestKind != RequestKind.update;
  bool get requiresSchoolEmail => requestKind != RequestKind.sspr;

  static const personalKeys = [
    'firstName',
    'middleName',
    'lastName',
    'personId',
    'institute',
    'program',
    'position',
    'schoolEmail',
    'contact',
    'gmail',
  ];
  static const detailKeys = [
    'alternativeGmail',
    'newContact',
    'reason',
    'notes',
  ];

  factory RequestData.fromJson(Map<String, dynamic> json) {
    final person = PersonKind.values
        .where((e) => e.code == json['personKind'])
        .firstOrNull;
    final kind = RequestKind.values
        .where((e) => e.code == json['requestKind'])
        .firstOrNull;
    if (person == null || kind == null || json['fields'] is! Map) {
      throw const FormatException('Invalid request type.');
    }
    final values = <String, String>{};
    final fields = json['fields'] as Map;
    if (fields.keys.any(
      (key) => ![...personalKeys, ...detailKeys].contains(key),
    )) {
      throw const FormatException('Unknown field.');
    }
    for (final key in [...personalKeys, ...detailKeys]) {
      final value = fields[key] ?? '';
      if (value is! String || value.length > 4000) {
        throw const FormatException('Invalid field.');
      }
      values[key] = value.trim();
    }
    for (final key in ['firstName', 'middleName', 'lastName']) {
      values[key] = titleCaseName(values[key]!).replaceAll(RegExp(r'\s+'), ' ');
    }
    values['personId'] = values['personId']!.toUpperCase();
    for (final key in ['gmail', 'schoolEmail', 'alternativeGmail']) {
      values[key] = values[key]!.toLowerCase();
    }
    // Discard irrelevant fields so they cannot become hidden request changes.
    values[person == PersonKind.student ? 'position' : 'program'] = '';
    if (kind == RequestKind.sspr) values['schoolEmail'] = '';
    if (kind == RequestKind.update) {
      values['gmail'] = '';
      values['contact'] = '';
    }
    if (kind != RequestKind.update) {
      values['alternativeGmail'] = '';
      values['newContact'] = '';
    }
    if (kind != RequestKind.recovery) values['reason'] = '';
    return RequestData(personKind: person, requestKind: kind, fields: values);
  }
  Map<String, Object?> toJson() => {
    'personKind': personKind.code,
    'requestKind': requestKind.code,
    'fields': fields,
  };
  Map<String, Object?> get identityJson => {
    'personKind': personKind.code,
    'requestKind': requestKind.code,
    'fields': {for (final key in personalKeys) key: this[key]},
  };
  Map<String, String> validate({
    bool details = true,
    Map<String, List<String>>? instituteCatalog,
  }) {
    final catalog = instituteCatalog ?? institutePrograms;
    final errors = <String, String>{};
    void check(String key, String? error) {
      if (error != null) errors[key] = error;
    }

    check('firstName', nameError(this['firstName']));
    check('lastName', nameError(this['lastName']));
    check('middleName', nameError(this['middleName'], optional: true));
    check('personId', idError(this['personId'], personKind));
    if (!catalog.containsKey(this['institute'])) {
      errors['institute'] = 'Select an institute.';
    }
    if (personKind == PersonKind.student &&
        !(catalog[this['institute']] ?? []).contains(this['program'])) {
      errors['program'] = 'Select a program from your institute.';
    }
    if (personKind == PersonKind.faculty &&
        !facultyPositions.contains(this['position'])) {
      errors['position'] = 'Select Full Time or Part Time.';
    }
    if (requiresSchoolEmail) {
      final expected = schoolEmailFor(this['firstName'], this['lastName']);
      if (!RegExp(r'^[a-z]+@gadtc\.edu\.ph$').hasMatch(this['schoolEmail']) ||
          this['schoolEmail'] != expected) {
        errors['schoolEmail'] =
            'Use lastnamefirstname@gadtc.edu.ph, matching your name.';
      }
    }
    if (requiresContact) {
      check('contact', phoneError(this['contact']));
      check('gmail', gmailError(this['gmail']));
    }
    if (details) {
      if (this['notes'].length > 2000) {
        errors['notes'] = 'Use at most 2,000 characters.';
      }
      if (requestKind == RequestKind.recovery &&
          (this['reason'].isEmpty || this['reason'].length > 2000)) {
        errors['reason'] = 'Enter a recovery reason (up to 2,000 characters).';
      }
      if (requestKind == RequestKind.update) {
        if (this['alternativeGmail'].isEmpty && this['newContact'].isEmpty) {
          errors['alternativeGmail'] =
              'Enter an alternative Gmail address, a contact number, or both.';
        }
        check(
          'alternativeGmail',
          gmailError(this['alternativeGmail'], optional: true),
        );
        check('newContact', phoneError(this['newContact'], optional: true));
      }
    }
    return errors;
  }
}
