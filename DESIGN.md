# flutter_local_notifications_ohos 设计文档

## 1. 概述

`flutter_local_notifications_ohos` 是 Flutter 插件 `flutter_local_notifications` 的 HarmonyOS NEXT 平台实现。该插件提供本地通知功能，包括即时通知、定时通知、重复通知、通知管理等。

## 2. 功能范围

### 2.1 MediPulse 使用的功能

| 功能 | 使用场景 | 优先级 |
|------|----------|--------|
| initialize() | 初始化通知服务、创建渠道、请求权限 | P0 |
| show() | 即时显示通知 | P0 |
| zonedSchedule() | 定时通知（复查/挂号提醒） | P0 |
| cancel() | 取消单个通知 | P0 |
| cancelAll() | 取消所有通知 | P0 |
| pendingNotificationRequests() | 获取待发送通知列表 | P1 |
| 通知权限请求 | 请求通知权限 | P0 |
| 通知渠道管理 | 创建/管理通知渠道 | P1 |
| 重复通知 | 每月/每年重复提醒 | P1 |

### 2.2 不支持的功能（v1.0）

| 功能 | 原因 | 替代方案 |
|------|------|----------|
| 通知点击回调 | 需要 Ability 生命周期管理 | 后续版本支持 |
| 富文本通知 | HarmonyOS API 限制 | 使用普通文本 |
| 大图标/自定义图标 | 资源格式不兼容 | 使用默认图标 |
| 通知分组 | 复杂度高 | 后续版本支持 |
| 全屏意图通知 | 需要特殊权限 | 不支持 |
| 进度条通知 | API 限制 | 不支持 |

## 3. 架构设计

### 3.1 分层架构

```
┌─────────────────────────────────────┐
│  Flutter App (Dart)                 │
│  flutter_local_notifications        │
└──────────────┬──────────────────────┘
               │ MethodChannel
               │ "dexterous.com/flutter/local_notifications"
               ▼
┌─────────────────────────────────────┐
│  Dart Plugin Layer                  │
│  FlutterLocalNotificationsOhos      │
│  - extends FlutterLocalNotificationsPlatform │
│  - initialize(), show(), zonedSchedule()    │
│  - cancel(), cancelAll()                    │
└──────────────┬──────────────────────┘
               │ MethodChannel
               ▼
┌─────────────────────────────────────┐
│  ArkTS Native Layer                 │
│  FlutterLocalNotificationsOhosPlugin.ets │
│  - handleInitialize()               │
│  - handleShow()                     │
│  - handleZonedSchedule()            │
│  - handleCancel() / handleCancelAll()│
│  - @ohos.notificationManager        │
│  - @ohos.reminderAgentManager       │
└─────────────────────────────────────┘
```

### 3.2 目录结构

```
flutter_local_notifications_ohos/
├── lib/
│   └── flutter_local_notifications_ohos.dart  # Dart 实现
├── ohos/
│   ├── index.ets                               # 插件入口
│   ├── src/main/ets/components/plugin/
│   │   └── FlutterLocalNotificationsOhosPlugin.ets
│   └── src/main/module.json5                   # 模块配置
├── test/
│   └── flutter_local_notifications_ohos_test.dart
├── example/
│   └── lib/main.dart                           # 示例应用
├── pubspec.yaml
├── README.md
└── LICENSE
```

## 4. API 映射

### 4.1 MethodChannel 接口

**Channel 名称**: `dexterous.com/flutter/local_notifications`

### 4.2 方法列表

| 方法名 | 参数 | 返回值 | 说明 |
|--------|------|--------|------|
| initialize | `{iOS:, android:}` | `bool` | 初始化通知服务 |
| show | `{id, title, body, payload}` | `void` | 即时显示通知 |
| zonedSchedule | `{id, title, body, scheduledDate, payload, matchDateTimeComponents}` | `void` | 定时通知 |
| cancel | `id` | `void` | 取消通知 |
| cancelAll | 无 | `void` | 取消所有通知 |
| pendingNotificationRequests | 无 | `List<Map>` | 获取待发送通知 |
| requestPermissions | `{alert, badge, sound}` | `bool` | 请求通知权限 |
| createNotificationChannel | `{id, name, description, importance}` | `void` | 创建通知渠道 |

### 4.3 HarmonyOS API 映射

#### 4.3.1 即时通知

```typescript
import { notificationManager } from '@kit.NotificationKit';

// 创建通知请求
const request: notificationManager.NotificationRequest = {
  id: notificationId,
  content: {
    notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
    normal: {
      title: title,
      text: body,
      additionalText: payload,
    }
  }
};

// 发布通知
notificationManager.publish(request);
```

#### 4.3.2 定时通知

```typescript
import { reminderAgentManager } from '@kit.ReminderKit';

// 创建定时提醒（倒计时）
const timerReminder: reminderAgentManager.TimerReminderRequest = {
  reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
  triggerTimeInSeconds: secondsUntilTrigger,
  title: title,
  body: body,
  expiredContent: body,
};

reminderAgentManager.publishReminder(timerReminder);
```

#### 4.3.3 重复通知

```typescript
// 日历提醒（支持重复）
const calendarReminder: reminderAgentManager.CalendarReminderRequest = {
  reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
  dateTime: {
    year: year,
    month: month,
    day: day,
    hour: hour,
    minute: minute,
  },
  repeatMonths: repeatMonthly ? [month] : [],
  repeatYears: repeatYearly ? [year] : [],
  title: title,
  body: body,
};

reminderAgentManager.publishReminder(calendarReminder);
```

#### 4.3.4 通知权限

