import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudySettings {
  final bool showQuickTools;
  final String defaultAiBot; // 'deepseek' | 'chatgpt' | 'gemini'

  StudySettings({
    this.showQuickTools = true,
    this.defaultAiBot = 'deepseek',
  });

  StudySettings copyWith({bool? showQuickTools, String? defaultAiBot}) {
    return StudySettings(
      showQuickTools: showQuickTools ?? this.showQuickTools,
      defaultAiBot: defaultAiBot ?? this.defaultAiBot,
    );
  }
}

class StudySettingsNotifier extends StateNotifier<StudySettings> {
  StudySettingsNotifier() : super(StudySettings()) {
    _load();
  }

  static const _keyShowTools = 'study_show_quick_tools';
  static const _keyAiBot     = 'study_default_ai_bot';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final show  = prefs.getBool(_keyShowTools) ?? true;
    final bot   = prefs.getString(_keyAiBot) ?? 'deepseek';
    state = StudySettings(showQuickTools: show, defaultAiBot: bot);
  }

  Future<void> toggleQuickTools(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTools, val);
    state = state.copyWith(showQuickTools: val);
  }

  Future<void> setDefaultAiBot(String botId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAiBot, botId);
    // Also sync the AI chat page preference key so they share the same bot
    await prefs.setString('main_ai_bot_pref', botId);
    await prefs.setString('study_ai_bot_pref', botId);
    state = state.copyWith(defaultAiBot: botId);
  }
}

final studySettingsProvider =
    StateNotifierProvider<StudySettingsNotifier, StudySettings>(
        (ref) => StudySettingsNotifier());
