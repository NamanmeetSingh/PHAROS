import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/phone_state_listener.dart';
import 'services/audio_chunking_engine.dart';
import 'services/activity_log_service.dart';
import 'widgets/status_dashboard.dart';
import 'widgets/activity_log_widget.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize foreground service
  await _initializeBackgroundService();
  
  // Initialize notifications
  await _initializeNotifications();

  runApp(const PharosApp());
}

Future<void> _initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: false,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

Future<void> _initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // This is called when the foreground service starts
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationOptions(
      options: ForegroundNotificationOptions(
        id: 888,
        title: "PHAROS",
        content: "Actively monitoring call audio",
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

class PharosApp extends StatefulWidget {
  const PharosApp({Key? key}) : super(key: key);

  @override
  State<PharosApp> createState() => _PharosAppState();
}

class _PharosAppState extends State<PharosApp> {
  final _phoneStateListener = PhoneStateListener();
  final _activityLogService = ActivityLogService();
  late final AudioChunkingEngine _audioChunkingEngine;

  @override
  void initState() {
    super.initState();
    _audioChunkingEngine = AudioChunkingEngine(activityLog: _activityLogService);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request permissions
    await _requestPermissions();

    // Initialize audio engine
    await _audioChunkingEngine.initialize();

    // Set up phone state listener callbacks
    _phoneStateListener.onCallStarted = () async {
      _activityLogService.logTelemetry('Call detected. Starting engine...');
      await _audioChunkingEngine.start();
    };

    _phoneStateListener.onCallEnded = () async {
      _activityLogService.logTelemetry('Call ended. Stopping engine...');
      await _audioChunkingEngine.stop();
    };

    // Start listening to phone state changes
    await _phoneStateListener.startListening();
    _activityLogService.logInfo('PHAROS initialized successfully');
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.phone,
    ].request();

    if (statuses[Permission.microphone]?.isDenied ?? false) {
      _activityLogService.logError('Microphone permission denied');
    }

    if (statuses[Permission.phone]?.isDenied ?? false) {
      _activityLogService.logError('Phone state permission denied');
    }
  }

  @override
  void dispose() {
    _phoneStateListener.dispose();
    _audioChunkingEngine.dispose();
    _activityLogService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _phoneStateListener),
        ChangeNotifierProvider.value(value: _audioChunkingEngine),
        ChangeNotifierProvider.value(value: _activityLogService),
      ],
      child: MaterialApp(
        title: 'PHAROS',
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A0E27),
          primaryColor: const Color(0xFF00FF88),
          primarySwatch: Colors.green,
        ),
        home: const PharosHomePage(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class PharosHomePage extends StatefulWidget {
  const PharosHomePage({Key? key}) : super(key: key);

  @override
  State<PharosHomePage> createState() => _PharosHomePageState();
}

class _PharosHomePageState extends State<PharosHomePage> {
  bool _manualEngineOverride = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        elevation: 0,
        title: const Text(
          '█ PHAROS System',
          style: TextStyle(
            color: Color(0xFF00FF88),
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Consumer<ActivityLogService>(
                builder: (context, logService, _) {
                  return Text(
                    '${logService.logs.length}',
                    style: const TextStyle(
                      color: Color(0xFF00FF88),
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              // Status Dashboard
              const StatusDashboard(),
              const SizedBox(height: 20),

              // Manual Override Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E27),
                    border: Border.all(
                      color: const Color(0xFF0066FF),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MANUAL OVERRIDE',
                            style: TextStyle(
                              color: Color(0xFF0066FF),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Force start/stop engine',
                            style: TextStyle(
                              color: const Color(0xFF888888),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                      Consumer<AudioChunkingEngine>(
                        builder: (context, audioEngine, _) {
                          return Switch(
                            value: _manualEngineOverride,
                            onChanged: (value) async {
                              setState(() {
                                _manualEngineOverride = value;
                              });

                              if (value) {
                                await audioEngine.start();
                              } else {
                                await audioEngine.stop();
                              }
                            },
                            activeColor: const Color(0xFF00FF88),
                            inactiveThumbColor: const Color(0xFF444444),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Activity Log
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  height: 300,
                  child: const ActivityLogWidget(maxVisible: 30),
                ),
              ),

              const SizedBox(height: 20),

              // Debug Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E27),
                    border: Border.all(
                      color: const Color(0xFF444444),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Consumer2<PhoneStateListener, AudioChunkingEngine>(
                    builder: (context, phoneState, audioEngine, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Debug Info',
                            style: TextStyle(
                              color: const Color(0xFF888888),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DebugRow(
                            label: 'Phone State:',
                            value: phoneState.getStateDescription(),
                          ),
                          _DebugRow(
                            label: 'Engine State:',
                            value: audioEngine.getStateDescription(),
                          ),
                          _DebugRow(
                            label: 'Current dB:',
                            value:
                                '${audioEngine.currentDecibel.toStringAsFixed(1)} dB',
                          ),
                          _DebugRow(
                            label: 'Manual Override:',
                            value: _manualEngineOverride ? 'ON' : 'OFF',
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00FF88),
        child: const Icon(Icons.delete, color: Colors.black),
        onPressed: () {
          context.read<ActivityLogService>().clear();
        },
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  final String label;
  final String value;

  const _DebugRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00FF88),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
