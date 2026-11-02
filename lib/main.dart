import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

void main() => runApp(const ShadowHackerApp());

class ShadowHackerApp extends StatelessWidget {
  const ShadowHackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SHADOWHACKER AI',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF080B12),
      colorScheme: const ColorScheme.dark(primary: Color(0xFF00E5FF), secondary: Color(0xFF8A5CFF)),
    ),
    home: const ChatPage(),
  );
}

class ChatMessage {
  final String role;
  final String text;
  ChatMessage(this.role, this.text);
  Map<String, dynamic> toJson() => {'role': role, 'content': text};
  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(j['role'] ?? 'assistant', j['content'] ?? '');
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Replace this with your deployed HTTPS backend URL ending in /chat.
  static const String serverUrl = 'https://YOUR-BACKEND-DOMAIN.example/chat';

  final input = TextEditingController();
  final scroll = ScrollController();
  final speech = stt.SpeechToText();
  final tts = FlutterTts();
  final List<ChatMessage> messages = [];
  String provider = 'gemini';
  bool busy = false, listening = false, speakReplies = true;
  String partial = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
    tts.setLanguage('hi-IN');
    tts.setSpeechRate(0.48);
  }

  Future<void> _loadHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('chat_history');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).map((e) => ChatMessage.fromJson(e)).toList();
      if (mounted) setState(() => messages.addAll(list));
    }
  }

  Future<void> _saveHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('chat_history', jsonEncode(messages.map((e) => e.toJson()).toList()));
  }

  Future<void> _listen() async {
    if (listening) {
      await speech.stop();
      if (mounted) setState(() => listening = false);
      return;
    }
    final available = await speech.initialize(
      onStatus: (s) { if (s == 'done' || s == 'notListening') { if (mounted) setState(() => listening = false); } },
      onError: (e) { if (mounted) { setState(() => listening = false); _notice('माइक/स्पीच समस्या: ${e.errorMsg}'); } },
    );
    if (!available) { _notice('इस फोन में Speech Recognition उपलब्ध नहीं है।'); return; }
    setState(() { listening = true; partial = ''; });
    await speech.listen(
      localeId: 'hi_IN',
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 4),
      onResult: (r) {
        setState(() {
          partial = r.recognizedWords;
          input.text = partial;
          input.selection = TextSelection.collapsed(offset: input.text.length);
        });
      },
    );
  }

  Future<void> _send() async {
    final text = input.text.trim();
    if (text.isEmpty || busy) return;
    if (listening) await speech.stop();
    setState(() {
      listening = false;
      messages.add(ChatMessage('user', text));
      input.clear();
      busy = true;
    });
    await _saveHistory();
    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'provider': provider,
          'messages': messages.map((m) => m.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 90));
      final data = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['error'] ?? 'Server error ${response.statusCode}');
      }
      final answer = (data['reply'] ?? '').toString();
      setState(() => messages.add(ChatMessage('assistant', answer)));
      await _saveHistory();
      if (speakReplies && answer.isNotEmpty) await tts.speak(answer);
    } catch (e) {
      setState(() => messages.add(ChatMessage('assistant', 'कनेक्शन में समस्या: $e')));
      await _saveHistory();
    } finally {
      if (mounted) setState(() => busy = false);
      _jumpDown();
    }
  }

  void _jumpDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _notice(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _clear() async {
    setState(() => messages.clear());
    final p = await SharedPreferences.getInstance();
    await p.remove('chat_history');
    await tts.stop();
  }

  @override
  void dispose() {
    input.dispose(); scroll.dispose(); speech.stop(); tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SHADOWHACKER AI', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          Text('PERSONAL VOICE ASSISTANT', style: TextStyle(fontSize: 10, color: Colors.cyanAccent)),
        ]),
        actions: [
          IconButton(tooltip: 'Clear chat', onPressed: _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(children: [
            const Text('AI MODEL  ', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ChoiceChip(label: const Text('Gemini'), selected: provider == 'gemini',
              onSelected: (_) => setState(() => provider = 'gemini')),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('OpenAI'), selected: provider == 'openai',
              onSelected: (_) => setState(() => provider = 'openai')),
            const Spacer(),
            const Text('आवाज़', style: TextStyle(fontSize: 12)),
            Switch(value: speakReplies, onChanged: (v) => setState(() => speakReplies = v)),
          ]),
        ),
        Expanded(child: messages.isEmpty
          ? const Center(child: Text('नमस्ते! मैं तुम्हारा Personal AI हूँ।\nमाइक दबाकर हिंदी में बात करो।', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.7)))
          : ListView.builder(controller: scroll, padding: const EdgeInsets.all(12), itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i]; final user = m.role == 'user';
                return Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .84),
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: user ? const Color(0xFF173A50) : const Color(0xFF171D2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: user ? Colors.cyan.withOpacity(.35) : Colors.white10),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user ? 'तुम' : 'SHADOWHACKER AI', style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5), Text(m.text),
                      if (!user) Align(alignment: Alignment.centerRight,
                        child: IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero,
                          icon: const Icon(Icons.volume_up, size: 18), onPressed: () => tts.speak(m.text))),
                    ]),
                  ));
              })),
        if (busy) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
        if (listening) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('सुन रहा हूँ... ${partial}', style: const TextStyle(color: Colors.cyanAccent))),
        SafeArea(top: false, child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Row(children: [
            IconButton(
              tooltip: listening ? 'Stop listening' : 'Speak',
              onPressed: busy ? null : _listen,
              iconSize: 30,
              color: listening ? Colors.redAccent : Colors.cyanAccent,
              icon: Icon(listening ? Icons.mic : Icons.mic_none),
            ),
            Expanded(child: TextField(
              controller: input, minLines: 1, maxLines: 4,
              decoration: InputDecoration(hintText: 'हिंदी में लिखो या माइक दबाओ...', filled: true,
                fillColor: const Color(0xFF171D2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 6),
            IconButton(onPressed: busy ? null : _send, icon: const Icon(Icons.send_rounded), color: Colors.cyanAccent),
          ]),
        )),
      ]),
    );
  }
}
