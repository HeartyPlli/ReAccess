import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../public_site/domain/entities/help_content.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_message.dart';
import '../providers/chat_controller.dart';

class SupportChat extends ConsumerStatefulWidget {
  const SupportChat({super.key});
  @override
  ConsumerState<SupportChat> createState() => _SupportChatState();
}

class _SupportChatState extends ConsumerState<SupportChat> {
  bool _open = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _confirm(String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _send([String? question]) async {
    final text = (question ?? _input.text).trim();
    if (text.isEmpty) return;
    final state = ref.read(chatControllerProvider);
    if (state.loading || state.busy || state.ticketId != null) return;
    if (ref.read(chatRepositoryProvider).faqFor(text) == null &&
        !state.aiConsent) {
      await ref.read(chatControllerProvider.notifier).consentToAi();
    }
    if (!mounted) return;
    _input.clear();
    await ref.read(chatControllerProvider.notifier).send(text);
  }

  Future<void> _requestHandoff() async {
    final form = GlobalKey<FormState>();
    var enteredId = '';
    final personId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify your school ID'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the ID number already registered with the school. The conversation can be sent to the CISO Office only after the ID is found.',
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    autofocus: true,
                    maxLength: 6,
                    onChanged: (value) => enteredId = value,
                    textCapitalization: TextCapitalization.characters,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      labelText: 'ID number',
                      hintText: 'Student or faculty ID',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final id = value?.trim().toUpperCase() ?? '';
                      if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(id)) {
                        return 'Enter exactly 6 letters or numbers for the ID.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) {
                      if (form.currentState?.validate() == true) {
                        Navigator.pop(dialogContext, enteredId.trim());
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your ID number will be linked to the support ticket. Do not enter a password or verification code.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (form.currentState?.validate() == true) {
                Navigator.pop(dialogContext, enteredId.trim());
              }
            },
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Verify and continue'),
          ),
        ],
      ),
    );
    if (personId == null || !mounted) return;
    await ref.read(chatControllerProvider.notifier).handoff(personId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.busy != next.busy) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    if (!_open) {
      return Positioned(
        right: 24,
        bottom: 24,
        child: FloatingActionButton(
          tooltip: 'Open support chat',
          backgroundColor: AppTheme.accent,
          foregroundColor: Colors.white,
          onPressed: () {
            setState(() => _open = true);
            ref.read(chatControllerProvider.notifier).checkReply();
          },
          child: const Icon(Icons.chat_bubble_outline),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      right: 12,
      bottom: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = MediaQuery.sizeOf(context);
          final available = math.max(
            180.0,
            size.height - MediaQuery.viewInsetsOf(context).bottom - 112,
          );
          return SizedBox(
            width: math.min(400, size.width - 24),
            height: math.min(590, available),
            child: Material(
              elevation: 14,
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFF252527),
                    padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.accent,
                          child: Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ReAccess Hub Assistant',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                'CISO Office · Automated help',
                                style: TextStyle(
                                  color: Color(0xFFBBBBBF),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Clear chat history',
                          onPressed: state.busy || state.loading
                              ? null
                              : () async {
                                  if (await _confirm(
                                        'Clear this chat?',
                                        'This removes the conversation from this browser. Any conversation already sent to the office remains there. You will lose access to its replies on this device.',
                                        'Clear chat',
                                      ) &&
                                      mounted) {
                                    await ref
                                        .read(chatControllerProvider.notifier)
                                        .clear();
                                  }
                                },
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close support chat',
                          onPressed: () => setState(() => _open = false),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (state.messages.isEmpty) ...[
                                const _Bubble(message: null),
                                const SizedBox(height: 12),
                                Text(
                                  'COMMON QUESTIONS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              for (final message in state.messages)
                                _Bubble(message: message),
                              if (state.ticketId == null) ...[
                                if (state.messages.isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'YOU MIGHT ALSO WANT TO KNOW',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                for (final faq
                                    in (state.messages.isEmpty
                                        ? helpQuestions
                                        : helpQuestions.take(3)))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: scheme.surface,
                                        foregroundColor: scheme.onSurface,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: state.busy
                                          ? null
                                          : () => _send(faq.question),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              faq.question,
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward,
                                            size: 17,
                                            color: scheme.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                              if (state.offerHandoff && state.ticketId == null)
                                FilledButton.icon(
                                  onPressed: state.busy
                                      ? null
                                      : _requestHandoff,
                                  icon: const Icon(Icons.support_agent),
                                  label: const Text('Ask the CISO Office'),
                                ),
                              if (state.ticketId != null)
                                OutlinedButton.icon(
                                  onPressed: state.busy
                                      ? null
                                      : () => ref
                                            .read(
                                              chatControllerProvider.notifier,
                                            )
                                            .checkReply(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Check for office reply'),
                                ),
                              if (state.busy)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: LinearProgressIndicator(),
                                ),
                              if (state.error != null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    state.error!,
                                    style: TextStyle(
                                      color: scheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              if (state.storageWarning != null)
                                Text(
                                  state.storageWarning!,
                                  style: TextStyle(
                                    color: scheme.error,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                  ),
                  Container(
                    color: scheme.surface,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                enabled:
                                    !state.loading &&
                                    !state.busy &&
                                    state.ticketId == null,
                                minLines: 1,
                                maxLines: 3,
                                maxLength: 1000,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: state.ticketId != null
                                      ? 'Waiting for the CISO Office'
                                      : 'Type your question...',
                                  counterText: '',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: 'Send question',
                              onPressed:
                                  state.loading ||
                                      state.busy ||
                                      state.ticketId != null
                                  ? null
                                  : () => _send(),
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.send_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'AI handles typed questions. Ask CISO verifies your ID before sharing with staff. Never send passwords or codes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage? message;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = message?.role == ChatRole.user;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 315),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: user ? AppTheme.accent : scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: user ? null : Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message?.role == ChatRole.office)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  'CISO OFFICE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            SelectableText(
              message?.text ?? 'Hello! How can we help with your Office 365 account? Choose a question below or ask something else.',
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: user ? Colors.white : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
