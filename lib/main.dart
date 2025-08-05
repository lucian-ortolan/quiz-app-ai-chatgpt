// lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(const QuizAIApp());
}

class QuizAIApp extends StatelessWidget {
  const QuizAIApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiz AI',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctIndex: json['answer'] as int,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  QuizQuestion? _quiz;
  bool _isLoading = false;
  final List<String> _askedQuestions = []; // histórico de perguntas

  Future<void> _getQuestion() async {
    setState(() {
      _isLoading = true;
      _quiz = null;
    });
    try {
      final q = await fetchQuizQuestion(_askedQuestions);
      setState(() {
        _quiz = q;
        _askedQuestions.add(q.question);
      });
    } catch (e) {
      setState(() {
        _quiz = QuizQuestion(
          question: 'Erro ao carregar pergunta:\n$e',
          options: [],
          correctIndex: -1,
        );
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onOptionTap(int idx) {
  if (_quiz == null || _quiz!.correctIndex < 0) return;
  
  final chosenText   = _quiz!.options[idx];
  final correctText  = _quiz!.options[_quiz!.correctIndex];
  final isCorrect    = idx == _quiz!.correctIndex;
  final chosenNumber = idx + 1;
  final correctNumber= _quiz!.correctIndex + 1;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(isCorrect ? '🎉 Acertou!' : '❌ Errou'),
      content: Text(
        isCorrect
          ? 'Parabéns, a opção $chosenNumber – "$chosenText" está correta.'
          : 'Resposta correta: opção $correctNumber – "$correctText".',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _getQuestion();
          },
          child: const Text('Próxima'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const CircularProgressIndicator();
    } else if (_quiz == null) {
      body = ElevatedButton(
        onPressed: _getQuestion,
        child: const Text('Começar Quiz'),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _quiz!.question,
            style: const TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ..._quiz!.options.asMap().entries.map((entry) {
            final i = entry.key;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                onPressed: () => _onOptionTap(i),
                child: Text(text),
              ),
            );
          }).toList(),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz AI')),
      body: Center(child: body),
    );
  }
}

Future<QuizQuestion> fetchQuizQuestion(List<String> previous) async {
  const apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  final apiKey = dotenv.env['OPENROUTER_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('OpenRouter API key não definida');
  }

  // Informa ao LLM quais perguntas já foram feitas
  final historyNote = previous.isEmpty
      ? ''
      : 'Não repetir estas perguntas:\n' + previous.join('\n');

  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    },
    body: jsonEncode({
      'model': 'openai/gpt-3.5-turbo',
      'messages': [
        {
          'role': 'system',
          'content':
              'Você é um gerador de perguntas de quiz. Sempre responda unicamente '
              'em JSON com os campos: question (string), options (array de 4 strings), '
              'answer (índice inteiro de 0 a 3).',
        },
        {
          'role': 'user',
          'content':
              '$historyNote\nGere uma nova pergunta de quiz com 4 alternativas.',
        },
      ],
      'max_tokens': 200,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('API ${response.statusCode}: ${response.body}');
  }

  final utf8Body = utf8.decode(response.bodyBytes);
  final data = jsonDecode(utf8Body) as Map<String, dynamic>;

  final content = (data['choices'][0]['message']['content'] as String).trim();

  // Caso o próprio 'content' venha com escapes Unicode (\u00e1),
  // podemos forçar um segundo decode:
  final decodedContent = jsonDecode(jsonEncode(content)) as String;

  final jsonMap = jsonDecode(decodedContent) as Map<String, dynamic>;
  return QuizQuestion.fromJson(jsonMap);
}
