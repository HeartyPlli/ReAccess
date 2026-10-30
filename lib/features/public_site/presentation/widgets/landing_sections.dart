import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SectionBand extends StatelessWidget {
  const SectionBand({required this.child, this.alternate = false, super.key});
  final Widget child;
  final bool alternate;
  @override
  Widget build(BuildContext context) => Material(
    color: alternate
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Theme.of(context).colorScheme.surface,
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1240),
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: MediaQuery.sizeOf(context).width < 600 ? 48 : 76,
        ),
        child: child,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.eyebrow, this.title, {this.description, super.key});
  final String eyebrow;
  final String title;
  final String? description;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        eyebrow,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 14),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      if (description != null) ...[
        const SizedBox(height: 12),
        Text(
          description!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ],
  );
}

class HeroSection extends StatelessWidget {
  const HeroSection({required this.onRequest, super.key});
  final ValueChanged<String> onRequest;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF19314C);
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        return Container(
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: math.min(
              710,
              math.max(540, MediaQuery.sizeOf(context).height - 150),
            ),
          ),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: const AssetImage('assets/images/school_front_view.jfif'),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                dark ? const Color(0xBB0B141C) : const Color(0xDDECF4FC),
                BlendMode.srcATop,
              ),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: mobile ? 44 : 64,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SUBMIT A REQUEST',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: dark
                      ? const Color(0xFFCECDD8)
                      : const Color(0xFF416BC0),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'How can we help you?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: mobile ? 32 : 46,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'Select your user type below for Office 365 account services.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: foreground.withValues(alpha: .85),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 570),
                child: Row(
                  children: [
                    Expanded(
                      child: _RequestCard(
                        type: 'Student',
                        icon: Icons.school_outlined,
                        dark: dark,
                        onTap: () => onRequest('Student'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RequestCard(
                        type: 'Faculty',
                        icon: Icons.person_outline,
                        dark: dark,
                        onTap: () => onRequest('Faculty'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              const SizedBox(height: 16),
              Text(
                'Tangub City Global College · CISO Office',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: foreground.withValues(alpha: .75),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.type,
    required this.icon,
    required this.dark,
    required this.onTap,
  });
  final String type;
  final IconData icon;
  final bool dark;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: dark ? const Color(0xEF292C30) : const Color(0xF9FFFFFF),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFCDDAEF)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 30),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: dark
                  ? const Color(0xFF414148)
                  : const Color(0xFFEEEDF8),
              child: Icon(
                icon,
                size: 30,
                color: dark ? Colors.white : AppTheme.accent,
              ),
            ),
            const SizedBox(height: 18),
            Text(type, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '$type Request',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});
  @override
  Widget build(BuildContext context) => SectionBand(
    alternate: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ABOUT THE SYSTEM',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'About ReAccess Hub',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'ReAccess Hub is a web-based service for Tangub City Global College that connects students and faculty with the CISO Office for Office 365 account assistance, without needing a separate system account.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Text(
              'The CISO Office maintains registered records and verifies your identity before processing account requests. Find the right service, explore common questions, or contact the office for support.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
        final purpose = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SYSTEM PURPOSE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final item in const [
              (
                Icons.person_outline,
                'Access',
                'A clear starting point for students and faculty to request Office 365 account support.',
              ),
              (
                Icons.grid_view_outlined,
                'Organization',
                'Keep requests, status updates, and communication organized for the CISO Office.',
              ),
              (
                Icons.help_outline,
                'Support',
                'Help students and faculty resolve concerns with their institutional accounts.',
              ),
            ]) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.$1, color: Colors.white, size: 23),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(item.$3),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (item.$2 != 'Support') const Divider(height: 1),
            ],
          ],
        );
        return constraints.maxWidth < 800
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 38), purpose],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 64),
                  Expanded(child: purpose),
                ],
              );
      },
    ),
  );
}

const accountServices = [
  (
    Icons.account_tree_outlined,
    'SSPR Enrollment',
    'Enroll your Office 365 account in Self-Service Password Reset using an alternative email and mobile number.',
    Color(0xFF6562AA),
  ),
  (
    Icons.restart_alt,
    'Account Recovery',
    'Request assistance when you can no longer access your institutional Office 365 account. A formal letter is required.',
    Color(0xFF087FC4),
  ),
  (
    Icons.manage_accounts_outlined,
    'Account Update',
    'Request an update to your registered account information: name, email address, contact number, and more.',
    Color(0xFF278543),
  ),
];

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});
  @override
  Widget build(BuildContext context) => SectionBand(
    child: Column(
      children: [
        const SectionTitle(
          'WHAT WE OFFER',
          'Account Services',
          description: 'Office 365 account support for our college community.',
        ),
        const SizedBox(height: 42),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              for (final service in accountServices)
                SizedBox(
                  width: constraints.maxWidth < 700
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 48) / 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: service.$4.withValues(alpha: .12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              service.$1,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color.lerp(service.$4, Colors.white, .4)
                                  : service.$4,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            service.$2,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Color.lerp(service.$4, Colors.white, .4)
                                      : service.$4,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(service.$3),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProcessSection extends StatelessWidget {
  const ProcessSection({super.key});
  @override
  Widget build(BuildContext context) => SectionBand(
    alternate: true,
    child: Column(
      children: [
        const SectionTitle('PROCESS', 'How ReAccess Hub Works'),
        const SizedBox(height: 48),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 480
                ? 1
                : constraints.maxWidth < 850
                ? 2
                : 4;
            return Wrap(
              spacing: 28,
              runSpacing: 36,
              children: [
                for (final step in const [
                  (
                    '01',
                    Icons.description_outlined,
                    'Select Request',
                    'Choose Student or Faculty and find the account service you need.',
                  ),
                  (
                    '02',
                    Icons.verified_user_outlined,
                    'Verify Identity',
                    'The CISO Office verifies your identity against its registered records.',
                  ),
                  (
                    '03',
                    Icons.assignment_outlined,
                    'Submit Details',
                    'Provide the request details and documents required by the office.',
                  ),
                  (
                    '04',
                    Icons.notifications_none,
                    'Get Notified',
                    'The CISO Office reviews your request and confirms the next steps.',
                  ),
                ])
                  SizedBox(
                    width:
                        (constraints.maxWidth - (columns - 1) * 28) / columns,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 31,
                          backgroundColor: AppTheme.accent,
                          child: Icon(step.$2, color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          step.$1,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.$3,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(step.$4, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
