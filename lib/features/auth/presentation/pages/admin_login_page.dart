import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../shared/widgets/theme_toggle.dart';
import '../providers/auth_controller.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});
  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController(),
      _password = TextEditingController();
  bool _show = false, _remember = false;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    if (mounted && _username.text.isEmpty) {
      setState(() {
        _username.text = p.getString('reaccess.admin.username') ?? '';
        _remember = _username.text.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(email: _username.text, password: _password.text);
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.isAuthenticated && auth.user!.canAccessAdmin) {
      final p = await SharedPreferences.getInstance();
      if (_remember) {
        await p.setString('reaccess.admin.username', _username.text.trim());
      } else {
        await p.remove('reaccess.admin.username');
      }
      if (mounted) {
        context.go(
          auth.user!.mustChangePassword
              ? '/admin/settings'
              : '/admin/dashboard',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final busy = auth.status == AuthStatus.loading;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    const brandColor = Color(0xFF5054A5);
    final pageBackground = dark
        ? const Color(0xFF101318)
        : const Color(0xFFF3F5FA);
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Return home',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: const [ThemeToggle(), SizedBox(width: 16)],
      ),
      body: LayoutBuilder(
        builder: (context, viewport) {
          final compact = viewport.maxWidth < 760;
          final verySmall = viewport.maxWidth < 390;
          final horizontalPadding = verySmall ? 12.0 : 24.0;
          const topPadding = 18.0;
          final bottomPadding = MediaQuery.viewInsetsOf(context).bottom + 24.0;
          final minimumContentHeight =
              (viewport.maxHeight - topPadding - bottomPadding)
                  .clamp(0.0, double.infinity)
                  .toDouble();
          final brand = Container(
            width: compact ? double.infinity : 310,
            padding: EdgeInsets.all(compact ? 22 : 34),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF262C73), Color(0xFF5054A5)],
              ),
            ),
            child: compact
                ? Row(
                    children: [
                      Image.asset(
                        'assets/images/tcgc_logo.png',
                        width: 58,
                        height: 58,
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ReAccess Hub',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'CISO Admin Portal',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Image.asset(
                        'assets/images/reaccess_logo.png',
                        width: 42,
                        height: 42,
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/tcgc_logo.png',
                            width: 72,
                            height: 72,
                          ),
                          const SizedBox(width: 18),
                          Image.asset(
                            'assets/images/reaccess_logo.png',
                            width: 62,
                            height: 62,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'ReAccess Hub',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'CISO Admin Portal',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                      const SizedBox(height: 32),
                      const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Authorized school personnel only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                    ],
                  ),
          );
          final loginForm = Padding(
            padding: EdgeInsets.all(
              verySmall
                  ? 20
                  : compact
                  ? 28
                  : 36,
            ),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with your CISO personnel credentials.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _username,
                      enabled: !busy,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'Enter your username',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your username.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _password,
                      enabled: !busy,
                      obscureText: !_show,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _show ? 'Hide password' : 'Show password',
                          onPressed: () => setState(() => _show = !_show),
                          icon: Icon(
                            _show
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _remember,
                      onChanged: busy
                          ? null
                          : (value) =>
                                setState(() => _remember = value ?? false),
                      title: const Text('Remember username'),
                    ),
                    if (auth.message != null)
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  auth.message!,
                                  style: TextStyle(color: colors.onSurface),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: brandColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: busy ? null : _submit,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(busy ? 'Signing in...' : 'Sign In'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => showDialog<void>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Account recovery'),
                                content: const Text(
                                  'Contact the authorized system administrator to recover your username or reset a forgotten password. Recovery cannot bypass identity verification.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            ),
                      child: const Text('Forgot username or password?'),
                    ),
                  ],
                ),
              ),
            ),
          );
          return ColoredBox(
            color: pageBackground,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minimumContentHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            elevation: dark ? 0 : 8,
                            shadowColor: Colors.black26,
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: compact
                                ? Column(children: [brand, loginForm])
                                : IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        brand,
                                        Expanded(child: loginForm),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Tangub City Global College · CISO Office',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
