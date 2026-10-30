enum ChatRole { user, assistant, office, notice }

class ChatMessage {
  ChatMessage({required this.role, required this.text, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();
  final ChatRole role;
  final String text;
  final DateTime createdAt;
  Map<String, Object?> toJson() => {
    'role': role.name,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: ChatRole.values.byName(json['role'] as String),
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

class ChatState {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.busy = false,
    this.offerHandoff = false,
    this.aiConsent = false,
    this.ticketId,
    this.ticketToken,
    this.lastReply,
    this.error,
    this.storageWarning,
  });
  final List<ChatMessage> messages;
  final bool loading;
  final bool busy;
  final bool offerHandoff;
  final bool aiConsent;
  final String? ticketId;
  final String? ticketToken;
  final String? lastReply;
  final String? error;
  final String? storageWarning;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? loading,
    bool? busy,
    bool? offerHandoff,
    bool? aiConsent,
    String? ticketId,
    String? ticketToken,
    String? lastReply,
    String? error,
    String? storageWarning,
  }) => ChatState(
    messages: messages ?? this.messages,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    offerHandoff: offerHandoff ?? this.offerHandoff,
    aiConsent: aiConsent ?? this.aiConsent,
    ticketId: ticketId ?? this.ticketId,
    ticketToken: ticketToken ?? this.ticketToken,
    lastReply: lastReply ?? this.lastReply,
    error: error,
    storageWarning: storageWarning ?? this.storageWarning,
  );
}
