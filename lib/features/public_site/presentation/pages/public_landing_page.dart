import 'package:flutter/material.dart';

import '../../../support/presentation/widgets/support_chat.dart';
import '../widgets/landing_sections.dart';
import '../widgets/help_section.dart';
import '../widgets/site_footer.dart';
import '../widgets/site_header.dart';

import 'package:go_router/go_router.dart';

class PublicLandingPage extends StatefulWidget {
  const PublicLandingPage({super.key});
  @override
  State<PublicLandingPage> createState() => _PublicLandingPageState();
}

class _PublicLandingPageState extends State<PublicLandingPage> {
  final _keys = {
    for (final name in ['home', 'about', 'services', 'process', 'help'])
      name: GlobalKey(),
  };
  void _scrollTo(String name) {
    final target = _keys[name]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: SiteHeader(onSectionSelected: _scrollTo),
    body: Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            child: Column(
              children: [
                KeyedSubtree(
                  key: _keys['home'],
                  child: HeroSection(
                    onRequest: (type) =>
                        context.go('/request/${type.toLowerCase()}'),
                  ),
                ),
                KeyedSubtree(key: _keys['about'], child: const AboutSection()),
                KeyedSubtree(
                  key: _keys['services'],
                  child: const ServicesSection(),
                ),
                KeyedSubtree(
                  key: _keys['process'],
                  child: const ProcessSection(),
                ),
                KeyedSubtree(key: _keys['help'], child: const HelpSection()),
                SiteFooter(
                  onSectionSelected: _scrollTo,
                  onRequest: (type) =>
                      context.go('/request/${type.toLowerCase()}'),
                ),
              ],
            ),
          ),
        ),
        const SupportChat(),
      ],
    ),
  );
}
