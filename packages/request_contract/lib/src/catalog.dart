enum PersonKind {
  student('STUDENT', 'Student', 'S'),
  faculty('FACULTY', 'Faculty', 'F');

  const PersonKind(this.code, this.label, this.prefix);
  final String code;
  final String label;
  final String prefix;
}

enum RequestKind {
  sspr(
    'SSPR',
    'SSPR Enrollment',
    'Enroll your Office 365 account in Self-Service Password Reset using an alternative Gmail and mobile number.',
  ),
  recovery(
    'RECOVERY',
    'Account Recovery',
    'Request assistance when you can no longer access your institutional Office 365 account.',
  ),
  update(
    'UPDATE',
    'Account Update',
    'Request an update to your alternative Gmail address or contact number.',
  );

  const RequestKind(this.code, this.label, this.description);
  final String code;
  final String label;
  final String description;
}

const institutePrograms = <String, List<String>>{
  'Institute of Computer Studies': ['Bachelor of Science in Computer Science'],
  'Institute of Health Sciences': ['Diploma in Midwifery'],
  'Institute of Art and Sciences': [
    'Bachelor of Arts in Communication',
    'Bachelor of Arts in English Language',
    'Bachelor of Arts in Political Science',
  ],
  'Institute of Teacher Education': [
    'Bachelor of Elementary Education',
    'Bachelor of Secondary Education Major in English',
    'Bachelor of Secondary Education Major in Filipino',
    'Bachelor of Secondary Education Major in Math',
    'Bachelor of Secondary Education Major in Social Studies',
  ],
  'Institute of Business and Financial Services': [
    'Bachelor of Science in Business Administration Major in Human Resource Management',
    'Bachelor of Science in Business Administration Major in Marketing Management',
    'Bachelor of Science in Office Administration',
    'Bachelor of Science in Business Administration Major in Financial Management',
  ],
  'Institute of Criminal Justice Education': [
    'Bachelor of Science in Criminology',
    'Bachelor of Science in Industrial Security Management',
  ],
};
const facultyPositions = ['Full Time', 'Part Time'];

String titleCaseName(String value) => value.replaceAllMapped(
  RegExp(r"(^|[\s'-])([a-zA-ZÀ-ž])"),
  (m) => '${m[1]}${m[2]!.toUpperCase()}',
);
String normalizeName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
String schoolEmailFor(String first, String last) =>
    '${last.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}${first.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}@gadtc.edu.ph';

String? nameError(String value, {bool optional = false}) {
  final text = value.trim();
  if (optional && text.isEmpty) return null;
  if (text.isEmpty) return 'This name is required.';
  if (text.length > 100 ||
      !RegExp(r"^[a-zA-ZÀ-ž][a-zA-ZÀ-ž .'-]*$").hasMatch(text)) {
    return 'Enter a valid name (up to 100 characters).';
  }
  return null;
}

String? idError(String value, PersonKind kind) {
  if (kind == PersonKind.student) {
    return RegExp(r'^\d{6}$').hasMatch(value)
        ? null
        : 'Enter a valid 6-digit Student ID.';
  }
  return RegExp(r'^[A-Za-z0-9]{6}$').hasMatch(value)
      ? null
      : 'Faculty ID must be exactly 6 letters or numbers, for example AB1234.';
}

String? gmailError(String value, {bool optional = false}) {
  final text = value.trim().toLowerCase();
  if (optional && text.isEmpty) return null;
  return text.length <= 254 &&
          RegExp(r'^[a-z0-9]+(?:\.[a-z0-9]+)*@gmail\.com$').hasMatch(text)
      ? null
      : 'Enter a valid Gmail address, e.g. yourname@gmail.com.';
}

String? phoneError(String value, {bool optional = false}) {
  if (optional && value.trim().isEmpty) return null;
  return RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(value.trim())
      ? null
      : 'Use 09 followed by 9 digits, or +639 followed by 9 digits.';
}