```typescript
import { notificationManager } from '@kit.NotificationKit';

// 请求通知权限
const enabled = await notificationManager.requestEnableNotification();
// enabled: 0 = 已授权, -1 = 未授权
```

#### 4.3.5 通知渠道

HarmonyOS NEXT 没有 Android 的通知渠道概念。

**处理策略**: 
- `createNotificationChannel()` 方法空实现，返回成功
- 通知渠道 ID 仅用于内部标识，不影响实际行为

### 4.4 功能映射表

| Flutter API | HarmonyOS API | 说明 |
|-------------|---------------|------|
| initialize() | notificationManager.requestEnableNotification() | 请求权限 |
| show() | notificationManager.publish() | 即时通知 |
| zonedSchedule() (一次性) | reminderAgentManager.publishReminder(Timer) | 倒计时提醒 |
| zonedSchedule() (重复) | reminderAgentManager.publishReminder(Calendar) | 日历提醒 |
| cancel() | notificationManager.cancel() / reminderAgentManager.cancelReminder() | 取消通知 |
| cancelAll() | notificationManager.cancelAll() | 取消所有 |
| pendingNotificationRequests() | reminderAgentManager.getValidReminders() | 获取有效提醒 |
| createNotificationChannel() | 空实现 | 不支持 |
| requestPermissions() | notificationManager.requestEnableNotification() | 请求权限 |

## 5. 权限要求

### 5.1 必需权限

```json
// module.json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.NOTIFICATION_CONTROLLER",
        "reason": "用于发布本地通知"
      }
    ]
  }
}
```

### 5.2 权限说明

| 权限 | 用途 | 授权方式 |
|------|------|----------|
| ohos.permission.NOTIFICATION_CONTROLLER | 发布通知 | 用户授权 |

## 6. 错误处理

### 6.1 异常场景

| 场景 | 处理方式 |
|------|----------|
| 通知权限未授予 | 返回错误，提示用户授权 |
| 定时通知时间已过 | 忽略或立即显示 |
| 提醒数量超限 | HarmonyOS 限制 500 个，返回错误 |
| 取消不存在的通知 | 静默忽略 |

### 6.2 错误码

| 错误码 | 说明 |
|--------|------|
| PERMISSION_DENIED | 通知权限未授予 |
| INVALID_TIME | 定时时间无效 |
| LIMIT_EXCEEDED | 提醒数量超限 |

## 7. 测试策略

### 7.1 单元测试

- 测试 initialize() 初始化逻辑
- 测试 show() 通知参数构建
- 测试 zonedSchedule() 时间计算
- 测试 cancel() / cancelAll() 取消逻辑
- 测试权限请求返回值

### 7.2 集成测试

- 在示例应用中验证通知显示
- 验证定时通知触发
- 验证通知取消
- 验证权限请求流程

### 7.3 手动测试

- 在真机上验证通知显示效果
- 验证通知点击行为
- 验证后台通知行为

## 8. 已知限制

### 8.1 与 Android/iOS 的差异

| 差异 | 说明 | 影响 |
|------|------|------|
| 无通知渠道 | HarmonyOS 不支持 | 渠道配置被忽略 |
| 无通知点击回调 | 需要 Ability 生命周期 | 无法处理通知点击 |
| 定时通知 API 不同 | 使用 reminderAgentManager | 行为可能有差异 |
| 重复通知限制 | 仅支持月/年重复 | 周重复不支持 |
| 通知数量限制 | 最多 500 个提醒 | 超限会报错 |

### 8.2 后续优化

- [ ] 支持通知点击回调
- [ ] 支持富文本通知
- [ ] 支持通知分组
- [ ] 支持自定义图标
- [ ] 支持进度条通知

## 9. 发布计划

### 9.1 版本规划

- **v0.1.0**: 基础功能（initialize, show, cancel, cancelAll）
- **v0.2.0**: 定时通知（zonedSchedule, pendingNotificationRequests）
- **v0.3.0**: 重复通知（monthly, yearly）
- **v1.0.0**: 稳定版本，发布到 pub.dev

### 9.2 开源准备

- [x] 代码结构符合 Flutter 插件规范
- [x] README.md 包含使用说明
- [x] LICENSE 文件
- [x] example 应用
- [x] 单元测试覆盖
- [x] 已知限制文档化
- [ ] pub.dev 发布（待验证）

## 10. 参考资源

- [flutter_local_notifications 源码](https://github.com/MaikuB/flutter_local_notifications)
- [HarmonyOS notificationManager API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-notificationmanager-V5)
- [HarmonyOS reminderAgentManager API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-reminderAgentManager-V5)
- [Flutter 插件开发指南](https://docs.flutter.dev/development/platform-integration/plugin-api)

## 11. MediPulse 集成指南

### 11.1 pubspec.yaml 配置

```yaml
dependencies:
  flutter_local_notifications: ^22.0.1
  flutter_local_notifications_ohos:
    path: ../flutter_local_notifications_ohos  # 或 git 依赖
```

### 11.2 代码适配

现有代码无需修改，插件会自动注册为 HarmonyOS 平台实现：

```dart
// lib/services/notification_service.dart
// 现有代码保持不变
final plugin = FlutterLocalNotificationsPlugin();
await plugin.initialize(initSettings);
await plugin.zonedSchedule(id, title, body, scheduledDate, details);
```

### 11.3 注意事项

1. 通知渠道配置会被忽略（HarmonyOS 不支持）
2. 通知点击回调不会触发（后续版本支持）
3. 定时通知使用系统提醒服务，应用关闭后仍会触发
4. 需要在 module.json5 中声明通知权限
