import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/timetable.dart';
import 'file_service.dart';

class IOSWidgetService {
  static const channel = MethodChannel('yiclass/ios');
  static Future<void> sync(Timetable? timetable) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await channel.invokeMethod('updateWidget',
        timetable == null ? null : FileService.toMap(timetable));
  }
}
