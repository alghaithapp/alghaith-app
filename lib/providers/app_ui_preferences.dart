import 'package:flutter/material.dart';

/// Language, theme, and in-app alert toggles (extracted from [AppProvider]).
class AppUiPreferences {
  String lang = 'ar';
  bool darkMode = false;
  bool inAppAlertsEnabled = true;
  bool skippedCustomerSetup = false;
  int? lastMainTab;
  String? homeCategoryFilter;
  List<String> catalogSearchHistory = const [];
  String? driverType;

  ThemeMode get themeMode => darkMode ? ThemeMode.dark : ThemeMode.light;

  void setLanguage(String value) {
    lang = value;
  }

  void applyRemoteState(Map<String, dynamic> state) {
    darkMode = state['darkMode'] as bool? ?? darkMode;
    inAppAlertsEnabled = state['inAppAlertsEnabled'] as bool? ??
        state['notificationsEnabled'] as bool? ??
        inAppAlertsEnabled;
    skippedCustomerSetup =
        state['skippedCustomerSetup'] as bool? ?? skippedCustomerSetup;
    lastMainTab = (state['lastMainTab'] as num?)?.toInt() ?? lastMainTab;
    homeCategoryFilter =
        state['homeCategoryFilter'] as String? ?? homeCategoryFilter;
    final history = state['catalogSearchHistory'];
    if (history is List) {
      catalogSearchHistory =
          history.map((item) => item.toString()).toList(growable: false);
    }
    driverType = state['driverType'] as String? ?? driverType;
    lang = state['lang'] as String? ?? lang;
  }

  Map<String, dynamic> toRemoteState() {
    return {
      'darkMode': darkMode,
      'inAppAlertsEnabled': inAppAlertsEnabled,
      if (skippedCustomerSetup) 'skippedCustomerSetup': true,
      if (lastMainTab != null) 'lastMainTab': lastMainTab,
      if (homeCategoryFilter != null && homeCategoryFilter!.isNotEmpty)
        'homeCategoryFilter': homeCategoryFilter,
      if (catalogSearchHistory.isNotEmpty)
        'catalogSearchHistory': catalogSearchHistory,
      if (driverType != null && driverType!.isNotEmpty) 'driverType': driverType,
      if (lang.isNotEmpty) 'lang': lang,
    };
  }
}
