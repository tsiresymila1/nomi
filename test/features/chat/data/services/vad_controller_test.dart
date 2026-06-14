import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/chat/data/services/vad_controller.dart';

void main() {
  group('MicLevel.normalized', () {
    test('maps the dBFS range onto 0..1', () {
      expect(const MicLevel(0).normalized(), closeTo(1.0, 1e-9));
      expect(const MicLevel(-60).normalized(), closeTo(0.0, 1e-9));
      expect(const MicLevel(-30).normalized(), closeTo(0.5, 1e-9));
    });

    test('clamps out-of-range and non-finite values', () {
      expect(const MicLevel(10).normalized(), 1.0);
      expect(const MicLevel(-200).normalized(), 0.0);
      expect(const MicLevel(double.nan).normalized(), 0.0);
      expect(const MicLevel(double.infinity).normalized(), 0.0);
    });
  });

  group('VadController', () {
    /// A manual clock so debounce windows are deterministic without real time.
    late Duration clock;
    VadController build(VadConfig config) =>
        VadController(config: config, clock: () => clock);

    const config = VadConfig(
      speechThresholdDbfs: -35.0,
      silenceWindow: Duration(milliseconds: 1500),
      minSpeechDuration: Duration(milliseconds: 300),
      maxListenDuration: Duration(seconds: 30),
    );

    setUp(() => clock = Duration.zero);

    void advance(Duration by) => clock += by;

    test('fires silence stop after the debounce window following speech', () {
      final vad = build(config);
      VadStopReason? reason;
      vad.start(onStop: (r) => reason = r);

      // Speak for 400ms (above the 300ms min).
      vad.add(const MicLevel(-20));
      advance(const Duration(milliseconds: 400));
      vad.add(const MicLevel(-20));

      expect(reason, isNull, reason: 'still speaking');
      expect(vad.hasDetectedSpeech, isTrue);

      // Go silent; not yet past the 1500ms window.
      advance(const Duration(milliseconds: 1000));
      vad.add(const MicLevel(-60));
      expect(reason, isNull);

      // Cross the silence window.
      advance(const Duration(milliseconds: 600));
      vad.add(const MicLevel(-60));
      expect(reason, VadStopReason.silence);
    });

    test('never fires on pure silence with no speech', () {
      final vad = build(config);
      var fired = false;
      vad.start(onStop: (_) => fired = true);

      for (var i = 0; i < 50; i++) {
        advance(const Duration(seconds: 2));
        vad.add(const MicLevel(-70));
      }

      expect(fired, isFalse);
      expect(vad.hasDetectedSpeech, isFalse);
    });

    test('does not fire when speech was shorter than the min duration', () {
      final vad = build(config);
      var fired = false;
      vad.start(onStop: (_) => fired = true);

      // Single blip below the 300ms min-speech guard.
      vad.add(const MicLevel(-20));
      advance(const Duration(milliseconds: 100));
      vad.add(const MicLevel(-60));
      advance(const Duration(milliseconds: 2000));
      vad.add(const MicLevel(-60));

      expect(fired, isFalse);
    });

    test('respects the max-listen cap once speech started', () {
      final vad = build(config);
      VadStopReason? reason;
      vad.start(onStop: (r) => reason = r);

      vad.add(const MicLevel(-20)); // speech begins at t=0
      // Keep speaking past the 30s cap.
      advance(const Duration(seconds: 31));
      vad.add(const MicLevel(-20));

      expect(reason, VadStopReason.maxDuration);
    });

    test('fires onStop at most once', () {
      final vad = build(config);
      var count = 0;
      vad.start(onStop: (_) => count++);

      vad.add(const MicLevel(-20));
      advance(const Duration(milliseconds: 400));
      vad.add(const MicLevel(-20));
      advance(const Duration(milliseconds: 2000));
      vad.add(const MicLevel(-60)); // fires
      advance(const Duration(milliseconds: 2000));
      vad.add(const MicLevel(-60)); // ignored

      expect(count, 1);
    });

    test('reset stops further callbacks', () {
      final vad = build(config);
      var fired = false;
      vad.start(onStop: (_) => fired = true);
      vad.add(const MicLevel(-20));
      vad.reset();
      advance(const Duration(seconds: 5));
      vad.add(const MicLevel(-60));
      expect(fired, isFalse);
    });
  });
}
