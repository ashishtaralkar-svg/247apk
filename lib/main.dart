import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// A fixed id for our repeating alarm so we can cancel it later.
const int kAlarmId = 1001;

/// A separate id for the one-shot "test buzz" alarm.
const int kTestAlarmId = 1002;

/// How long before the test buzz fires.
const Duration kTestDelay = Duration(seconds: 10);

// SharedPreferences keys.
const String _kRunningKey = 'running';
const String _kIntervalKey = 'interval_minutes';

/// Runs in a SEPARATE background isolate every time the alarm fires.
///
/// Must be a top-level or static function and annotated with
/// `@pragma('vm:entry-point')` so it survives release-mode tree-shaking.
@pragma('vm:entry-point')
Future<void> vibrateCallback() async {
  try {
    final bool hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    final bool hasAmplitude = await Vibration.hasAmplitudeControl() ?? false;
    if (hasAmplitude) {
      // amplitude 255 = strongest possible "hard" vibration.
      Vibration.vibrate(duration: 3000, amplitude: 255);
    } else {
      Vibration.vibrate(duration: 3000);
    }
  } catch (_) {
    // Never let the background isolate crash silently kill the alarm.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(const VibrateTimerApp());
}

class VibrateTimerApp extends StatelessWidget {
  const VibrateTimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibrate Timer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _running = false;
  int? _intervalMinutes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreState();
  }

  Future<void> _restoreState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _running = prefs.getBool(_kRunningKey) ?? false;
      _intervalMinutes = prefs.getInt(_kIntervalKey);
      _loading = false;
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRunningKey, _running);
    if (_intervalMinutes != null) {
      await prefs.setInt(_kIntervalKey, _intervalMinutes!);
    }
  }

  Future<void> _start(int minutes) async {
    // Cancel any stale alarm before scheduling a fresh one.
    await AndroidAlarmManager.cancel(kAlarmId);

    final bool scheduled = await AndroidAlarmManager.periodic(
      Duration(minutes: minutes),
      kAlarmId,
      vibrateCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );

    if (!mounted) return;

    if (!scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not schedule the alarm. Check exact-alarm permission.'),
        ),
      );
      return;
    }

    setState(() {
      _running = true;
      _intervalMinutes = minutes;
    });
    await _saveState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Started — buzzing every $minutes min.')),
    );
  }

  Future<void> _stop() async {
    await AndroidAlarmManager.cancel(kAlarmId);
    Vibration.cancel();

    setState(() {
      _running = false;
    });
    await _saveState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stopped.')),
    );
  }

  Future<void> _testBuzz() async {
    final bool scheduled = await AndroidAlarmManager.oneShot(
      kTestDelay,
      kTestAlarmId,
      vibrateCallback,
      exact: true,
      wakeup: true,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Test buzz in ${kTestDelay.inSeconds}s — you can lock the screen now.'
              : 'Could not schedule the test. Check exact-alarm permission.',
        ),
      ),
    );
  }

  Future<void> _onStartPressed() async {
    final int? minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _IntervalPicker(),
    );
    if (minutes != null && minutes > 0) {
      await _start(minutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Color buttonColor = _running ? Colors.red.shade600 : Colors.green.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vibrate Timer'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _running ? 'RUNNING' : 'STOPPED',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    letterSpacing: 2,
                    color: _running ? Colors.green : Colors.grey,
                  ),
            ),
            const SizedBox(height: 12),
            if (_running && _intervalMinutes != null)
              Text(
                'Buzzing every $_intervalMinutes min',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else
              Text(
                'Tap Start and choose an interval',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: _running ? _stop : _onStartPressed,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: buttonColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _running ? Icons.stop : Icons.play_arrow,
                        size: 64,
                        color: Colors.white,
                      ),
                      Text(
                        _running ? 'STOP' : 'START',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Each buzz lasts ~3 seconds and repeats at the chosen interval '
                'until you press Stop. Works in the background.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.vibration),
              label: Text('Test buzz (in ${kTestDelay.inSeconds}s)'),
              onPressed: _testBuzz,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet that lets the user pick 5 / 10 / 15 min or a custom interval.
class _IntervalPicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Vibrate every…',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            _PresetButton(minutes: 5),
            const SizedBox(height: 8),
            _PresetButton(minutes: 10),
            const SizedBox(height: 8),
            _PresetButton(minutes: 15),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Custom…'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                final custom = await _showCustomDialog(context);
                if (custom != null && context.mounted) {
                  Navigator.of(context).pop(custom);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _showCustomDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Custom interval'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Minutes',
              hintText: 'e.g. 7',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value != null && value > 0) {
                  Navigator.of(ctx).pop(value);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({required this.minutes});

  final int minutes;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: () => Navigator.of(context).pop(minutes),
      child: Text(
        '$minutes minutes',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
