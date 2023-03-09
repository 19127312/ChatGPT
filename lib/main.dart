import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'chat_message.dart';
import 'package:avatar_glow/avatar_glow.dart';
import "package:speech_to_text/speech_to_text.dart" as stt;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ChatPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

const backgroundColor = Color.fromARGB(255, 255, 255, 255);
const answerBackgroundColor = Color.fromARGB(247, 247, 248, 255);

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final txtController = TextEditingController();
  final srlController = ScrollController();

  final List<ChatMessage> msgs = [];

  late bool isLoading;
  late stt.SpeechToText _speech;
  String _textSpeech = "";
  bool isListening = false;
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
        title: const Center(
          child: Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Voice Chat GPT",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        backgroundColor: const Color.fromARGB(247, 247, 248, 255),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: AvatarGlow(
          animate: isListening,
          glowColor: Colors.blue,
          endRadius: 75.0,
          duration: const Duration(milliseconds: 2000),
          repeatPauseDuration: const Duration(milliseconds: 100),
          repeat: true,
          child: FloatingActionButton(
            onPressed: () => onListen(),
            backgroundColor: Colors.blue,
            child: Icon(isListening ? Icons.mic : Icons.mic_none),
          ),
        ),
      ),
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messageList(),
            ),
            Visibility(
              visible: isLoading,
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(
                  color: Colors.black,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  textInput(),
                  buttonSubmit(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> chatGPTResponse(String prompt) async {
    const apiKey = "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";

    var url = Uri.https("api.openai.com", "/v1/completions");
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        "Authorization": "Bearer $apiKey"
      },
      body: json.encode({
        "model": "text-davinci-003",
        "prompt": prompt,
        'temperature': 0.5,
        'max_tokens': 100,
        'top_p': 1,
        'frequency_penalty': 0.0,
        'presence_penalty': 0.0,
      }),
    );

    // Do something with the response
    Map<String, dynamic> newresponse = jsonDecode(response.body);

    return newresponse['choices'][0]['text'];
  }

  ListView messageList() {
    return ListView.builder(
      controller: srlController,
      itemCount: msgs.length,
      itemBuilder: (context, index) {
        var message = msgs[index];
        return ChatMessageWidget(
          text: message.text,
          chatMessageType: message.chatMessageType,
        );
      },
    );
  }

  Widget buttonSubmit() {
    return Visibility(
      visible: !isLoading,
      child: Container(
        color: answerBackgroundColor,
        child: IconButton(
          icon: const Icon(
            Icons.send_rounded,
            color: Color.fromRGBO(142, 142, 160, 1),
          ),
          onPressed: () async {
            setState(
              () {
                msgs.add(
                  ChatMessage(
                    text: txtController.text,
                    chatMessageType: ChatMessageType.question,
                  ),
                );
                isLoading = true;
                Future.delayed(const Duration(milliseconds: 50))
                    .then((_) => srllMessageList());
              },
            );
            var input = txtController.text;
            txtController.clear();

            chatGPTResponse(input).then((value) {
              setState(() {
                isLoading = false;
                msgs.add(
                  ChatMessage(
                    text: value,
                    chatMessageType: ChatMessageType.answer,
                  ),
                );
              });
              Future.delayed(const Duration(milliseconds: 50))
                  .then((_) => srllMessageList());
            });
          },
        ),
      ),
    );
  }

  Expanded textInput() {
    return Expanded(
      child: TextField(
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(color: Colors.black),
        controller: txtController,
        decoration: const InputDecoration(
          fillColor: answerBackgroundColor,
          filled: true,
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  void srllMessageList() {
    srlController.animateTo(
      srlController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void onListen() async {
    if (!isListening) {
      print("start");
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _textSpeech = val.recognizedWords;
            txtController.text = _textSpeech;
          }),
        );
      }
    } else {
      print("end");

      setState(() {
        isListening = false;
        _speech.stop();
      });
    }
  }
}

class ChatMessageWidget extends StatelessWidget {
  ChatMessageWidget(
      {super.key, required this.text, required this.chatMessageType});

  final String text;
  final ChatMessageType chatMessageType;
  final FlutterTts flutterTts = FlutterTts();

  @override
  Widget build(BuildContext context) {
    var iconButton = IconButton(
      icon: const Icon(
        Icons.send_rounded,
        color: Color.fromRGBO(142, 142, 160, 1),
      ),
      onPressed: () async {
        print(text);

        await flutterTts.setLanguage("en-US");
        await flutterTts.setPitch(1);
        await flutterTts.speak(text);
      },
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      padding: const EdgeInsets.all(8),
      color: chatMessageType == ChatMessageType.answer
          ? answerBackgroundColor
          : backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          chatMessageType == ChatMessageType.answer
              ? Container(
                  margin: const EdgeInsets.only(right: 16.0, left: 8.0),
                  child: CircleAvatar(
                    child: Image.asset(
                      'assets/icon.png',
                    ),
                  ),
                )
              : Container(
                  margin: const EdgeInsets.only(right: 16.0, left: 8.0),
                  child: const CircleAvatar(
                    child: Icon(
                      Icons.person,
                    ),
                  ),
                ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.black),
                  ),
                ),
                iconButton
              ],
            ),
          ),
        ],
      ),
    );
  }
}
