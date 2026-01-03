import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ValueQuestion {
  final String id;
  final String question;
  String answer;

  ValueQuestion({
    required this.id,
    required this.question,
    this.answer = '',
  });

  factory ValueQuestion.fromJson(Map<String, dynamic> json) {
    return ValueQuestion(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
    };
  }
}

class LifeValue {
  final String id;
  final String title;
  final String description;
  final String iconName; // Store icon as string for JSON serialization
  int score; // 0 to 100 based on AI analysis of answers
  String? lastInsight; // Brief insight note from AI
  final List<ValueQuestion> questions;

  LifeValue({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    this.score = 0,
    this.lastInsight,
    required this.questions,
  });

  IconData get icon => _getIconFromName(iconName);

  static IconData _getIconFromName(String name) {
    switch (name) {
      case 'homeHeart':
        return MdiIcons.homeHeart;
      case 'heartOutline':
        return MdiIcons.heartOutline;
      case 'accountGroupOutline':
        return MdiIcons.accountGroupOutline;
      case 'briefcaseOutline':
        return MdiIcons.briefcaseOutline;
      case 'schoolOutline':
        return MdiIcons.schoolOutline;
      case 'controllerClassicOutline':
        return MdiIcons.controllerClassicOutline;
      case 'meditation':
        return MdiIcons.meditation;
      case 'handHeartOutline':
        return MdiIcons.handHeartOutline;
      case 'treeOutline':
        return MdiIcons.treeOutline;
      case 'runFast':
        return MdiIcons.runFast;
      default:
        return MdiIcons.helpCircleOutline;
    }
  }

  static String _mapCodePointToName(int codePoint) {
    // Map existing code points back to names for migration
    if (codePoint == MdiIcons.homeHeart.codePoint) return 'homeHeart';
    if (codePoint == MdiIcons.heartOutline.codePoint) return 'heartOutline';
    if (codePoint == MdiIcons.accountGroupOutline.codePoint)
      return 'accountGroupOutline';
    if (codePoint == MdiIcons.briefcaseOutline.codePoint)
      return 'briefcaseOutline';
    if (codePoint == MdiIcons.schoolOutline.codePoint) return 'schoolOutline';
    if (codePoint == MdiIcons.controllerClassicOutline.codePoint)
      return 'controllerClassicOutline';
    if (codePoint == MdiIcons.meditation.codePoint) return 'meditation';
    if (codePoint == MdiIcons.handHeartOutline.codePoint)
      return 'handHeartOutline';
    if (codePoint == MdiIcons.treeOutline.codePoint) return 'treeOutline';
    if (codePoint == MdiIcons.runFast.codePoint) return 'runFast';
    return 'helpCircleOutline';
  }

