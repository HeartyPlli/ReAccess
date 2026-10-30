import 'package:flutter/material.dart';

import '../../domain/entities/help_content.dart';
import 'landing_sections.dart';

class HelpSection extends StatelessWidget {
  const HelpSection({super.key});
  @override
  Widget build(BuildContext context) => SectionBand(
    child: Column(
      children: [
        const SectionTitle(
          'HELP CENTER',
          'Need Help?',
          description: 'Find answers to common questions or contact the CISO Office directly.',
        ),
        const SizedBox(height: 42),
        LayoutBuilder(
          builder: (context, constraints) {
            final questions = DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                      'FREQUENTLY ASKED QUESTIONS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final faq in helpQuestions)
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 22),
                      childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
                      title: Text(
                        faq.question,
                        style: const TextStyle(fontSize: 15),
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(faq.answer),
                        ),
                      ],
                    ),
                ],
              ),
            );
            final office = Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CISO OFFICE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  for (final item in const [
                    ('INSTITUTION', 'Tangub City Global College'),
                    ('EMAIL', 'Official email to be announced'),
                    ('CONTACT NUMBER', 'Contact number to be announced'),
                    ('OFFICE HOURS', 'Please confirm with the CISO Office'),
                  ]) ...[
                    const SizedBox(height: 24),
                    Text(
                      item.$1,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(item.$2),
                  ],
                ],
              ),
            );
            return constraints.maxWidth < 800
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [questions, const SizedBox(height: 30), office],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: questions),
                      const SizedBox(width: 48),
                      Expanded(flex: 2, child: office),
                    ],
                  );
          },
        ),
      ],
    ),
  );
}
