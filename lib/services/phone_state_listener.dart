import 'package:flutter/foundation.dart';
import 'package:phone_state/phone_state.dart';
import 'package:logger/logger.dart';

enum PhoneState {
  idle,
  ringing,
  inCall,
  unknown,
}

class PhoneStateListener extends ChangeNotifier {
  final Logger _logger = Logger();
  
  PhoneState _currentState = PhoneState.idle;
  DateTime? _callStartTime;
  bool _isListening = false;
  
  // Callbacks for state changes
  Function(PhoneState)? onStateChanged;
  Function()? onCallStarted;
  Function()? onCallEnded;

  PhoneState get currentState => _currentState;
  bool get isInCall => _currentState == PhoneState.inCall;
  bool get isListening => _isListening;
  DateTime? get callStartTime => _callStartTime;

  /// Initialize and start listening to phone state changes
  Future<void> startListening() async {
    if (_isListening) {
      _logger.w('Phone state listener is already listening');
      return;
    }

    try {
      _isListening = true;
      PhoneState.setPhoneStateListener(_handlePhoneStateChanged);
      _logger.i('Phone state listener started');
    } catch (e) {
      _logger.e('Error starting phone state listener: $e');
      _isListening = false;
    }
  }

  /// Stop listening to phone state changes
  Future<void> stopListening() async {
    try {
      _isListening = false;
      PhoneState.removePhoneStateListener();
      _logger.i('Phone state listener stopped');
    } catch (e) {
      _logger.e('Error stopping phone state listener: $e');
    }
  }

  /// Handle phone state change
  void _handlePhoneStateChanged(PhoneState phoneState) {
    final previousState = _currentState;

    // Map phone_state package PhoneState to our enum
    _currentState = _mapPhoneState(phoneState);

    _logger.i('Phone state changed: $previousState -> $_currentState');

    // Trigger callbacks
    if (_currentState != previousState) {
      onStateChanged?.call(_currentState);
      notifyListeners();

      if (_currentState == PhoneState.inCall) {
        _callStartTime = DateTime.now();
        onCallStarted?.call();
        _logger.i('[TEL] Call detected. Starting engine...');
      } else if (previousState == PhoneState.inCall && _currentState == PhoneState.idle) {
        final callDuration = DateTime.now().difference(_callStartTime ?? DateTime.now());
        _logger.i('[TEL] Call ended. Duration: ${callDuration.inSeconds}s');
        onCallEnded?.call();
        _callStartTime = null;
      }
    }
  }

  /// Map phone_state package PhoneState to our custom enum
  PhoneState _mapPhoneState(PhoneState phoneState) {
    switch (phoneState) {
      case PhoneState.CALL_STATE_IDLE:
        return PhoneState.idle;
      case PhoneState.CALL_STATE_RINGING:
        return PhoneState.ringing;
      case PhoneState.CALL_STATE_OFFHOOK:
        return PhoneState.inCall;
      default:
        return PhoneState.unknown;
    }
  }

  /// Get human-readable phone state description
  String getStateDescription() {
    switch (_currentState) {
      case PhoneState.idle:
        return 'Idle';
      case PhoneState.ringing:
        return 'Ringing';
      case PhoneState.inCall:
        return 'In Call';
      case PhoneState.unknown:
        return 'Unknown';
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
