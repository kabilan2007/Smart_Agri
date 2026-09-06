class ChatMessageModel {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final List<String>? followups;
  final List<String>? govtSchemes;
  final bool isAudioPlaying;

  ChatMessageModel({
    required this.role,
    required this.content,
    required this.timestamp,
    this.followups,
    this.govtSchemes,
    this.isAudioPlaying = false,
  });

  ChatMessageModel copyWith({
    String? role,
    String? content,
    DateTime? timestamp,
    List<String>? followups,
    List<String>? govtSchemes,
    bool? isAudioPlaying,
  }) {
    return ChatMessageModel(
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      followups: followups ?? this.followups,
      govtSchemes: govtSchemes ?? this.govtSchemes,
      isAudioPlaying: isAudioPlaying ?? this.isAudioPlaying,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class AgriChatResponseModel {
  final String reply;
  final String language;
  final List<String> suggestedFollowups;
  final List<String> keyTakeaways;
  final List<String> relatedGovtSchemes;

  AgriChatResponseModel({
    required this.reply,
    required this.language,
    required this.suggestedFollowups,
    required this.keyTakeaways,
    required this.relatedGovtSchemes,
  });

  factory AgriChatResponseModel.fromJson(Map<String, dynamic> json) {
    final rawReply = json['response'] ??
        json['reply'] ??
        json['message'] ??
        json['text'] ??
        '';
    return AgriChatResponseModel(
      reply: rawReply.toString(),
      language: json['language']?.toString() ?? 'en',
      suggestedFollowups: (json['suggested_followups'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      keyTakeaways: (json['key_takeaways'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      relatedGovtSchemes: (json['related_govt_schemes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
