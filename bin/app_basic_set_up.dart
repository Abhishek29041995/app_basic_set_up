import 'dart:io';

void main() async {
  print("🚀 Welcome to Flutter App Setup CLI!");

  // Check for FVM installation first
  bool fvmInstalled = await _checkFvmInstallation();
  if (!fvmInstalled) {
    await _handleFvmInstallation();
  }

  stdout.write("Enter the name of your entry page (default: intro): ");
  String entryPageInput = stdin.readLineSync()?.trim().toLowerCase() ?? "intro";
  if (entryPageInput.isEmpty) entryPageInput = "intro";

  // Convert to proper naming format for class
  String entryPageClass = _toPascalCase(entryPageInput);
  // For file and folder names, use snake case
  String entryPageFileName = "${entryPageInput}_page.dart";
  String entryPageFolder = entryPageInput;

  stdout.write("Would you like to add flavors? (y/n): ");
  bool useFlavors = (stdin.readLineSync()?.trim().toLowerCase() == 'y');

  List<String> flavors = [];
  Map<String, String> baseUrls = {};
  String baseBundleId = "";

  if (useFlavors) {
    stdout.write("Enter flavors (comma-separated, e.g., dev,uat,prod): ");
    String? flavorsInput = stdin.readLineSync();
    flavors =
        flavorsInput?.split(",").map((e) => e.trim().toLowerCase()).toList() ??
        [];

    if (flavors.isEmpty) {
      print("⚠️ No flavors provided. Exiting.");
      return;
    }

    // Get base bundle ID once
    stdout.write("Enter base Bundle ID (e.g., com.example.app): ");
    baseBundleId = stdin.readLineSync()?.trim() ?? "com.example.app";

    for (var flavor in flavors) {
      stdout.write("Enter Base URL for $flavor: ");
      baseUrls[flavor] = stdin.readLineSync() ?? "";
    }
  }

  stdout.write("Would you like to add VSCode configuration files? (y/n): ");
  bool addVSCodeConfig = (stdin.readLineSync()?.trim().toLowerCase() == 'y');

  print("\n🛠 Generating project structure...\n");

  await _updatePubspec();
  await _runPubGet();
  await _generateAppFile();
  await _generateRouterFile(entryPageClass, entryPageFolder, entryPageFileName);
  await _generateLocatorFile();
  await _generatePresentationFiles(
    entryPageClass,
    entryPageFolder,
    entryPageFileName,
  );
  await _createAnalysisOptions();
  await _runBuildRunner();

  if (useFlavors) {
    // Generate package IDs based on the base bundle ID
    Map<String, String> packageIds = {};
    for (var flavor in flavors) {
      // For prod, use the base bundle ID as is; for others, append the flavor
      packageIds[flavor] = flavor == 'prod' 
          ? baseBundleId 
          : "$baseBundleId.$flavor";
    }
    
    await _updateConfigFile(flavors, baseUrls);
    await _generateMainFiles(flavors);
    await _updateAndroidFiles(flavors, packageIds);
    await _updateIOSFiles(flavors, packageIds);
  }

  if (addVSCodeConfig) {
    await _createVSCodeFiles(flavors);
  }

  print(
    "\n🎉 Setup Complete! Run `flutter run ${useFlavors ? '--flavor <flavor>' : ''}` to test.",
  );
  print("🤝 Happy coding! Hope this setup makes your development smoother.");
}

/// Check if FVM is installed
Future<bool> _checkFvmInstallation() async {
  try {
    ProcessResult result = Process.runSync('fvm', ['--version']);
    if (result.exitCode == 0) {
      print("✅ FVM is already installed: ${result.stdout}");
      return true;
    }
  } catch (e) {
    // FVM is not installed or not in PATH
  }
  return false;
}

