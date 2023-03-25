// ignore: file_names
enum ChatMessageType { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUserMessage,
  });

  final String text;
  final bool isUserMessage;

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'isUserMessage': isUserMessage,
    };
  }

  ChatMessage fromJson(json) {
    return ChatMessage(
      text: json['text'],
      isUserMessage: json['isUserMessage'],
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text'] as String,
      isUserMessage: json['isUserMessage'] as bool,
    );
  }
}
