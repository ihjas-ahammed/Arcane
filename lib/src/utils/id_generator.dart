import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();

  static String generateMainTaskId() => 'mt_${DateTime.now().millisecondsSinceEpoch}';
  
  static String generateSubTaskId() => 'sub_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
  
  static String generateCheckpointId() => 'ssub_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
  
  static String generateSessionId() => 'sess_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';
}