/// Handle FVM installation and setup
Future<void> _handleFvmInstallation() async {
  stdout.write("FVM (Flutter Version Management) is not installed. Would you like to install it? (y/n): ");
  bool installFvm = (stdin.readLineSync()?.trim().toLowerCase() == 'y');
  
  if (!installFvm) {
    print("⚠️ Skipping FVM installation. Note that some features may not work correctly.");
    return;
  }
  
  print("🔧 Installing FVM...");
  
  // Install FVM using dart pub global activate
  try {
    Process.runSync('dart', ['pub', 'global', 'activate', 'fvm']);
    print("✅ FVM installed successfully!");
    
    // Add FVM to PATH instructions
    print("ℹ️ Make sure FVM is in your PATH. You might need to add the following to your profile:");
    print("  export PATH=\"\$PATH:\$HOME/.pub-cache/bin\"");
    
    // Install Flutter version using FVM
    stdout.write("Would you like to install Flutter 3.29.2 using FVM? (y/n): ");
    bool installFlutter = (stdin.readLineSync()?.trim().toLowerCase() == 'y');
    
    if (installFlutter) {
      print("🔧 Installing Flutter 3.29.2 using FVM (this may take a while)...");
      Process.runSync('fvm', ['install', '3.29.2']);
      Process.runSync('fvm', ['use', '3.29.2']);
      print("✅ Flutter 3.29.2 installed successfully!");
      
      // Suggest VS Code restart
      stdout.write("Would you like to restart VS Code to apply FVM settings? (y/n): ");
      bool restartVsCode = (stdin.readLineSync()?.trim().toLowerCase() == 'y');
      
      if (restartVsCode) {
        print("🔄 Restarting VS Code...");
        if (Platform.isWindows) {
          Process.runSync('taskkill', ['/F', '/IM', 'Code.exe']);
          Process.runSync('cmd', ['/c', 'start', 'code', '.']);
        } else if (Platform.isMacOS) {
          Process.runSync('pkill', ['-f', 'Visual Studio Code']);
          Process.runSync('open', ['-a', 'Visual Studio Code', '.']);
        } else if (Platform.isLinux) {
          Process.runSync('pkill', ['code']);
          Process.runSync('code', ['.']);
        }
        print("✅ VS Code has been restarted. Please run this setup script again.");
        exit(0);
      }
    }
  } catch (e) {
    print("⚠️ Failed to install FVM: $e");
    print("ℹ️ Please install FVM manually: https://fvm.app/docs/getting_started/installation");
  }
}

/// Converts a string to PascalCase
String _toPascalCase(String input) {
  if (input.isEmpty) return '';
  return input
      .split('_')
      .map(
        (word) =>
            word.isEmpty
                ? ''
                : word[0].toUpperCase() + word.substring(1).toLowerCase(),
      )
      .join('');
}

/// Create analysis_options.yaml with code quality rules
Future<void> _createAnalysisOptions() async {
  String content = '''
# This file configures the analyzer, which statically analyzes Dart code to
# check for errors, warnings, and lints.
#
# The issues identified by the analyzer are surfaced in the UI of Dart-enabled
# IDEs (https://dart.dev/tools#ides-and-editors). The analyzer can also be
# invoked from the command line by running `flutter analyze`.
# The following line activates a set of recommended lints for Flutter apps,
# packages, and plugins designed to encourage good coding practices.
include: package:flutter_lints/flutter.yaml

analyzer:
  exclude:
    - "**/*.gr.dart"
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - always_declare_return_types
    - always_require_non_null_named_parameters
    - annotate_overrides
    - avoid_bool_literals_in_conditional_expressions
    - avoid_empty_else
    - avoid_print
    - avoid_unnecessary_containers
    - avoid_unused_constructor_parameters
    - avoid_void_async
    - await_only_futures
    - camel_case_types
    - cancel_subscriptions
    - constant_identifier_names
    - curly_braces_in_flow_control_structures
    - directives_ordering
    - empty_catches
    - empty_constructor_bodies
    - file_names
    - implementation_imports
    - library_names
    - library_prefixes
    - list_remove_unrelated_type
    - no_leading_underscores_for_local_identifiers
    - non_constant_identifier_names
    - overridden_fields
    - package_api_docs
    - package_names
    - prefer_const_constructors
    - prefer_const_constructors_in_immutables
    - prefer_const_declarations
    - prefer_final_fields
    - prefer_initializing_formals
    - prefer_is_not_empty
    - prefer_single_quotes
    - prefer_typing_uninitialized_variables
    - require_trailing_commas
    - sized_box_for_whitespace
    - sort_child_properties_last
    - type_init_formals
    - unawaited_futures
    - unnecessary_brace_in_string_interps
    - unnecessary_const
    - unnecessary_getters_setters
    - unnecessary_new
    - unnecessary_null_aware_assignments
    - unnecessary_null_in_if_null_operators
    - unnecessary_string_escapes
    - unnecessary_string_interpolations
    - unnecessary_this
    - use_build_context_synchronously
    - use_full_hex_values_for_flutter_colors
    - use_key_in_widget_constructors
    - use_rethrow_when_possible
    - valid_regexps

dart_code_metrics:
  anti-patterns:
    - long-method:
        exclude:
          - "**/*_bloc.dart"
          - "**/value_transformers.dart"
    - long-parameter-list
  metrics:
    cyclomatic-complexity: 30
    maximum-nesting-level: 6
    number-of-parameters: 20
    source-lines-of-code: 62
  metrics-exclude:
    # - test/**
    # - integration_test/**
    - lib/core/di/locator.dart
  rules:
    - newline-before-return
    - no-boolean-literal-compare
    - no-empty-block
    - prefer-trailing-comma
    - prefer-conditional-expressions
    - no-equal-then-else
    - avoid-shrink-wrap-in-lists
    - avoid-unnecessary-setstate
    - always-remove-listener
    - avoid-expanded-as-spacer
    - prefer-correct-edge-insets-constructor
    - avoid-returning-widgets
''';

  File("analysis_options.yaml").writeAsStringSync(content);

  // Add flutter_lints to dev_dependencies if it's not already there
  await _addFlutterLintsDependency();

  print("✅ Created analysis_options.yaml with code quality rules");
}