  factory LifeValue.fromJson(Map<String, dynamic> json) {
    String? iconName = json['iconName'] as String?;
    if (iconName == null && json['iconCodePoint'] != null) {
      iconName = _mapCodePointToName(json['iconCodePoint'] as int);
    }

    return LifeValue(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      iconName: iconName ?? 'helpCircleOutline',
      score: json['score'] as int? ?? 0,
      lastInsight: json['lastInsight'] as String?,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => ValueQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'iconName': iconName,
      'score': score,
      'lastInsight': lastInsight,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  // Static definition of the default values hierarchy
  static List<LifeValue> getDefaults() {
    return [
      LifeValue(
        id: 'family',
        title: 'Family',
        description: 'Roles, qualities, and relationships with relatives.',
        iconName: 'homeHeart',
        questions: [
          ValueQuestion(
              id: 'q1',
              question:
                  'What sort of brother/sister, son/daughter, father/mother (or other relative) do you want to be?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'What personal qualities would you like to bring to these relationships?'),
          ValueQuestion(
              id: 'q3',
              question:
                  'How would you treat others if you were the ‘ideal you’ in these relationships?'),
          ValueQuestion(
              id: 'q4',
              question:
                  'What sort of ongoing activities do you want to do with your relatives?'),
          ValueQuestion(
              id: 'q5',
              question: 'What sort of relationships do you want to build?'),
        ],
      ),
      LifeValue(
        id: 'partners',
        title: 'Partners',
        description:
            'Intimacy, shared qualities, and treatment of your partner.',
        iconName: 'heartOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question:
                  'What sort of partner would you like to be in an intimate relationship?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'What personal qualities would you like to develop within this relationship?'),
          ValueQuestion(
              id: 'q3',
              question:
                  'How would you treat your partner if you were the ‘ideal you’ in this relationship?'),
          ValueQuestion(
              id: 'q4',
              question: 'What sort of relationship do you want to build?'),
          ValueQuestion(
              id: 'q5',
              question:
                  'What sort of ongoing activities do you want to do with your partner?'),
        ],
      ),
      LifeValue(
        id: 'friendships',
        title: 'Friendships',
        description: 'Being a good friend and building social bonds.',
        iconName: 'accountGroupOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question: 'What does it mean to you to be a good friend?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'If you could be the ‘ideal you’, how would you behave toward your friends?'),
          ValueQuestion(
              id: 'q3',
              question:
                  'What personal qualities would you like to bring to these friendships?'),
          ValueQuestion(
              id: 'q4',
              question: 'What sort of friendships do you want to build?'),
          ValueQuestion(
              id: 'q5',
              question:
                  'What sort of ongoing activities do you want to do with your friends?'),
        ],
      ),
      LifeValue(
        id: 'work',
        title: 'Work',
        description: 'Professional conduct, relationships, and meaning.',
        iconName: 'briefcaseOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question:
                  'What sort of worker or employer would you like to be?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'What personal qualities would you like to bring to the workplace?'),
          ValueQuestion(
              id: 'q3',
              question:
                  'How would you treat your co-workers if you were the ‘ideal you’?'),
          ValueQuestion(
              id: 'q4',
              question:
                  'What sort of relationships do you want to build with your colleagues?'),
          ValueQuestion(
              id: 'q5',
              question:
                  'What sort of ongoing activities do you want to do with your colleagues?'),
          ValueQuestion(
              id: 'q6', question: 'What would make your work more meaningful?'),
        ],
      ),
      LifeValue(
        id: 'education',
        title: 'Education',
        description: 'Learning, skills, and intellectual growth.',
        iconName: 'schoolOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question:
                  'What do you value about learning, education or training?'),
          ValueQuestion(
              id: 'q2',
              question: 'What new skills or knowledge would you like to gain?'),
          ValueQuestion(
              id: 'q3',
              question: 'What further education or training appeals to you?'),
          ValueQuestion(
              id: 'q4',
              question: 'What sort of student/trainee would you like to be?'),
          ValueQuestion(
              id: 'q5',
              question:
                  'What personal qualities would you like to bring to your studies?'),
          ValueQuestion(
              id: 'q6',
              question:
                  'What sort of relationships would you like to build with other students?'),
        ],
      ),
      LifeValue(
        id: 'fun',
        title: 'Fun',
        description: 'Hobbies, relaxation, creativity, and leisure.',
        iconName: 'controllerClassicOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question:
                  'What sorts of hobbies, sports or leisure activities do you want to participate in?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'On an ongoing basis, how do you wish to relax and unwind?'),
          ValueQuestion(
              id: 'q3',
              question: 'On an ongoing basis, how do you wish to have fun?'),
          ValueQuestion(id: 'q4', question: 'How do you wish to be creative?'),
          ValueQuestion(
              id: 'q5',
              question: 'What sorts of new activities would you like to try?'),
          ValueQuestion(
              id: 'q6',
              question: 'What old activities would you like to take up again?'),
        ],
      ),
      LifeValue(
        id: 'spirituality',
        title: 'Spirituality',
        description: 'Inner life, faith, or philosophical connection.',
        iconName: 'meditation',
        questions: [
          ValueQuestion(
              id: 'q1',
              question: 'What is important to you in this area of life?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'What spiritual activities would you like to do on an ongoing basis?'),
        ],
      ),
      LifeValue(
        id: 'community',
        title: 'Community',
        description: 'Contribution, volunteering, and civic engagement.',
        iconName: 'handHeartOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question: 'How would you like to contribute to your community?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'What interest groups, charities or political parties would you like to support?'),
        ],
      ),
      LifeValue(
        id: 'nature',
        title: 'Nature',
        description: 'Environment, connection to earth, and surroundings.',
        iconName: 'treeOutline',
        questions: [
          ValueQuestion(
              id: 'q1',
              question:
                  'What aspects of nature would you like to connect with?'),
          ValueQuestion(
              id: 'q2',
              question:
                  'What environments would you like to spend more time in?'),
          ValueQuestion(
              id: 'q3',
              question:
                  'How would you like to care for the variety of environments around you?'),
          ValueQuestion(
              id: 'q4',
              question:
                  'What activities would you like to do that get you out into nature?'),
          ValueQuestion(
              id: 'q5',
              question:
                  'What activities would you like to do that alter your environment in creative ways?'),
        ],
      ),
      LifeValue(
        id: 'health',
        title: 'Health',
        description: 'Physical well-being, diet, sleep, and exercise.',
        iconName: 'runFast',
        questions: [
          ValueQuestion(
              id: 'q1', question: 'How would you like to care for your body?'),
          ValueQuestion(
              id: 'q2',
              question: 'What sort of physical health do you want to build?'),
          ValueQuestion(
              id: 'q3',
              question:
                  'What sort of ongoing activities do you want to do in terms of taking care of your body?'),
          ValueQuestion(
              id: 'q4',
              question:
                  'How do you want to look after your health with regard to sleep, diet, exercise?'),
        ],
      ),
    ];
  }
}
