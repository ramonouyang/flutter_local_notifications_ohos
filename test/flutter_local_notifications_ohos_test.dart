import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_local_notifications_ohos/flutter_local_notifications_ohos.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  const MethodChannel channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'initialize':
          return true;
        case 'show':
          return null;
        case 'zonedSchedule':
          return null;
        case 'cancel':
          return null;
        case 'cancelAll':
          return null;
        case 'pendingNotificationRequests':
          return <Map<dynamic, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'title': 'Test',
              'body': 'Body',
              'payload': 'payload',
            },
          ];
        case 'requestPermissions':
          return true;
        case 'createNotificationChannel':
          return null;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('FlutterLocalNotificationsOhos', () {
    test('registerWith sets the platform instance', () {
      FlutterLocalNotificationsOhos.registerWith();
      expect(FlutterLocalNotificationsPlatform.instance,
          isA<FlutterLocalNotificationsOhos>());
    });

    test('initialize invokes correct method', () async {
      final plugin = FlutterLocalNotificationsOhos();
      await plugin.initialize();

      expect(log, hasLength(1));
      expect(log.first.method, 'initialize');
    });

    test('show invokes correct method with arguments', () async {
      final plugin = FlutterLocalNotificationsOhos();
      await plugin.show(1, 'Title', 'Body', payload: 'payload');

      expect(log, hasLength(1));
      expect(log.first.method, 'show');
      expect(log.first.arguments, {
        'id': 1,
        'title': 'Title',
        'body': 'Body',
        'payload': 'payload',
      });
    });

    test('zonedSchedule invokes correct method with arguments', () async {
      final plugin = FlutterLocalNotificationsOhos();
      final scheduledDate = tz.TZDateTime(
        tz.getLocation('Asia/Shanghai'),
        2024,
        1,
        1,
        9,
        0,
      );

      await plugin.zonedSchedule(
        id: 2,
        title: 'Reminder',
        body: 'Time to take medicine',
        scheduledDate: scheduledDate,
        payload: 'reminder_payload',
      );

      expect(log, hasLength(1));
      expect(log.first.method, 'zonedSchedule');
      expect(log.first.arguments['id'], 2);
      expect(log.first.arguments['title'], 'Reminder');
      expect(log.first.arguments['body'], 'Time to take medicine');
      expect(log.first.arguments['payload'], 'reminder_payload');
      expect(log.first.arguments['scheduledDate'],
          scheduledDate.millisecondsSinceEpoch);
    });

    test('cancel invokes correct method with id', () async {
      final plugin = FlutterLocalNotificationsOhos();
      await plugin.cancel(3);

      expect(log, hasLength(1));
      expect(log.first.method, 'cancel');
      expect(log.first.arguments, 3);
    });

    test('cancelAll invokes correct method', () async {
      final plugin = FlutterLocalNotificationsOhos();
      await plugin.cancelAll();

      expect(log, hasLength(1));
      expect(log.first.method, 'cancelAll');
    });

    test('pendingNotificationRequests returns list', () async {
      final plugin = FlutterLocalNotificationsOhos();
      final result = await plugin.pendingNotificationRequests();

      expect(log, hasLength(1));
      expect(log.first.method, 'pendingNotificationRequests');
      expect(result, hasLength(1));
      expect(result.first.id, 1);
      expect(result.first.title, 'Test');
      expect(result.first.body, 'Body');
      expect(result.first.payload, 'payload');
    });

    test('requestPermissions invokes correct method', () async {
      final plugin = FlutterLocalNotificationsOhos();
      final result = await plugin.requestPermissions();

      expect(log, hasLength(1));
      expect(log.first.method, 'requestPermissions');
      expect(result, true);
    });

    test('createNotificationChannel invokes correct method', () async {
      final plugin = FlutterLocalNotificationsOhos();
      await plugin.createNotificationChannel(
        id: 'channel_id',
        name: 'Channel Name',
        description: 'Description',
        importance: 5,
      );

      expect(log, hasLength(1));
      expect(log.first.method, 'createNotificationChannel');
      expect(log.first.arguments['id'], 'channel_id');
      expect(log.first.arguments['name'], 'Channel Name');
    });

    test('show handles null title and body', () async {
      final plugin = FlutterLocalNotificationsOhos();
      await plugin.show(4, null, null);

      expect(log, hasLength(1));
      expect(log.first.method, 'show');
      expect(log.first.arguments['id'], 4);
      expect(log.first.arguments['title'], isNull);
      expect(log.first.arguments['body'], isNull);
    });
  });
}
