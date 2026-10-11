import 'package:spark_sales/features/call_logs/domain/call_record.dart';

class CallTypeMapper {
  const CallTypeMapper._();

  static const incoming = 1;
  static const outgoing = 2;
  static const missed = 3;
  static const voicemail = 4;
  static const rejected = 5;
  static const blocked = 6;
  static const answeredExternally = 7;

  static CallType? fromAndroid(int? type) {
    switch (type) {
      case incoming:
        return CallType.incoming;
      case outgoing:
        return CallType.outgoing;
      case missed:
        return CallType.missed;
      case rejected:
        return CallType.rejected;
      case blocked:
        return CallType.blocked;
      case voicemail:
      case answeredExternally:
      default:
        return null;
    }
  }
}
