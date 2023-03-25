// ignore: file_names
enum ChatMessageType { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUserMessage,
  });

  final String text;
  final bool isUserMessage;
}
