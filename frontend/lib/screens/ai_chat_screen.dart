import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/colors.dart';
import '../models/chat_message_model.dart';
import '../services/api_service.dart';
import '../services/localization_service.dart';
import '../services/tts_stt_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessageModel> _messages = [];
  final TtsSttService _voice = TtsSttService();
  bool _isLoading = false;
  bool _isListening = false;
  late AnimationController _waveController;

  static const List<String> _quickPrompts = [
    '🌿 How to prepare Panchagavya?',
    '🧪 How to fix acidic soil pH?',
    '🦟 Organic pest control for tomato?',
    '💊 PM-KISAN scheme eligibility?',
    '🌧 Rain alert – what should I do now?',
    '🌾 Best variety of rice for Kharif?',
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Greeting message
    _messages.add(ChatMessageModel(
      role: 'assistant',
      content:
          '🌱 **Hello! I am Smart Agri AI – your 24/7 Agricultural Doctor.**\n\n'
          'I can help you with:\n'
          '• **Soil pH & Nutrient Management** (Red soil, Black soil, Clay)\n'
          '• **Organic Inputs** (Panchagavya, Jeevamrutham, Vermicompost)\n'
          '• **Pest & Disease IPM** with exact dosage\n'
          '• **Government Schemes** (PM-KISAN, PMFBY, KCC, Drip Subsidy)\n'
          '• **Seasonal Crop Planning** & profitability advice\n\n'
          'Ask me anything in **your language**! 🎤',
      timestamp: DateTime.now(),
      followups: _quickPrompts,
    ));
  }

  @override
  void dispose() {
    _waveController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _voice.stopSpeaking();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputController.clear();

    final loc = Provider.of<LocalizationService>(context, listen: false);

    setState(() {
      _messages.add(ChatMessageModel(
        role: 'user',
        content: text.trim(),
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    final response = await ApiService.sendChatMessage(
      message: text.trim(),
      language: loc.currentLocale,
      history: _messages
          .where((m) => m.role != 'assistant' || _messages.last == m)
          .take(10)
          .toList(),
    );

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessageModel(
        role: 'assistant',
        content: response?.reply ??
            '⚠️ Could not reach the server. Please check your connection and try again.',
        timestamp: DateTime.now(),
        followups: response?.suggestedFollowups,
        govtSchemes: response?.relatedGovtSchemes,
      ));
    });
    _scrollToBottom();
  }

  Future<void> _startVoiceInput() async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    setState(() => _isListening = true);
    await _voice.startListening(
      langCode: loc.currentLocale,
      onResult: (text) {
        setState(() {
          _inputController.text = text;
          _isListening = false;
        });
        _sendMessage(text);
      },
      onDone: () => setState(() => _isListening = false),
    );
  }

  Future<void> _speakMessage(String text, String langCode) async {
    await _voice.speak(text, langCode: langCode);
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AgriColors.bgDark : const Color(0xFFF1F8F2),
      appBar: AppBar(
        backgroundColor: isDark ? AgriColors.cardDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.tr('ai_chat_title'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Online  •  Gemini AI',
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AgriColors.textMuted)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AgriColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                loc.currentLanguageInfo.flag,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            onPressed: () => _showLanguagePicker(loc),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _buildTypingIndicator();
                return _buildMessageBubble(_messages[i], loc, isDark);
              },
            ),
          ),
          _buildInputBar(loc, isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      ChatMessageModel msg, LocalizationService loc, bool isDark) {
    final isUser = msg.role == 'user';

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUser
                      ? AgriColors.primaryGreen
                      : isDark
                          ? AgriColors.cardDark
                          : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: isUser
                    ? Text(
                        msg.content,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, height: 1.4),
                      )
                    : MarkdownBody(
                        data: msg.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: isDark ? Colors.white : Colors.black87),
                          strong: TextStyle(
                              color: isDark
                                  ? AgriColors.accentLime
                                  : AgriColors.primaryGreen,
                              fontWeight: FontWeight.bold),
                          listBullet: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54),
                          code: TextStyle(
                            backgroundColor:
                                AgriColors.primaryGreen.withOpacity(0.1),
                            color: AgriColors.primaryGreen,
                            fontSize: 12,
                          ),
                        ),
                      ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
          ],
        ),
        if (!isUser) ...[
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      _speakMessage(msg.content, loc.currentLocale),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AgriColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.volume_up_rounded,
                            size: 14, color: AgriColors.primaryGreen),
                        SizedBox(width: 4),
                        Text(
                          'Listen',
                          style: TextStyle(
                              fontSize: 11,
                              color: AgriColors.primaryGreen,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(msg.timestamp),
                  style: const TextStyle(
                      fontSize: 10, color: AgriColors.textMuted),
                ),
              ],
            ),
          ),
        ],
        // Suggested followup chips
        if (!isUser && msg.followups != null && msg.followups!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: msg.followups!
                  .take(3)
                  .map((prompt) => GestureDetector(
                        onTap: () => _sendMessage(prompt),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AgriColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AgriColors.primaryGreen.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            prompt,
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: AgriColors.primaryGreen,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
        // Govt schemes tags
        if (!isUser &&
            msg.govtSchemes != null &&
            msg.govtSchemes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 12),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined,
                    size: 12, color: AgriColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Related schemes: ${msg.govtSchemes!.join(' • ')}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AgriColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 10),
      ],
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.06, end: 0);
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 6)
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => AnimatedBuilder(
                  animation: _waveController,
                  builder: (_, __) {
                    final phase = (i * 0.33);
                    final val =
                        ((_waveController.value + phase) % 1.0);
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8 + (val * 6),
                      decoration: BoxDecoration(
                        color: AgriColors.primaryGreen
                            .withOpacity(0.5 + val * 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(LocalizationService loc, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? AgriColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isListening)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AgriColors.alertCritical.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AgriColors.alertCritical.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (_, __) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color.lerp(AgriColors.alertCritical,
                            AgriColors.amberWarm, _waveController.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loc.tr('listening'),
                    style: const TextStyle(
                        color: AgriColors.alertCritical,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      await _voice.stopListening();
                      setState(() => _isListening = false);
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AgriColors.alertCritical, size: 20),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  decoration: InputDecoration(
                    hintText: loc.tr('tap_to_speak'),
                    hintStyle:
                        const TextStyle(color: AgriColors.textMuted),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AgriColors.bgDark
                        : AgriColors.bgLight,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Voice Mic Button
              GestureDetector(
                onTap: _isListening
                    ? () async {
                        await _voice.stopListening();
                        setState(() => _isListening = false);
                      }
                    : _startVoiceInput,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? AgriColors.alertCritical
                        : AgriColors.primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.stop_rounded
                        : Icons.mic_rounded,
                    color: _isListening
                        ? Colors.white
                        : AgriColors.primaryGreen,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send Button
              GestureDetector(
                onTap: () => _sendMessage(_inputController.text),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            AgriColors.primaryGreen.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(LocalizationService loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: LocalizationService.supportedLanguages.map((lang) {
            final isSelected = loc.currentLocale == lang.code;
            return GestureDetector(
              onTap: () {
                loc.setLocale(lang.code);
                Navigator.pop(context);
              },
              child: Chip(
                backgroundColor: isSelected
                    ? AgriColors.primaryGreen
                    : AgriColors.primaryGreen.withOpacity(0.08),
                label: Text(
                  '${lang.flag} ${lang.nativeName}',
                  style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AgriColors.primaryGreen),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
