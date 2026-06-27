import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:timezone/timezone.dart' as tz;

/// DateTime components for matching scheduled notifications.
/// 
/// Mirrors the enum from flutter_local_notifications_platform_interface.
enum DateTimeComponents {
  /// Matches the time (hour and minute) only.
  time,
  
  /// Matches the day of the month and time.
  dayOfMonthAndTime,
  
  /// Matches the date (day of week) and time.
  dateAndTime,
}

/// HarmonyOS NEXT implementation of [FlutterLocalNotificationsPlatform].
///
/// This plugin provides local notification functionality on HarmonyOS NEXT,
/// including instant notifications, scheduled notifications, and notification management.
///
/// ## Features
///
/// - ✅ Show instant notifications
/// - ✅ Schedule timed notifications
/// - ✅ Cancel individual notification
/// - ✅ Cancel all notifications
/// - ✅ Query pending notifications
/// - ✅ Request notification permissions
/// - ⚠️ Notification channels (not supported, no-op)
/// - ⚠️ Notification click callbacks (not supported in v0.1)
///
/// ## HarmonyOS API Mapping
///
/// - Instant notifications: `@ohos.notificationManager.publish()`
/// - Scheduled notifications: `@ohos.reminderAgentManager.publishReminder()`
/// - Permissions: `@ohos.notificationManager.requestEnableNotification()`
class FlutterLocalNotificationsOhos extends FlutterLocalNotificationsPlatform {
  /// Method channel for communication with the native layer.
  static const MethodChannel _channel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  /// Registers this class as the default instance of [FlutterLocalNotificationsPlatform].
  static void registerWith() {
    FlutterLocalNotificationsPlatform.instance = FlutterLocalNotificationsOhos();
  }

  /// Initializes the notification service.
  ///
  /// On HarmonyOS NEXT, this requests notification permissions.
  Future<bool?> initialize({
    dynamic settings,
  }) async {
    return await _channel.invokeMethod<bool>('initialize');
  }

  @override
  Future<void> show(int id, String? title, String? body,
      {String? payload}) async {
    await _channel.invokeMethod<void>('show', {
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
    });
  }

  /// Schedules a notification to be shown at the specified date and time.
  ///
  /// This is a HarmonyOS-specific extension that maps to
  /// `@ohos.reminderAgentManager.publishReminder()`.
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    // Convert TZDateTime to milliseconds since epoch
    final int scheduledMillis = scheduledDate.millisecondsSinceEpoch;

    await _channel.invokeMethod<void>('zonedSchedule', {
      'id': id,
      'title': title,
      'body': body,
      'scheduledDate': scheduledMillis,
      'payload': payload,
      'matchDateTimeComponents': matchDateTimeComponents?.index,
    });
  }

  @override
  Future<void> cancel(int id) async {
    await _channel.invokeMethod<void>('cancel', id);
  }

  @override
  Future<void> cancelAll() async {
    await _channel.invokeMethod<void>('cancelAll');
  }

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    final List<Map<dynamic, dynamic>>? result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'pendingNotificationRequests',
    );

    return result
            ?.map(
              (Map<dynamic, dynamic> item) => PendingNotificationRequest(
                item['id'] as int,
                item['title'] as String?,
                item['body'] as String?,
                item['payload'] as String?,
              ),
            )
            .toList() ??
        <PendingNotificationRequest>[];
  }

  /// Requests notification permissions.
  ///
  /// Returns `true` if permission was granted, `false` otherwise.
  Future<bool?> requestPermissions() async {
    return await _channel.invokeMethod<bool>('requestPermissions');
  }

  /// Creates a notification channel.
  ///
  /// **Note:** HarmonyOS NEXT does not support notification channels.
  /// This method is a no-op and always returns successfully.
  Future<void> createNotificationChannel({
    required String id,
    required String name,
    String? description,
    int? importance,
  }) async {
    // No-op on HarmonyOS NEXT
    await _channel.invokeMethod<void>('createNotificationChannel', {
      'id': id,
      'name': name,
      'description': description,
      'importance': importance,
    });
  }
}