/// Add flutter_lints to dev_dependencies
Future<void> _addFlutterLintsDependency() async {
  File pubspecFile = File("pubspec.yaml");
  if (!pubspecFile.existsSync()) return;

  String content = pubspecFile.readAsStringSync();
  if (!content.contains("flutter_lints")) {
    List<String> lines = content.split("\n");
    int devDepsIndex = lines.indexWhere(
      (line) => line.trim() == "dev_dependencies:",
    );

    if (devDepsIndex != -1) {
      // Find the position to insert the dependency
      int insertIndex = devDepsIndex + 1;
      while (insertIndex < lines.length &&
          (lines[insertIndex].trim().isEmpty ||
              lines[insertIndex].startsWith("  "))) {
        insertIndex++;
      }

      lines.insert(insertIndex, "  flutter_lints: ^2.0.0");
      pubspecFile.writeAsStringSync(lines.join("\n"));
    }
  }
}

/// Create VSCode settings.json and launch.json files
Future<void> _createVSCodeFiles(List<String> flavors) async {
  Directory(".vscode").createSync(recursive: true);

  // Create settings.json
  String settingsContent = '''
{
  "git.autofetch": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit",
    "source.dcm.fixAll": "explicit"
  },
  "[plist]": {
    "editor.formatOnSave": true
  },
  "debug.openDebug": "openOnDebugBreak",
  "debug.internalConsoleOptions": "openOnSessionStart",
  "debug.toolBarLocation": "commandCenter",
  "dart.previewFlutterUiGuidesCustomTracking": true,
  "dart.previewFlutterUiGuides": true,
  "dart.devToolsLocation": "external",
  "dart.runPubGetOnPubspecChanges": "prompt",
  "dart.flutterSdkPath": ".fvm/flutter_sdk",
  "dart.sdkPath": ".fvm/flutter_sdk/bin/dart",
  "[dart]": {
    "editor.formatOnType": true,
    "editor.formatOnSave": true,
    "editor.rulers": [
      80
    ],
    "editor.selectionHighlight": false,
    "editor.suggest.snippetsPreventQuickSuggestions": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": "off",
    "editor.guides.indentation": true,
    "editor.defaultFormatter": "Dart-Code.dart-code"
  },
  "search.exclude": {
    "**/.fvm": true
  },
  "files.watcherExclude": {
    "**/.fvm": true
  },
  "files.exclude": {
    "**/*.freezed.dart": true,
    "**/*.g.dart": true,
    "**/*.gr.dart": true
  },
  "[csv]": {
    "files.eol": "\\r\\n"
  },
  "flutter-coverage.coverageFileNames": [
    "lcov.info",
    "cov.xml",
    "coverage.xml",
    "jacoco.xml"
  ]
}
''';

  // Build launch configurations based on flavors
  List<String> launchConfigurations = [];

  // Always add default Flutter configuration
  launchConfigurations.add('''
    {
      "name": "Flutter",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "flutterMode": "profile"
    }''');

  // Add flavor-specific configurations
  if (flavors.isNotEmpty) {
    for (var flavor in flavors) {
      launchConfigurations.add('''
    {
      "name": "$flavor",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_$flavor.dart",
      "args": ["--flavor", "$flavor"]
    }''');
    }

    // Add profile and release configs for the first flavor
    String mainFlavor = flavors.first;
    launchConfigurations.add('''
    {
      "name": "$mainFlavor-profile",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile",
      "program": "lib/main_$mainFlavor.dart",
      "args": ["--flavor", "$mainFlavor"]
    }''');

    launchConfigurations.add('''
    {
      "name": "$mainFlavor-release",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_$mainFlavor.dart",
      "args": ["--flavor", "$mainFlavor", "--release"]
    }''');
  }

  // Build compound configurations if needed
  List<String> compoundConfigs = [];
  if (flavors.length >= 2) {
    List<String> deviceConfigs = [];

    // Create device-specific configs first
    for (var flavor in flavors.take(2)) {
      String androidConfig = '''
    {
      "name": "$flavor-android",
      "request": "launch",
      "deviceId": "emulator-5554",
      "type": "dart",
      "program": "lib/main_$flavor.dart",
      "args": ["--flavor", "$flavor"]
    }''';

      String iosConfig = '''
    {
      "name": "$flavor-ios",
      "request": "launch",
      "deviceId": "apple_ios_simulator",
      "type": "dart",
      "program": "lib/main_$flavor.dart",
      "args": ["--flavor", "$flavor"]
    }''';

      launchConfigurations.add(androidConfig);
      launchConfigurations.add(iosConfig);

      deviceConfigs.add('"$flavor-android"');
      deviceConfigs.add('"$flavor-ios"');
    }

    // Create compound config
    compoundConfigs.add('''
    {
      "name": "all-devices",
      "configurations": [${deviceConfigs.join(', ')}]
    }''');
  }

  String launchJson = '''
{
  // Use IntelliSense to learn about possible attributes.
  // Hover to view descriptions of existing attributes.
  // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
  "version": "0.2.0",
  "configurations": [
${launchConfigurations.join(',\n')}
  ]${compoundConfigs.isNotEmpty ? ',\n  "compounds": [\n${compoundConfigs.join(',\n')}\n  ]' : ''}
}
''';

  File(".vscode/settings.json").writeAsStringSync(settingsContent);
  File(".vscode/launch.json").writeAsStringSync(launchJson);

  print("✅ Created VSCode configuration files:");
  print("  • .vscode/settings.json");
  print("  • .vscode/launch.json");
}

