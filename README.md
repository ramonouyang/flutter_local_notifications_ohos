# flutter_local_notifications_ohos

[![pub package](https://img.shields.io/pub/v/flutter_local_notifications_ohos.svg)](https://pub.dev/packages/flutter_local_notifications_ohos)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

HarmonyOS NEXT implementation of Flutter's [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) plugin.

## Features

- ✅ Show instant notifications
- ✅ Schedule timed notifications (one-time)
- ✅ Schedule repeating notifications (monthly/yearly)
- ✅ Cancel individual notifications
- ✅ Cancel all notifications
- ✅ Query pending notifications
- ✅ Request notification permissions
- ⚠️ Notification channels (not supported, no-op)
- ⚠️ Notification click callbacks (not supported in v0.1)

## Requirements

- HarmonyOS NEXT (API 12+)
- Flutter for HarmonyOS (3.24.0+)
- DevEco Studio 5.0+

## Installation

```yaml
dependencies:
  flutter_local_notifications: ^22.0.0
  flutter_local_notifications_ohos:
    git:
      url: https://github.com/ramonouyang/flutter_local_notifications_ohos.git
      ref: main
```

## Usage

The plugin implements `FlutterLocalNotificationsPlatform`, so it works transparently with the `flutter_local_notifications` API:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final plugin = FlutterLocalNotificationsPlugin();

// Initialize
await plugin.initialize(
  InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  ),
);

// Show instant notification
await plugin.show(
  0,
  'Title',
  'Body',
);

// Schedule notification
await plugin.zonedSchedule(
  1,
  'Reminder',
  'Time to take your medicine',
  scheduledDate,
  NotificationDetails(
    android: AndroidNotificationDetails(
      'channel_id',
      'channel_name',
    ),
  ),
);

// Cancel notification
await plugin.cancel(1);

// Cancel all notifications
await plugin.cancelAll();
```

## Architecture

```
flutter_local_notifications_ohos/
├── lib/
│   └── flutter_local_notifications_ohos.dart           # Dart implementation
├── ohos/
│   └── src/main/ets/components/plugin/
│       └── FlutterLocalNotificationsOhosPlugin.ets      # ArkTS native layer
└── example/
    └── lib/main.dart                                    # Example app
```

### HarmonyOS API Mapping

| Flutter API | HarmonyOS API | Notes |
|-------------|---------------|-------|
| initialize() | notificationManager.requestEnableNotification() | Request permission |
| show() | notificationManager.publish() | Instant notification |
| zonedSchedule() (one-time) | reminderAgentManager.publishReminder(Timer) | Timer reminder |
| zonedSchedule() (repeating) | reminderAgentManager.publishReminder(Calendar) | Calendar reminder |
| cancel() | notificationManager.cancel() + reminderAgentManager.cancelReminder() | Cancel both |
| cancelAll() | notificationManager.cancelAll() + reminderAgentManager.cancelReminder() | Cancel all |
| pendingNotificationRequests() | reminderAgentManager.getValidReminders() | List reminders |
| createNotificationChannel() | No-op | Not supported |

## Platform-Specific Notes

### Notification Channels

HarmonyOS NEXT does not support notification channels like Android. The `createNotificationChannel()` method is a no-op and always succeeds.

### Notification Click Callbacks

Notification click callbacks are not supported in v0.1. This requires Ability lifecycle management which will be added in a future version.

### Scheduled Notifications

Scheduled notifications use `@ohos.reminderAgentManager` which has a limit of 500 active reminders per app.

### Repeating Notifications

Repeating notifications support:
- Monthly: `DateTimeComponents.dayOfMonthAndTime`
- Yearly: `DateTimeComponents.dateAndTime`

Weekly repetition is not supported.

## Permissions

The plugin requires the `ohos.permission.NOTIFICATION_CONTROLLER` permission, which is declared in the module.json5.

## Known Limitations

1. **No notification click callbacks** - Requires Ability lifecycle management
2. **No notification channels** - HarmonyOS concept difference
3. **No rich text notifications** - API limitation
4. **No custom icons** - Resource format incompatibility
5. **500 reminder limit** - HarmonyOS system limit
6. **No weekly repetition** - reminderAgentManager limitation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
