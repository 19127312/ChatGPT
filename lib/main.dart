import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_openai/openai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'chat_message.dart';
import "package:speech_to_text/speech_to_text.dart" as stt;
import 'package:path_provider/path_provider.dart';

Future main() async {
  await dotenv.load(fileName: ".env");
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
final FlutterTts flutterTts = FlutterTts();

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final txtController = TextEditingController();
  final srlController = ScrollController();

  var msgs = <ChatMessage>[];

  late bool isLoading;
  late stt.SpeechToText _speech;
  String _textSpeech = "";
  bool isListening = false;
  bool isSwitched = false;
  bool isSpeaking = false;
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    isLoading = false;
    readChatMessagesFromFile().then((value) => {
          setState(() {
            msgs = value;
          })
        });

    String? apiKey = dotenv.env['API_KEY'];
    OpenAI.apiKey = apiKey!;
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
        actions: [
          Switch(
            value: isSwitched,
            onChanged: (value) {
              setState(() {
                isSwitched = value;
              });
            },
          )
        ],
        leading: IconButton(
          color: Color.fromRGBO(142, 142, 160, 1),
          icon: const Icon(Icons.clear),
          onPressed: () {
            setState(() {
              msgs = [];
            });
            writeChatMessagesToFile(msgs);
          },
        ),
        backgroundColor: const Color.fromARGB(247, 247, 248, 255),
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
                padding: EdgeInsets.only(bottom: 30),
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
                  voiceBtn(),
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
    // ignore: unused_local_variable
    List<ChatMessage> lastTenItems;
    if (msgs.length >= 6) {
      lastTenItems = msgs.sublist(msgs.length - 5, msgs.length);
    } else {
      lastTenItems = msgs.sublist(0, msgs.length);
    }
    final chatCompletion = await OpenAI.instance.chat.create(
      model: 'gpt-3.5-turbo',
      messages: [
        ...lastTenItems.map(
          (e) => OpenAIChatCompletionChoiceMessageModel(
            role: e.isUserMessage ? 'user' : 'assistant',
            content: e.text,
          ),
        ),
      ],
    );
    lastTenItems.add(ChatMessage(
      text: chatCompletion.choices.first.message.content,
      isUserMessage: false,
    ));
    writeChatMessagesToFile(lastTenItems);

    return chatCompletion.choices.first.message.content;
  }

  void writeChatMessagesToFile(List<ChatMessage> messages) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/chat_messages.json');
    final jsonStr = jsonEncode(messages.map((m) => m.toJson()).toList());
    await file.writeAsString(jsonStr);
  }

  Future<List<ChatMessage>> readChatMessagesFromFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/chat_messages.json');
    if (!await file.exists()) {
      return [];
    }
    final jsonStr = await file.readAsString();
    final jsonList = jsonDecode(jsonStr) as List<dynamic>;
    final messages =
        jsonList.map((json) => ChatMessage.fromJson(json)).toList();
    return messages;
  }

  ListView messageList() {
    return ListView.builder(
      controller: srlController,
      itemCount: msgs.length,
      itemBuilder: (context, index) {
        var message = msgs[index];
        return ChatMessageWidget(
          text: message.text,
          isUserMessage: message.isUserMessage,
          onSpeakBtn: () => {handleSpeak(message.text)},
        );
      },
    );
  }

  void handleSpeak(String text) {
    setState(() {
      isSpeaking = !isSpeaking;
    });
    if (isSpeaking) {
      stop();
    } else {
      speak(text);
    }
  }

  Widget voiceBtn() {
    return Container(
      color: answerBackgroundColor,
      child: IconButton(
        onPressed: () => onListen(),
        icon: Icon(
          isListening ? Icons.mic : Icons.mic_none,
          color: Colors.black,
        ),
      ),
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
            var input = txtController.text;
            setState(
              () {
                if (input != "") {
                  msgs.add(ChatMessage(
                    text: input,
                    isUserMessage: true,
                  ));
                  txtController.clear();
                  isLoading = true;
                  Future.delayed(const Duration(milliseconds: 50))
                      .then((_) => srllMessageList());
                }
              },
            );
            txtController.clear();
            if (input != "") {
              chatGPTResponse(input).then((value) {
                setState(() {
                  isLoading = false;
                  msgs.add(
                    ChatMessage(
                      text: value,
                      isUserMessage: false,
                    ),
                  );
                  if (isSwitched) {
                    speak(value);
                  }
                });
                Future.delayed(const Duration(milliseconds: 50))
                    .then((_) => srllMessageList());
              });
            }
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
      setState(() {
        isListening = false;
        _speech.stop();
      });
    }
  }
}

void speak(text) async {
  await flutterTts.setLanguage("en-US");
  await flutterTts.setPitch(1);
  await flutterTts.speak(text);
}

void stop() async {
  await flutterTts.stop();
}

class ChatMessageWidget extends StatelessWidget {
  ChatMessageWidget(
      {super.key,
      required this.text,
      required this.isUserMessage,
      required this.onSpeakBtn});

  final String text;
  final bool isUserMessage;
  final VoidCallback onSpeakBtn;

  @override
  Widget build(BuildContext context) {
    var iconButton = IconButton(
      icon: const Icon(
        Icons.speaker_notes,
        color: Color.fromRGBO(142, 142, 160, 1),
      ),
      onPressed: () {
        onSpeakBtn();
      },
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      padding: const EdgeInsets.all(8),
      color: isUserMessage == false ? answerBackgroundColor : backgroundColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          isUserMessage == false
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