/// Generates `lib/app.dart`
Future<void> _generateAppFile() async {
  String content = '''
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'core/di/locator.dart';
import 'core/router/router.dart';
import 'core/config/config.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = locator<AppRouter>();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: locator<Config>().appName,
      routerDelegate: AutoRouterDelegate(
        router,
      ),
      routeInformationParser: router.defaultRouteParser(),
    );
  }
}
''';

  Directory("lib/core/config").createSync(recursive: true);
  Directory("lib/core/router").createSync(recursive: true);
  Directory("lib/core/di").createSync(recursive: true);

  File("lib/app.dart").writeAsStringSync(content);
  print("✅ Created lib/app.dart");
}

/// Generates `lib/core/router/router.dart`
Future<void> _generateRouterFile(
  String entryPageClass,
  String entryPageFolder,
  String entryPageFileName,
) async {
  String content = '''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import '../../presentation/screens/$entryPageFolder/$entryPageFileName';

part 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends \$AppRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: ${entryPageClass}Page.page, initial: true),
      ];
}
''';

  File("lib/core/router/router.dart").writeAsStringSync(content);
  print("✅ Created lib/core/router/router.dart");
}

/// Generates `lib/core/di/locator.dart`
Future<void> _generateLocatorFile() async {
  String content = '''
import 'package:get_it/get_it.dart';
import '../router/router.dart';
import '../config/config.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register router
  locator.registerSingleton<AppRouter>(AppRouter());
  
  // Register config
  locator.registerSingleton<Config>(Config());
  
  // Register services and repositories here
}
''';

  File("lib/core/di/locator.dart").writeAsStringSync(content);
  print("✅ Created lib/core/di/locator.dart");
}

