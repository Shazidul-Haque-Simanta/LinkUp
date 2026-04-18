import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:project_v2/core/config/app_config.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show File; // Add for non-web file usage if needed, but we'll use bytes
import 'package:flutter/foundation.dart' show kIsWeb;

class AiTutorScreen extends StatefulWidget {
  const AiTutorScreen({super.key});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController(text: AppConfig.geminiApiKey);
  final ScrollController _scrollController = ScrollController();
  final List<Content> _chatHistory = [];
  bool _isLoading = false;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  late GenerativeModel _model;
  late ChatSession _chat;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
    );
    _chat = _model.startChat();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _chatHistory.add(Content.text(message));
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final List<Part> parts = [TextPart(message)];
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        parts.add(DataPart('image/jpeg', bytes));
      }

      final response = await _chat.sendMessage(Content.multi(parts));
      setState(() {
        _selectedImage = null; // Clear image after sending
        if (response.text != null) {
          _chatHistory.add(Content.model([TextPart(response.text!)]));
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI Tutor', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatHistory.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      final content = _chatHistory[index];
                      final isUser = content.role == 'user';
                      return _buildChatBubble(content, isUser);
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildLoadingIndicator(),
            ),
          if (_selectedImage != null) _buildImagePreview(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      child: Row(
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: kIsWeb
                    ? Image.network(_selectedImage!.path, height: 60, width: 60, fit: BoxFit.cover)
                    : Image.file(File(_selectedImage!.path), height: 60, width: 60, fit: BoxFit.cover),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: IconButton(
                  icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
                  onPressed: () => setState(() => _selectedImage = null),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Text('Image selected for analysis', style: TextStyle(fontSize: 12)),
        ],
      ),
    ).animate().slideY(begin: 0.1).fadeIn();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 80, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text(
            'Ask me anything about your studies!',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Example: "Help me summarize my Calculus notes" or "How to solve quadratic equations?"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  Widget _buildChatBubble(Content content, bool isUser) {
    final theme = Theme.of(context);
    final text = content.parts.whereType<TextPart>().map((e) => e.text).join();
    final hasImage = content.parts.any((p) => p is DataPart);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser
              ? null
              : Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  (content.parts.firstWhere((p) => p is DataPart) as DataPart).bytes,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (isUser)
              Text(
                text,
                style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w500),
              )
            else
              MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(color: theme.colorScheme.onSurface, height: 1.5, fontSize: 14),
                  code: TextStyle(
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  codeblockPadding: const EdgeInsets.all(16),
                  h1: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  h2: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                  listBullet: TextStyle(color: theme.colorScheme.primary),
                ),
              ),
          ],
        ),
      ).animate().scale(
            begin: const Offset(0.95, 0.95),
            duration: 300.ms,
            curve: Curves.easeOutBack,
          ).fadeIn(duration: 400.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildLoadingIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(width: 8),
        Text(
          'Tutor is thinking...',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add_photo_alternate_outlined, color: theme.colorScheme.primary),
              onPressed: _pickImage,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type your question...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.send, size: 18, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Paste your Gemini API Key here if it is not working:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _model = GenerativeModel(
                  model: AppConfig.geminiModel,
                  apiKey: _apiKeyController.text.trim(),
                );
                _chat = _model.startChat();
                _chatHistory.clear();
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API Key updated for this session!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
