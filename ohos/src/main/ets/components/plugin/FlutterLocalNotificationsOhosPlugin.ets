import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import notificationManager from '@ohos.notificationManager';
import reminderAgentManager from '@ohos.reminderAgentManager';

const TAG = 'FlutterLocalNotificationsOhos';
const CHANNEL_NAME = 'dexterous.com/flutter/local_notifications';

/**
 * HarmonyOS NEXT implementation of flutter_local_notifications plugin.
 * 
 * Provides local notification functionality using:
 * - @ohos.notificationManager for instant notifications
 * - @ohos.reminderAgentManager for scheduled/repeating notifications
 */
export default class FlutterLocalNotificationsOhosPlugin
  implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private reminderIds: Map<number, number> = new Map();

  static registerWith(registrar: FlutterPluginBinding): void {
    const instance = new FlutterLocalNotificationsOhosPlugin();
    const channel = new MethodChannel(
      CHANNEL_NAME,
      registrar.getMessenger()
    );
    channel.setMethodCallHandler(instance);
    instance.channel = channel;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'initialize':
        this.handleInitialize(result);
        break;
      case 'show':
        this.handleShow(call.arguments as Record<string, Object>, result);
        break;
      case 'zonedSchedule':
        this.handleZonedSchedule(call.arguments as Record<string, Object>, result);
        break;
      case 'cancel':
        this.handleCancel(call.arguments as number, result);
        break;
      case 'cancelAll':
        this.handleCancelAll(result);
        break;
      case 'pendingNotificationRequests':
        this.handlePendingNotificationRequests(result);
        break;
      case 'requestPermissions':
        this.handleRequestPermissions(result);
        break;
      case 'createNotificationChannel':
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  private handleInitialize(result: MethodResult): void {
    try {
      notificationManager.requestEnableNotification((err, data) => {
        if (err) {
          result.error('INIT_ERROR', 'Failed to initialize notifications', err.toString());
        } else {
          result.success(data === 0);
        }
      });
    } catch (error) {
      result.error('INIT_ERROR', 'Failed to initialize notifications', error?.toString() ?? 'Unknown error');
    }
  }

  private handleShow(args: Record<string, Object>, result: MethodResult): void {
    try {
      const id = args['id'] as number;
      const title = args['title'] as string;
      const body = args['body'] as string;
      const payload = args['payload'] as string;

      const request: notificationManager.NotificationRequest = {
        id: id,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: title,
            text: body,
            additionalText: payload,
          }
        }
      };

      notificationManager.publish(request, (err) => {
        if (err) {
          result.error('SHOW_ERROR', 'Failed to show notification', err.toString());
        } else {
          result.success(null);
        }
      });
    } catch (error) {
      result.error('SHOW_ERROR', 'Failed to show notification', error?.toString() ?? 'Unknown error');
    }
  }

  private handleZonedSchedule(args: Record<string, Object>, result: MethodResult): void {
    try {
      const id = args['id'] as number;
      const title = args['title'] as string;
      const body = args['body'] as string;
      const scheduledDate = args['scheduledDate'] as number;
      const payload = args['payload'] as string;
      const matchDateTimeComponents = args['matchDateTimeComponents'] as number;

      const now = Date.now();
      const delaySeconds = Math.max(0, Math.floor((scheduledDate - now) / 1000));

      const isRepeating = matchDateTimeComponents !== undefined && matchDateTimeComponents !== null;

      if (isRepeating) {
        const scheduledDateObj = new Date(scheduledDate);
        const reminder: reminderAgentManager.CalendarReminderRequest = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
          dateTime: {
            year: scheduledDateObj.getFullYear(),
            month: scheduledDateObj.getMonth() + 1,
            day: scheduledDateObj.getDate(),
            hour: scheduledDateObj.getHours(),
            minute: scheduledDateObj.getMinutes(),
          },
          repeatMonths: this.getRepeatMonths(matchDateTimeComponents),
          repeatYears: this.getRepeatYears(matchDateTimeComponents),
          title: title,
          body: body,
          expiredContent: body,
        };

        reminderAgentManager.publishReminder(reminder, (err, reminderId) => {
          if (err) {
            result.error('SCHEDULE_ERROR', 'Failed to schedule reminder', err.toString());
          } else {
            this.reminderIds.set(id, reminderId);
            result.success(null);
          }
        });
      } else {
        const reminder: reminderAgentManager.TimerReminderRequest = {
          reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
          triggerTimeInSeconds: delaySeconds,
          title: title,
          body: body,
          expiredContent: body,
        };

        reminderAgentManager.publishReminder(reminder, (err, reminderId) => {
          if (err) {
            result.error('SCHEDULE_ERROR', 'Failed to schedule reminder', err.toString());
          } else {
            this.reminderIds.set(id, reminderId);
            result.success(null);
          }
        });
      }
    } catch (error) {
      result.error('SCHEDULE_ERROR', 'Failed to schedule notification', error?.toString() ?? 'Unknown error');
    }
  }

  private handleCancel(id: number, result: MethodResult): void {
    try {
      notificationManager.cancel(id);

      const reminderId = this.reminderIds.get(id);
      if (reminderId !== undefined) {
        reminderAgentManager.cancelReminder(reminderId, (err) => {
          this.reminderIds.delete(id);
          result.success(null);
        });
      } else {
        result.success(null);
      }
    } catch (error) {
      result.error('CANCEL_ERROR', 'Failed to cancel notification', error?.toString() ?? 'Unknown error');
    }
  }

  private handleCancelAll(result: MethodResult): void {
    try {
      notificationManager.cancelAll();

      for (const [id, reminderId] of this.reminderIds.entries()) {
        reminderAgentManager.cancelReminder(reminderId, (err) => {
          // Ignore individual errors
        });
      }
      this.reminderIds.clear();

      result.success(null);
    } catch (error) {
      result.error('CANCEL_ALL_ERROR', 'Failed to cancel all notifications', error?.toString() ?? 'Unknown error');
    }
  }

  private handlePendingNotificationRequests(result: MethodResult): void {
    try {
      reminderAgentManager.getValidReminders((err, reminders) => {
        if (err) {
          result.error('PENDING_ERROR', 'Failed to get pending notifications', err.toString());
        } else {
          const pendingList: Array<Record<string, Object>> = [];
          for (const reminder of reminders) {
            let notificationId = 0;
            for (const [id, reminderId] of this.reminderIds.entries()) {
              if (reminderId === reminder.reminderId) {
                notificationId = id;
                break;
              }
            }

            pendingList.push({
              'id': notificationId,
              'title': reminder.title,
              'body': reminder.body,
              'payload': null,
            });
          }
          result.success(pendingList);
        }
      });
    } catch (error) {
      result.error('PENDING_ERROR', 'Failed to get pending notifications', error?.toString() ?? 'Unknown error');
    }
  }

  private handleRequestPermissions(result: MethodResult): void {
    try {
      notificationManager.requestEnableNotification((err, data) => {
        if (err) {
          result.error('PERMISSION_ERROR', 'Failed to request permissions', err.toString());
        } else {
          result.success(data === 0);
        }
      });
    } catch (error) {
      result.error('PERMISSION_ERROR', 'Failed to request permissions', error?.toString() ?? 'Unknown error');
    }
  }

  private getRepeatMonths(matchDateTimeComponents: number): number[] {
    if (matchDateTimeComponents === 1) {
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    }
    return [];
  }

  private getRepeatYears(matchDateTimeComponents: number): number[] {
    if (matchDateTimeComponents === 2) {
      const currentYear = new Date().getFullYear();
      const years: number[] = [];
      for (let i = 0; i < 10; i++) {
        years.push(currentYear + i);
      }
      return years;
    }
    return [];
  }
}
