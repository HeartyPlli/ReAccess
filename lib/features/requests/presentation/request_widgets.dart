import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:request_contract/request_contract.dart';

const requestAccent = Color(0xFF6663AB);
const requestStages = [
  'Select Request Type',
  'Personal Information',
  'Identity Verification',
  'Request Details',
  'Review & Submit',
];

class NameCapitalizer extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    return newValue.copyWith(text: titleCaseName(newValue.text));
  }
}

class RequestProgress extends StatelessWidget {
  const RequestProgress({super.key, required this.step, required this.kind});
  final int step;
  final RequestKind? kind;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= step ? requestAccent : const Color(0xFFDCDCE9),
                ),
              ),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= step ? requestAccent : const Color(0xFFE8E8F2),
              ),
              child: i < step
                  ? const Icon(Icons.check, size: 17, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: i <= step ? Colors.white : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            requestStages[step],
            style: const TextStyle(fontSize: 12, color: requestAccent),
          ),
          if (kind != null)
            Text(
              kind!.label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
        ],
      ),
    ],
  );
}

class RequestSummary extends StatelessWidget {
  const RequestSummary({super.key, required this.title, required this.rows});
  final String title;
  final Map<String, String> rows;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainer,
          padding: const EdgeInsets.all(14),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        for (final row in rows.entries)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 95,
                  child: Text(row.key, style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? 'Not provided' : row.value,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class RequestNotice extends StatelessWidget {
  const RequestNotice(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5CC),
      border: Border.all(color: const Color(0xFFE8CC70)),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF70530A),
        fontSize: 13,
        height: 1.5,
      ),
    ),
  );
}