/// Creates presentation structure and entry page
Future<void> _generatePresentationFiles(
  String entryPageClass,
  String entryPageFolder,
  String entryPageFileName,
) async {
  Directory(
    "lib/presentation/screens/$entryPageFolder",
  ).createSync(recursive: true);

  String content = '''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ${entryPageClass}Page extends StatelessWidget {
  const ${entryPageClass}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${entryPageClass} Page')),
      body: const Center(child: Text('Welcome to ${entryPageClass}!')),
    );
  }
}
''';

  File(
    "lib/presentation/screens/$entryPageFolder/$entryPageFileName",
  ).writeAsStringSync(content);
  print(
    "✅ Created lib/presentation/screens/$entryPageFolder/$entryPageFileName",
  );
}

/// Runs `flutter pub get`
Future<void> _runPubGet() async {
  print("📦 Running `flutter pub get`...");
  Process.runSync('flutter', ['pub', 'get']);
  print("✅ Dependencies installed.");
}

/// Runs `flutter pub run build_runner build --delete-conflicting-outputs`
Future<void> _runBuildRunner() async {
  print("🔧 Running build_runner...");
  Process.runSync('flutter', [
    'pub',
    'run',
    'build_runner',
    'build',
    '--delete-conflicting-outputs',
  ]);
  print("✅ Code generation complete.");
}

/// Updates `pubspec.yaml`
Future<void> _updatePubspec() async {
  File pubspecFile = File("pubspec.yaml");
  if (!pubspecFile.existsSync()) {
    print("⚠️ pubspec.yaml not found. Skipping dependency installation.");
    return;
  }

  List<String> lines = pubspecFile.readAsLinesSync();
  List<String> updatedLines = [];

  bool inDependencies = false, inDevDependencies = false;
  bool dependenciesUpdated = false, devDependenciesUpdated = false;
  bool inFlutterSection = false;

  // New dependencies to add (auto_route without a version)
  Map<String, String?> newDependencies = {
    "auto_route": null, // No version specified
    "get_it": "^7.6.7",
    "flutter_bloc": "^8.1.3",
    "equatable": "^2.0.5",
    "dio": "^5.3.2",
  };

  // New dev_dependencies to add
  Map<String, String> newDevDependencies = {
    "auto_route_generator": "^8.0.0",
    "build_runner": "^2.3.3",
    "json_serializable": "^6.6.1",
    "freezed": "^2.3.2",
    "flutter_lints": "^2.0.0",
    "dart_code_metrics": "^5.7.6",
  };

  // Track existing dependencies
  Set<String> existingDependencies = {};
  Set<String> existingDevDependencies = {};

  for (String line in lines) {
    String trimmed = line.trim();

    if (trimmed.startsWith("dependencies:")) {
      inDependencies = true;
      inDevDependencies = false;
      inFlutterSection = false;
      dependenciesUpdated = true;
    } else if (trimmed.startsWith("dev_dependencies:")) {
      inDependencies = false;
      inDevDependencies = true;
      inFlutterSection = false;
      devDependenciesUpdated = true;
    } else if (trimmed.startsWith("flutter:")) {
      inDependencies = false;
      inDevDependencies = false;
      inFlutterSection = true;
    } else if (trimmed.isNotEmpty &&
        !trimmed.startsWith(RegExp(r'[a-zA-Z_]'))) {
      // Not a dependency line
      inDependencies = false;
      inDevDependencies = false;
    }

    // Collect existing dependencies
    if (inDependencies || inDevDependencies) {
      List<String> parts = trimmed.split(":");
      if (parts.length > 1) {
        String key = parts[0].trim();
        if (inDependencies) {
          existingDependencies.add(key);
        } else if (inDevDependencies) {
          existingDevDependencies.add(key);
        }
      }
    }

    updatedLines.add(line);
  }

  // Insert missing dependencies in correct section
  List<String> finalLines = [];

  for (String line in updatedLines) {
    finalLines.add(line);

    if (line.trim().startsWith("dependencies:")) {
      for (var entry in newDependencies.entries) {
        if (!existingDependencies.contains(entry.key)) {
          if (entry.value == null) {
            finalLines.add("  ${entry.key}:"); // No version
          } else {
            finalLines.add("  ${entry.key}: ${entry.value}");
          }
        }
      }
    } else if (line.trim().startsWith("dev_dependencies:")) {
      for (var entry in newDevDependencies.entries) {
        if (!existingDevDependencies.contains(entry.key)) {
          finalLines.add("  ${entry.key}: ${entry.value}");
        }
      }
    }
  }

  // Write back the modified content
  pubspecFile.writeAsStringSync(finalLines.join("\n"));
  print("✅ Successfully updated pubspec.yaml without duplicates.");
}

