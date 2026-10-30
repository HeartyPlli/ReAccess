import 'package:flutter/material.dart';

class SiteFooter extends StatelessWidget {
  const SiteFooter({
    required this.onSectionSelected,
    required this.onRequest,
    super.key,
  });
  final ValueChanged<String> onSectionSelected;
  final ValueChanged<String> onRequest;
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1E1E20),
    width: double.infinity,
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1240),
        padding: const EdgeInsets.fromLTRB(24, 56, 24, 90),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFFB6B6C0),
            fontSize: 14,
            height: 1.6,
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 40,
                  runSpacing: 30,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 700
                          ? constraints.maxWidth
                          : constraints.maxWidth * .35,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                'assets/images/reaccess_logo.png',
                                width: 36,
                                height: 36,
                              ),
                              const SizedBox(width: 12),
                              Image.asset(
                                'assets/images/tcgc_logo.png',
                                width: 36,
                                height: 36,
                                semanticLabel:
                                    'Tangub City Global College seal',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'ReAccess Hub',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                          const Text(
                            'Tangub City Global College · CISO Office',
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Office 365 account services and support for the TCGC community.',
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('QUICK LINKS'),
                          for (final item in const [
                            ('home', 'Home'),
                            ('about', 'About'),
                            ('services', 'Account Services'),
                            ('process', 'How It Works'),
                            ('help', 'Need Help'),
                          ])
                            _Link(item.$2, () => onSectionSelected(item.$1)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Label('USER ACCESS'),
                          _Link('Student Request', () => onRequest('Student')),
                          _Link('Faculty Request', () => onRequest('Faculty')),
                        ],
                      ),
                    ),
                    const SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Label('CONTACT'),
                          Text(
                            'CISO Office',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text('Tangub City Global College'),
                          SizedBox(height: 12),
                          Text(
                            'Visit the office for account assistance and identity verification.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Divider(color: Color(0xFF39393D)),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 32,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '© ${DateTime.now().year} Tangub City Global College. All rights reserved.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  _Link(
                    'Chat privacy',
                    () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Chat privacy'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'Chat history is stored in this browser for up to 30 days. Anyone using this browser profile may see it. Clear the chat on a shared device.\n\nSending a typed question sends it to our backend and AI provider. Selecting Ask the CISO Office sends the recent conversation to office staff. Do not include passwords, verification codes, IDs, grades, or financial information.\n\nClearing local history does not delete a question already sent to the office. Contact the CISO Office about stored support records.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFFBAB7EF),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Link extends StatelessWidget {
  const _Link(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFB6B6C0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.centerLeft,
    ),
    onPressed: onTap,
    child: Text(text),
  );
}
