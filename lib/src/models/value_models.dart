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
  final int iconCodePoint; // Store icon as int for JSON serialization
  int score; // 0 to 100 based on AI analysis of answers
  final List<ValueQuestion> questions;

  LifeValue({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCodePoint,
    this.score = 0,
    required this.questions,
  });

  IconData get icon => IconData(iconCodePoint,
      fontFamily: 'Material Design Icons',
      fontPackage: 'material_design_icons_flutter');

  factory LifeValue.fromJson(Map<String, dynamic> json) {
    return LifeValue(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      iconCodePoint: json['iconCodePoint'] as int,
      score: json['score'] as int? ?? 0,
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
      'iconCodePoint': iconCodePoint,
      'score': score,
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
        iconCodePoint: MdiIcons.homeHeart.codePoint,
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
        iconCodePoint: MdiIcons.heartOutline.codePoint,
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
        iconCodePoint: MdiIcons.accountGroupOutline.codePoint,
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
        iconCodePoint: MdiIcons.briefcaseOutline.codePoint,
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
        iconCodePoint: MdiIcons.schoolOutline.codePoint,
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
        iconCodePoint: MdiIcons.controllerClassicOutline.codePoint,
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
        iconCodePoint: MdiIcons.meditation.codePoint,
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
        iconCodePoint: MdiIcons.handHeartOutline.codePoint,
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
        iconCodePoint: MdiIcons.treeOutline.codePoint,
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
        iconCodePoint: MdiIcons.runFast.codePoint,
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
