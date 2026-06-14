import 'package:flutter_test/flutter_test.dart';
import 'package:gena/features/downloads/data/models/local_model_capabilities.dart';
import 'package:gena/features/setting/data/chat_model_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ChatModelSettings.defaults', () {
    test('exposes the documented default values', () {
      const settings = ChatModelSettings(
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxTokens: 2048,
        tokenBuffer: 256,
        randomSeed: 1,
        preferredBackend: 'gpu',
        isThinkingOverride: null,
      );
      final defaults = ChatModelSettings.defaults();

      expect(defaults.temperature, settings.temperature);
      expect(defaults.topK, settings.topK);
      expect(defaults.topP, settings.topP);
      expect(defaults.maxTokens, settings.maxTokens);
      expect(defaults.tokenBuffer, settings.tokenBuffer);
      expect(defaults.randomSeed, settings.randomSeed);
      expect(defaults.preferredBackend, 'gpu');
      expect(defaults.isThinkingOverride, isNull);
    });
  });

  group('ChatModelSettings.fromJson', () {
    test('parses every field and coerces numeric types', () {
      final settings = ChatModelSettings.fromJson(<String, dynamic>{
        'temperature': 1, // int -> double
        'topK': 20.0, // double -> int
        'topP': 0.5,
        'maxTokens': 1024,
        'tokenBuffer': 128,
        'randomSeed': 7,
        'preferredBackend': 'cpu',
        'isThinkingOverride': true,
      });

      expect(settings.temperature, 1.0);
      expect(settings.topK, 20);
      expect(settings.topP, 0.5);
      expect(settings.maxTokens, 1024);
      expect(settings.tokenBuffer, 128);
      expect(settings.randomSeed, 7);
      expect(settings.preferredBackend, 'cpu');
      expect(settings.isThinkingOverride, isTrue);
    });

    test('falls back to defaults for missing keys', () {
      final defaults = ChatModelSettings.defaults();
      final settings = ChatModelSettings.fromJson(const <String, dynamic>{});

      expect(settings.temperature, defaults.temperature);
      expect(settings.topK, defaults.topK);
      expect(settings.topP, defaults.topP);
      expect(settings.maxTokens, defaults.maxTokens);
      expect(settings.tokenBuffer, defaults.tokenBuffer);
      expect(settings.randomSeed, defaults.randomSeed);
      expect(settings.preferredBackend, defaults.preferredBackend);
      expect(settings.isThinkingOverride, isNull);
    });

    test('preserves an explicit null isThinkingOverride when key present', () {
      final settings = ChatModelSettings.fromJson(<String, dynamic>{
        'isThinkingOverride': null,
      });
      expect(settings.isThinkingOverride, isNull);
    });

    test('reads isThinkingOverride false when key present', () {
      final settings = ChatModelSettings.fromJson(<String, dynamic>{
        'isThinkingOverride': false,
      });
      expect(settings.isThinkingOverride, isFalse);
    });
  });

  group('toJson round-trip', () {
    test('serializes then deserializes to an equivalent object', () {
      const original = ChatModelSettings(
        temperature: 0.3,
        topK: 11,
        topP: 0.7,
        maxTokens: 512,
        tokenBuffer: 64,
        randomSeed: 99,
        preferredBackend: 'cpu',
        isThinkingOverride: false,
      );

      final restored = ChatModelSettings.fromJson(original.toJson());

      expect(restored.temperature, original.temperature);
      expect(restored.topK, original.topK);
      expect(restored.topP, original.topP);
      expect(restored.maxTokens, original.maxTokens);
      expect(restored.tokenBuffer, original.tokenBuffer);
      expect(restored.randomSeed, original.randomSeed);
      expect(restored.preferredBackend, original.preferredBackend);
      expect(restored.isThinkingOverride, original.isThinkingOverride);
    });
  });

  group('copyWith', () {
    test('keeps existing values when nothing is supplied', () {
      const original = ChatModelSettings(
        temperature: 0.3,
        topK: 11,
        topP: 0.7,
        maxTokens: 512,
        tokenBuffer: 64,
        randomSeed: 99,
        preferredBackend: 'cpu',
        isThinkingOverride: true,
      );

      final copy = original.copyWith();

      expect(copy.temperature, original.temperature);
      expect(copy.topK, original.topK);
      expect(copy.topP, original.topP);
      expect(copy.maxTokens, original.maxTokens);
      expect(copy.tokenBuffer, original.tokenBuffer);
      expect(copy.randomSeed, original.randomSeed);
      expect(copy.preferredBackend, original.preferredBackend);
      expect(copy.isThinkingOverride, original.isThinkingOverride);
    });

    test('overrides only the supplied scalar fields', () {
      final base = ChatModelSettings.defaults();
      final copy = base.copyWith(
        temperature: 0.1,
        topK: 5,
        topP: 0.2,
        maxTokens: 256,
        tokenBuffer: 32,
        randomSeed: 3,
        preferredBackend: 'cpu',
      );

      expect(copy.temperature, 0.1);
      expect(copy.topK, 5);
      expect(copy.topP, 0.2);
      expect(copy.maxTokens, 256);
      expect(copy.tokenBuffer, 32);
      expect(copy.randomSeed, 3);
      expect(copy.preferredBackend, 'cpu');
      // isThinkingOverride untouched without the update flag.
      expect(copy.isThinkingOverride, base.isThinkingOverride);
    });

    test('isThinkingOverride is not cleared unless update flag is set', () {
      const base = ChatModelSettings(
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxTokens: 2048,
        tokenBuffer: 256,
        randomSeed: 1,
        preferredBackend: 'gpu',
        isThinkingOverride: true,
      );

      // Passing null without the flag keeps the previous value.
      final unchanged = base.copyWith(isThinkingOverride: null);
      expect(unchanged.isThinkingOverride, isTrue);

      // Setting the flag applies the (possibly null) value.
      final cleared = base.copyWith(
        isThinkingOverride: null,
        updateIsThinkingOverride: true,
      );
      expect(cleared.isThinkingOverride, isNull);

      final toggled = base.copyWith(
        isThinkingOverride: false,
        updateIsThinkingOverride: true,
      );
      expect(toggled.isThinkingOverride, isFalse);
    });
  });

  group('backend getter', () {
    test('resolves a known backend name', () {
      const settings = ChatModelSettings(
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxTokens: 2048,
        tokenBuffer: 256,
        randomSeed: 1,
        preferredBackend: 'gpu',
        isThinkingOverride: null,
      );
      expect(settings.backend, parseLocalModelBackend('gpu'));
      expect(settings.backend, isNotNull);
    });

    test('returns null for an unknown backend name', () {
      const settings = ChatModelSettings(
        temperature: 0.8,
        topK: 40,
        topP: 0.95,
        maxTokens: 2048,
        tokenBuffer: 256,
        randomSeed: 1,
        preferredBackend: 'not-a-backend',
        isThinkingOverride: null,
      );
      expect(settings.backend, isNull);
    });
  });

  group('SharedPreferences integration', () {
    test('fromPrefs returns defaults for an empty store', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      final settings = ChatModelSettings.fromPrefs(prefs);
      final defaults = ChatModelSettings.defaults();

      expect(settings.temperature, defaults.temperature);
      expect(settings.preferredBackend, defaults.preferredBackend);
      expect(settings.isThinkingOverride, isNull);
    });

    test('saveToPrefs then fromPrefs round-trips a non-null override',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();

      const settings = ChatModelSettings(
        temperature: 0.25,
        topK: 12,
        topP: 0.6,
        maxTokens: 777,
        tokenBuffer: 88,
        randomSeed: 42,
        preferredBackend: 'cpu',
        isThinkingOverride: true,
      );
      await settings.saveToPrefs(prefs);

      final restored = ChatModelSettings.fromPrefs(prefs);
      expect(restored.temperature, 0.25);
      expect(restored.topK, 12);
      expect(restored.topP, 0.6);
      expect(restored.maxTokens, 777);
      expect(restored.tokenBuffer, 88);
      expect(restored.randomSeed, 42);
      expect(restored.preferredBackend, 'cpu');
      expect(restored.isThinkingOverride, isTrue);
    });

    test('saving a null override removes the persisted key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_settings_is_thinking_override': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final settings = ChatModelSettings.defaults().copyWith(
        isThinkingOverride: null,
        updateIsThinkingOverride: true,
      );
      await settings.saveToPrefs(prefs);

      expect(prefs.containsKey('chat_settings_is_thinking_override'), isFalse);
      expect(ChatModelSettings.fromPrefs(prefs).isThinkingOverride, isNull);
    });

    test('fromPrefs falls back to the legacy thinking key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_settings_is_thinking': true,
      });
      final prefs = await SharedPreferences.getInstance();

      expect(ChatModelSettings.fromPrefs(prefs).isThinkingOverride, isTrue);
    });

    test('saving clears the legacy thinking key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_settings_is_thinking': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final settings = ChatModelSettings.defaults().copyWith(
        isThinkingOverride: false,
        updateIsThinkingOverride: true,
      );
      await settings.saveToPrefs(prefs);

      expect(prefs.containsKey('chat_settings_is_thinking'), isFalse);
      expect(ChatModelSettings.fromPrefs(prefs).isThinkingOverride, isFalse);
    });
  });
}
