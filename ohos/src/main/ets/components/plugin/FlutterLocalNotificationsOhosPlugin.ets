import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.ReminderKit';
import { FlutterPlugin, FlutterMethodCall, FlutterMethodResult } from '@ohos/flutter';

/**
 * HarmonyOS NEXT implementation of flutter_local_notifications plugin.
 * 
 * Provides local notification functionality using:
 * - @ohos.notificationManager for instant notifications
 * - @ohos.reminderAgentManager for scheduled/repeating notifications
 * 
 * Supported features:
 * - show(): Instant notification via notificationManager.publish()
 * - zonedSchedule(): Scheduled notification via reminderAgentManager
 * - cancel(): Cancel notification/reminder
 * - cancelAll(): Cancel all notifications and reminders
 * - pendingNotificationRequests(): List active reminders
 * - requestPermissions(): Request notification permission
 * - createNotificationChannel(): No-op (not supported on HarmonyOS)
 * 
 * Limitations:
 * - Notification click callbacks not supported (requires Ability lifecycle)
 * - Notification channels not supported (HarmonyOS concept difference)
 * - Rich text notifications not supported
 * - Custom icons not supported
 */
export default class FlutterLocalNotificationsOhosPlugin implements FlutterPlugin {
  private static readonly CHANNEL_NAME = 'dexterous.com/flutter/local_notifications';
  
  // Track scheduled reminders for cancellation
  private reminderIds: Map<number, number> = new Map(); // notificationId -> reminderId

  /**
   * Registers the plugin with the Flutter engine.
   */
  static registerWith(registry: any): void {
    const channel = registry.messenger(FlutterLocalNotificationsOhosPlugin.CHANNEL_NAME);
    const instance = new FlutterLocalNotificationsOhosPlugin();
    channel.setMethodCallHandler(instance.handleMethodCall.bind(instance));
  }

  /**
   * Handles method calls from the Dart side.
   */
  private handleMethodCall(call: FlutterMethodCall, result: FlutterMethodResult): void {
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
        // No-op on HarmonyOS NEXT
        result.success(null);
        break;
      default:
        result.notImplemented();
        break;
    }
  }

  /**
   * Initializes the notification service.
   * Requests notification permissions on HarmonyOS NEXT.
   */
  private handleInitialize(result: FlutterMethodResult): void {
    try {
      notificationManager.requestEnableNotification((err, data) => {
        if (err) {
          result.error('INIT_ERROR', 'Failed to initialize notifications', err.toString());
        } else {
          // data: 0 = enabled, -1 = disabled
          result.success(data === 0);
        }
      });
    } catch (error) {
      result.error('INIT_ERROR', 'Failed to initialize notifications', error?.toString() ?? 'Unknown error');
    }
  }

  /**
   * Shows an instant notification.
   * Uses notificationManager.publish() API.
   */
  private handleShow(args: Record<string, Object>, result: FlutterMethodResult): void {
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

  /**
   * Schedules a notification at a specific time.
   * Uses reminderAgentManager for scheduled notifications.
   */
  private handleZonedSchedule(args: Record<string, Object>, result: FlutterMethodResult): void {
    try {
      const id = args['id'] as number;
      const title = args['title'] as string;
      const body = args['body'] as string;
      const scheduledDate = args['scheduledDate'] as number; // milliseconds
      const payload = args['payload'] as string;
      const matchDateTimeComponents = args['matchDateTimeComponents'] as number;

      const now = Date.now();
      const delaySeconds = Math.max(0, Math.floor((scheduledDate - now) / 1000));

      // Check if this is a repeating notification
      const isRepeating = matchDateTimeComponents !== undefined && matchDateTimeComponents !== null;

      if (isRepeating) {
        // Use calendar reminder for repeating notifications
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
        // Use timer reminder for one-time notifications
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

  /**
   * Cancels a specific notification.
   * Tries both notificationManager and reminderAgentManager.
   */
  private handleCancel(id: number, result: FlutterMethodResult): void {
    try {
      // Try to cancel as notification
      notificationManager.cancel(id);

      // Try to cancel as reminder
      const reminderId = this.reminderIds.get(id);
      if (reminderId !== undefined) {
        reminderAgentManager.cancelReminder(reminderId, (err) => {
          this.reminderIds.delete(id);
          if (err) {
            // Ignore error, notification might have already been cancelled
          }
          result.success(null);
        });
      } else {
        result.success(null);
      }
    } catch (error) {
      result.error('CANCEL_ERROR', 'Failed to cancel notification', error?.toString() ?? 'Unknown error');
    }
  }

  /**
   * Cancels all notifications and reminders.
   */
  private handleCancelAll(result: FlutterMethodResult): void {
    try {
      // Cancel all notifications
      notificationManager.cancelAll();

      // Cancel all reminders
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

  /**
   * Returns list of pending notification requests.
   * Uses reminderAgentManager.getValidReminders().
   */
  private handlePendingNotificationRequests(result: FlutterMethodResult): void {
    try {
      reminderAgentManager.getValidReminders((err, reminders) => {
        if (err) {
          result.error('PENDING_ERROR', 'Failed to get pending notifications', err.toString());
        } else {
          const pendingList: Array<Record<string, Object>> = [];
          for (const reminder of reminders) {
            // Map reminder back to notification ID
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

  /**
   * Requests notification permissions.
   */
  private handleRequestPermissions(result: FlutterMethodResult): void {
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

  /**
   * Gets repeat months based on DateTimeComponents.
   */
  private getRepeatMonths(matchDateTimeComponents: number): number[] {
    // DateTimeComponents.dayOfMonthAndTime = 1 (monthly)
    // DateTimeComponents.dateAndTime = 2 (yearly)
    if (matchDateTimeComponents === 1) {
      // Monthly: repeat every month
      return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    }
    return [];
  }

  /**
   * Gets repeat years based on DateTimeComponents.
   */
  private getRepeatYears(matchDateTimeComponents: number): number[] {
    // DateTimeComponents.dateAndTime = 2 (yearly)
    if (matchDateTimeComponents === 2) {
      // Yearly: repeat every year for next 10 years
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
