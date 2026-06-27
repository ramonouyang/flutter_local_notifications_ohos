import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications_ohos.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FlutterLocalNotificationsOhos _plugin = FlutterLocalNotificationsOhos();
  bool _initialized = false;
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    final result = await _plugin.initialize();
    setState(() {
      _initialized = true;
      _status = result == true ? 'Initialized (permission granted)' : 'Initialized (permission denied)';
    });
  }

  Future<void> _showNotification() async {
    await _plugin.show(
      id: 0,
      title: 'Instant Notification',
      body: 'This is an instant notification',
      payload: 'instant_payload',
    );
    _showSnackBar('Notification shown');
  }

  Future<void> _scheduleNotification() async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await _plugin.zonedSchedule(
      id: 1,
      title: 'Scheduled Notification',
      body: 'This notification was scheduled 5 seconds ago',
      scheduledDate: scheduledDate,
      payload: 'scheduled_payload',
    );
    _showSnackBar('Notification scheduled for 5 seconds from now');
  }

  Future<void> _cancelNotification() async {
    await _plugin.cancel(id: 1);
    _showSnackBar('Notification cancelled');
  }

  Future<void> _cancelAll() async {
    await _plugin.cancelAll();
    _showSnackBar('All notifications cancelled');
  }

  Future<void> _getPending() async {
    final pending = await _plugin.pendingNotificationRequests();
    _showSnackBar('${pending.length} pending notification(s)');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_local_notifications_ohos Example'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _status,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initialized ? _showNotification : null,
                child: const Text('Show Instant Notification'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initialized ? _scheduleNotification : null,
                child: const Text('Schedule Notification (5s)'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initialized ? _cancelNotification : null,
                child: const Text('Cancel Notification'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initialized ? _cancelAll : null,
                child: const Text('Cancel All'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _initialized ? _getPending : null,
                child: const Text('Get Pending Notifications'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
