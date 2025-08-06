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

enum DifficultyLevel { facil, medio, avancado }

extension DifficultyLevelExt on DifficultyLevel {
  String get label {
    switch (this) {
      case DifficultyLevel.facil:
        return 'Fácil';
      case DifficultyLevel.medio:
        return 'Médio';
      case DifficultyLevel.avancado:
        return 'Avançado';
    }
  }

  String get promptText {
    switch (this) {
      case DifficultyLevel.facil:
        return 'fácil';
      case DifficultyLevel.medio:
        return 'médio';
      case DifficultyLevel.avancado:
        return 'avançado';
    }
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
  DifficultyLevel? _selectedLevel;

  final Map<DifficultyLevel, List<String>> _askedPerLevel = {
    DifficultyLevel.facil: [],
    DifficultyLevel.medio: [],
    DifficultyLevel.avancado: [],
  };

  final Map<DifficultyLevel, int> _acertos = {
    DifficultyLevel.facil: 0,
    DifficultyLevel.medio: 0,
    DifficultyLevel.avancado: 0,
  };

  final Map<DifficultyLevel, int> _erros = {
    DifficultyLevel.facil: 0,
    DifficultyLevel.medio: 0,
    DifficultyLevel.avancado: 0,
  };

  Future<void> _getQuestion() async {
    if (_selectedLevel == null) return;

    setState(() {
      _isLoading = true;
      _quiz = null;
    });

    try {
      final previous = _askedPerLevel[_selectedLevel!]!;
      const int maxTentativas = 10;
      int tentativas = 0;
      QuizQuestion? novaPergunta;

      while (tentativas < maxTentativas) {
        final q = await fetchQuizQuestion(previous, _selectedLevel!);
        if (!previous.contains(q.question)) {
          novaPergunta = q;
          break;
        }
        tentativas++;
      }

      if (novaPergunta == null) {
        throw Exception('Não foi possível obter uma pergunta nova após $maxTentativas tentativas.');
      }

      setState(() {
        _quiz = novaPergunta;
        previous.add(novaPergunta!.question);
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
    if (_quiz == null || _quiz!.correctIndex < 0 || _selectedLevel == null) return;

    final chosenText = _quiz!.options[idx];
    final correctText = _quiz!.options[_quiz!.correctIndex];
    final isCorrect = idx == _quiz!.correctIndex;
    final chosenNumber = idx + 1;
    final correctNumber = _quiz!.correctIndex + 1;

    setState(() {
      if (isCorrect) {
        _acertos[_selectedLevel!] = _acertos[_selectedLevel!]! + 1;
      } else {
        _erros[_selectedLevel!] = _erros[_selectedLevel!]! + 1;
      }
    });

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

    if (_selectedLevel == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: DifficultyLevel.values.map((level) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ElevatedButton(
              onPressed: () {
                setState(() => _selectedLevel = level);
                _getQuestion();
              },
              child: Text(level.label),
            ),
          );
        }).toList(),
      );
    } else if (_isLoading) {
      body = const CircularProgressIndicator();
    } else if (_quiz == null) {
      body = ElevatedButton(
        onPressed: _getQuestion,
        child: const Text('Nova Pergunta'),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nível: ${_selectedLevel!.label}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            '✅ Acertos: ${_acertos[_selectedLevel!]}   ❌ Erros: ${_erros[_selectedLevel!]}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
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
      appBar: AppBar(
        title: const Text('Quiz AI'),
        actions: _selectedLevel != null
            ? [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Mudar Nível',
                  onPressed: () {
                    setState(() {
                      _selectedLevel = null;
                      _quiz = null;
                    });
                  },
                )
              ]
            : null,
      ),
      body: Center(child: body),
    );
  }
}

Future<QuizQuestion> fetchQuizQuestion(
    List<String> previous, DifficultyLevel nivel) async {
  const apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
  final apiKey = dotenv.env['OPENROUTER_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    throw Exception('OpenRouter API key não definida');
  }

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
              'Gere uma pergunta de quiz de nível ${nivel.promptText} com 4 alternativas.\n'
              '$historyNote',
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
  final decodedContent = jsonDecode(jsonEncode(content)) as String;
  final jsonMap = jsonDecode(decodedContent) as Map<String, dynamic>;

  return QuizQuestion.fromJson(jsonMap);
}
