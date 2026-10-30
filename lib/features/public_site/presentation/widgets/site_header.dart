import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_controller.dart';

class SiteHeader extends ConsumerWidget implements PreferredSizeWidget {
  const SiteHeader({required this.onSectionSelected, super.key});
  final ValueChanged<String> onSectionSelected;
  @override
  Size get preferredSize => const Size.fromHeight(88);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/school_pic_top_view.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Color(0xE619242D), BlendMode.srcATop),
          ),
          border: Border(bottom: BorderSide(color: Color(0xFF6562AA))),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => onSectionSelected('home'),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Image.asset(
                            'assets/images/reaccess_logo.png',
                            semanticLabel: 'ReAccess Hub',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'ReAccess Hub',
                                  style: TextStyle(
                                    fontSize: 23,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                MediaQuery.sizeOf(context).width < 480
                                    ? 'CISO Office'
                                    : 'CISO Office · Office 365 Services',
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Color(0xFFBABCC5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: dark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: () =>
                      ref.read(themeControllerProvider.notifier).toggle(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .10),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(
                    dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