/// Updates `lib/core/config/config.dart`
Future<void> _updateConfigFile(
  List<String> flavors,
  Map<String, String> baseUrls,
) async {
  String content = '''
enum Flavor { ${flavors.join(', ')} }

class Config {
  static Flavor appFlavor = Flavor.${flavors.first};
  
  String get appName => 'Flutter App (\${_flavorName})';
  
  String get _flavorName => appFlavor.toString().split('.').last;

  String get baseUrl {
    switch (appFlavor) {
${flavors.map((f) => "      case Flavor.$f:\n        return '${baseUrls[f]}';").join('\n')}
    }
  }
}
''';

  File("lib/core/config/config.dart").writeAsStringSync(content);
  print("✅ Created lib/core/config/config.dart");
}

/// Generates `main_<flavor>.dart` for each flavor
Future<void> _generateMainFiles(List<String> flavors) async {
  String mainContent = '''
import 'package:flutter/material.dart';
import 'core/config/config.dart';
import 'core/di/locator.dart';
import 'app.dart';

void main() {
  setupLocator();
  runApp(const App());
}
''';

  // Create regular main.dart
  File("lib/main.dart").writeAsStringSync(mainContent);
  print("✅ Created lib/main.dart");

  for (var flavor in flavors) {
    String content = '''
import 'package:flutter/material.dart';
import 'core/config/config.dart';
import 'core/di/locator.dart';
import 'app.dart';

void main() {
  Config.appFlavor = Flavor.$flavor;
  setupLocator();
  runApp(const App());
}
''';
    File("lib/main_$flavor.dart").writeAsStringSync(content);
    print("✅ Created lib/main_$flavor.dart");
  }
}

/// Updates `android/app/build.gradle` for flavors
Future<void> _updateAndroidFiles(
  List<String> flavors,
  Map<String, String> packageIds,
) async {
  File gradleFile = File("android/app/build.gradle");
  if (!gradleFile.existsSync()) return;
  String gradleContent = gradleFile.readAsStringSync();

  String flavorConfig = "    flavorDimensions \"flavor\"\n    productFlavors {";
  for (var flavor in flavors) {
    flavorConfig += '''
        $flavor {
            dimension "flavor"
            applicationId "${packageIds[flavor]}"
            resValue "string", "app_name", "Flutter App $flavor"
        }
    ''';
  }
  flavorConfig += "    }";

  if (!gradleContent.contains("productFlavors")) {
    // Find the right position to insert the flavor configuration
    int index = gradleContent.indexOf("android {") + "android {".length;
    String updatedContent =
        gradleContent.substring(0, index) +
        "\n$flavorConfig\n" +
        gradleContent.substring(index);

    gradleFile.writeAsStringSync(updatedContent);
    print("✅ Modified android/app/build.gradle for flavors.");
  }
}

/// Updates `ios/Runner.xcodeproj/project.pbxproj` for flavors
Future<void> _updateIOSFiles(
  List<String> flavors,
  Map<String, String> packageIds,
) async {
  print("⚠️ iOS flavor setup requires manual configuration.");
  print("ℹ️ Please follow these steps for iOS setup:");
  print("  1. Open iOS/Runner.xcodeproj in Xcode");
  print("  2. Go to Runner target > Build Settings");
  print("  3. Add User-Defined settings for each flavor:");

  for (var flavor in flavors) {
    print("     - For $flavor:");
    print("       • PRODUCT_BUNDLE_IDENTIFIER = ${packageIds[flavor]}");
  }

  // Create iOS flavor configurations helper file
  Directory("ios/Flutter/flavors").createSync(recursive: true);

  for (var flavor in flavors) {
    String content = '''
// Generated file - do not edit
#include "Flutter/Generated.xcconfig"
PRODUCT_BUNDLE_IDENTIFIER=${packageIds[flavor]};
FLUTTER_TARGET=lib/main_$flavor.dart;
''';
    File("ios/Flutter/flavors/$flavor.xcconfig").writeAsStringSync(content);
  }

  print("✅ Created iOS flavor configuration files in ios/Flutter/flavors/");
}
