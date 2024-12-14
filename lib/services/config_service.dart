import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  static const String _configKey = 'app_config';
  
  late SharedPreferences _prefs;
  Map<String, dynamic> _config = {};
  bool _initialized = false;

  // Default configuration
  static const Map<String, dynamic> _defaultConfig = {
    'environment': 'development',
    'api': {
      'baseUrl': 'http://localhost:3000',
      'timeout': 30000,
    },
    'aws': {
      'region': 'us-west-2',
      'cognito': {
        'userPoolId': '',
        'clientId': '',
      },
      's3': {
        'bucket': '',
      },
      'rds': {
        'endpoint': '',
      },
    },
    'ui': {
      'theme': {
        'primaryColor': 0xFF2196F3,
        'secondaryColor': 0xFF6C757D,
        'backgroundColor': 0xFFFFFFFF,
        'textColor': 0xFF000000,
      },
      'layout': {
        'maxWidth': 1200,
        'sidebarWidth': 300,
        'outlineWidth': 250,
      },
      'editor': {
        'fontFamily': 'Roboto Mono',
        'fontSize': 14,
        'lineHeight': 1.5,
        'tabSize': 2,
      },
    },
    'markdown': {
      'maxHeaderLevel': 6,
      'validTags': ['employee', 'company', 'policy', 'date'],
      'validConditions': ['complianceIsRequired', 'isEmployee', 'hasAccess'],
    },
    'features': {
      'offlineMode': true,
      'autoSave': true,
      'syntaxHighlighting': true,
      'documentHistory': true,
      'aiSuggestions': false,
    },
    'logging': {
      'level': 'info',
      'includeTimestamp': true,
      'includeUserId': true,
    },
  };

  factory ConfigService() {
    return _instance;
  }

  ConfigService._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    
    // Try to load config from shared preferences
    final String? storedConfig = _prefs.getString(_configKey);
    if (storedConfig != null) {
      try {
        _config = json.decode(storedConfig);
      } catch (e) {
        print('Error loading stored config: $e');
        _config = Map<String, dynamic>.from(_defaultConfig);
      }
    } else {
      _config = Map<String, dynamic>.from(_defaultConfig);
    }

    // Try to load environment-specific config
    try {
      final envConfig = await rootBundle.loadString('assets/config/${_config['environment']}.json');
      final envConfigMap = json.decode(envConfig);
      _mergeConfig(envConfigMap);
    } catch (e) {
      print('No environment-specific config found: $e');
    }

    _initialized = true;
  }

  void _mergeConfig(Map<String, dynamic> newConfig) {
    _config = _deepMerge(_config, newConfig);
  }

  Map<String, dynamic> _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    source.forEach((key, value) {
      if (value is Map<String, dynamic> && target[key] is Map<String, dynamic>) {
        target[key] = _deepMerge(target[key], value);
      } else {
        target[key] = value;
      }
    });
    return target;
  }

  Future<void> updateConfig(Map<String, dynamic> newConfig) async {
    _mergeConfig(newConfig);
    await _saveConfig();
  }

  Future<void> _saveConfig() async {
    await _prefs.setString(_configKey, json.encode(_config));
  }

  T getValue<T>(String key, {T? defaultValue}) {
    if (!_initialized) {
      throw StateError('ConfigService not initialized');
    }

    final keys = key.split('.');
    dynamic value = _config;

    for (final k in keys) {
      if (value is! Map<String, dynamic> || !value.containsKey(k)) {
        return defaultValue as T;
      }
      value = value[k];
    }

    if (value is! T) {
      return defaultValue as T;
    }

    return value;
  }

  Future<void> setValue<T>(String key, T value) async {
    if (!_initialized) {
      throw StateError('ConfigService not initialized');
    }

    final keys = key.split('.');
    Map<String, dynamic> current = _config;

    for (int i = 0; i < keys.length - 1; i++) {
      final k = keys[i];
      if (!current.containsKey(k) || current[k] is! Map<String, dynamic>) {
        current[k] = <String, dynamic>{};
      }
      current = current[k];
    }

    current[keys.last] = value;
    await _saveConfig();
  }

  bool get isInitialized => _initialized;
  
  Map<String, dynamic> get allConfig => Map<String, dynamic>.from(_config);

  // Helper methods for common configurations
  bool isFeatureEnabled(String featureName) {
    return getValue<bool>('features.$featureName', defaultValue: false);
  }

  Map<String, dynamic> get uiTheme => getValue<Map<String, dynamic>>('ui.theme');
  
  Map<String, dynamic> get layoutConfig => getValue<Map<String, dynamic>>('ui.layout');
  
  Map<String, dynamic> get editorConfig => getValue<Map<String, dynamic>>('ui.editor');
  
  List<String> get validMarkdownTags => 
      List<String>.from(getValue<List>('markdown.validTags', defaultValue: []));
  
  String get environment => getValue<String>('environment', defaultValue: 'development');
  
  Map<String, dynamic> get awsConfig => getValue<Map<String, dynamic>>('aws');
}
