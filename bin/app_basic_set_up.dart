import 'dart:io';

void main() async {
  print("🚀 Welcome to Flutter App Setup CLI!");

  if (!await _ensureFvmInstalled()) return;

  String entryPageInput = _getEntryPageInput();
  String entryPageClass = _toPascalCase(entryPageInput);
  String entryPageFileName = "${entryPageInput}_page.dart";
  String entryPageFolder = entryPageInput;

  bool useFlavors = _getYesNoInput("Would you like to add flavors? (y/n): ");
  List<String> flavors = [];
  Map<String, String> baseUrls = {};
  String baseBundleId = "";

  if (useFlavors) {
    flavors = _getFlavors();
    if (flavors.isEmpty) {
      print("⚠️ No flavors provided. Exiting.");
      return;
    }
    baseBundleId = _getBaseBundleId();
    baseUrls = _getBaseUrls(flavors);
  }

  bool addVSCodeConfig = _getYesNoInput(
    "Would you like to add VSCode configuration files? (y/n): ",
  );

  print("\n🛠 Generating project structure...\n");

  await _setupProject(
    entryPageClass,
    entryPageFolder,
    entryPageFileName,
    useFlavors,
    flavors,
    baseUrls,
    baseBundleId,
    addVSCodeConfig,
  );

  print(
    "\n🎉 Setup Complete! Run `flutter run ${useFlavors ? '--flavor <flavor>' : ''}` to test.",
  );
  print("🤝 Happy coding! Hope this setup makes your development smoother.");
}

Future<bool> _ensureFvmInstalled() async {
  bool fvmInstalled = await _checkFvmInstallation();
  if (!fvmInstalled) {
    await _handleFvmInstallation();
    return false;
  }
  return true;
}

String _getEntryPageInput() {
  stdout.write("Enter the name of your entry page (default: intro): ");
  String input = stdin.readLineSync()?.trim().toLowerCase() ?? "intro";
  return input.isEmpty ? "intro" : input;
}

bool _getYesNoInput(String prompt) {
  stdout.write(prompt);
  return stdin.readLineSync()?.trim().toLowerCase() == 'y';
}

List<String> _getFlavors() {
  stdout.write("Enter flavors (comma-separated, e.g., dev,uat,prod): ");
  String? input = stdin.readLineSync();
  return input?.split(",").map((e) => e.trim().toLowerCase()).toList() ?? [];
}

String _getBaseBundleId() {
  stdout.write("Enter base Bundle ID (e.g., com.example.app): ");
  return stdin.readLineSync()?.trim() ?? "com.example.app";
}

Map<String, String> _getBaseUrls(List<String> flavors) {
  Map<String, String> baseUrls = {};
  for (var flavor in flavors) {
    stdout.write("Enter Base URL for $flavor: ");
    baseUrls[flavor] = stdin.readLineSync() ?? "";
  }
  return baseUrls;
}

Future<void> _setupProject(
  String entryPageClass,
  String entryPageFolder,
  String entryPageFileName,
  bool useFlavors,
  List<String> flavors,
  Map<String, String> baseUrls,
  String baseBundleId,
  bool addVSCodeConfig,
) async {
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
    Map<String, String> packageIds = _generatePackageIds(flavors, baseBundleId);
    await _updateConfigFile(flavors, baseUrls);
    await _generateMainFiles(flavors);
    await _updateAndroidFiles(flavors, packageIds);
    await _updateIOSFiles(flavors, packageIds);
    _removeMainFile(); // Remove main.dart if flavors are added
  }

  if (addVSCodeConfig) {
    await _createVSCodeFiles(flavors);
  }
}

Map<String, String> _generatePackageIds(
  List<String> flavors,
  String baseBundleId,
) {
  return {
    for (var flavor in flavors)
      flavor: flavor == 'prod' ? baseBundleId : "$baseBundleId.$flavor",
  };
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
  stdout.write(
    "FVM (Flutter Version Management) is not installed. Would you like to install it? (y/n): ",
  );
  bool installFvm = (stdin.readLineSync()?.trim().toLowerCase() == 'y');

  if (!installFvm) {
    print(
      "⚠️ Skipping FVM installation. Note that some features may not work correctly.",
    );
    return;
  }

  print("🔧 Installing FVM...");

  // Install FVM using dart pub global activate
  try {
    Process.runSync('dart', ['pub', 'global', 'activate', 'fvm']);
    print("✅ FVM installed successfully!");

    // Add FVM to PATH instructions
    print(
      "ℹ️ Make sure FVM is in your PATH. You might need to add the following to your profile:",
    );
    print("  export PATH=\"\$PATH:\$HOME/.pub-cache/bin\"");

    // Install Flutter version using FVM
    stdout.write("Would you like to install Flutter 3.29.2 using FVM? (y/n): ");
    bool installFlutter = (stdin.readLineSync()?.trim().toLowerCase() == 'y');

    if (installFlutter) {
      print(
        "🔧 Installing Flutter 3.29.2 using FVM (this may take a while)...",
      );
      Process.runSync('fvm', ['install', '3.29.2']);
      Process.runSync('fvm', ['use', '3.29.2']);
      print("✅ Flutter 3.29.2 installed successfully!");

      // Suggest VS Code restart
      stdout.write(
        "Would you like to restart VS Code to apply FVM settings? (y/n): ",
      );
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
        print(
          "✅ VS Code has been restarted. Please run this setup script again.",
        );
        exit(0);
      }
    }
  } catch (e) {
    print("⚠️ Failed to install FVM: $e");
    print(
      "ℹ️ Please install FVM manually: https://fvm.app/docs/getting_started/installation",
    );
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
    - lib/di/locator.dart
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
  print("✅ Created analysis_options.yaml with code quality rules");
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
import 'locator.dart';
import 'routes/router.dart';
import 'config.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = locator<AppRouter>();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: locator<Config>().appName,
      routerConfig: router.config(),
    );
  }
}
''';

  Directory("lib/di").createSync(recursive: true);
  Directory("lib/routes").createSync(recursive: true);

  File("lib/app.dart").writeAsStringSync(content);
  print("✅ Created lib/app.dart");
}

/// Generates `lib/routes/router.dart`
Future<void> _generateRouterFile(
  String entryPageClass,
  String entryPageFolder,
  String entryPageFileName,
) async {
  String content = '''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

part 'router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route,Tab')
class AppRouter extends _\$AppRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: ${entryPageClass}PageRoute.page, initial: true),
      ];
      
  // Add modalSheetBuilder to fix the error
  @override
  Route<T> modalSheetBuilder<T>(
    BuildContext context,
    Widget child,
    AutoRoutePage<T> page,
  ) {
    return ModalBottomSheetRoute(
      settings: page,
      builder: (context) => child,
      isScrollControlled: true,
    );
  }
}

// The route will be auto-generated by build_runner
@RoutePage()
class ${entryPageClass}Page extends StatelessWidget {
  const ${entryPageClass}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$entryPageClass Page')),
      body: const Center(child: Text('Welcome to $entryPageClass!')),
    );
  }
}
''';

  File("lib/routes/router.dart").writeAsStringSync(content);
  print("✅ Updated lib/routes/router.dart with correct route naming.");

  // Also create the page separately
  Directory(
    "lib/presentation/screens/$entryPageFolder",
  ).createSync(recursive: true);

  String pageContent = '''
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
  ).writeAsStringSync(pageContent);
  print(
    "✅ Created lib/presentation/screens/$entryPageFolder/$entryPageFileName",
  );
}

/// Generates `lib/locator.dart`
Future<void> _generateLocatorFile() async {
  String content = '''
import 'package:get_it/get_it.dart';
import 'routes/router.dart';
import 'config.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register router
  locator.registerSingleton<AppRouter>(AppRouter());
  
  // Register config
  locator.registerSingleton<Config>(Config());
  
  // Register services and repositories here
}
''';

  File("lib/locator.dart").writeAsStringSync(content);
  print("✅ Created lib/locator.dart");
}

/// Creates presentation structure and entry page
Future<void> _generatePresentationFiles(
  String entryPageClass,
  String entryPageFolder,
  String entryPageFileName,
) async {
  // This is now handled in the router file generation
  // We're keeping the method in case we need to add more presentation files
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

  // New dependencies to add with specified versions
  Map<String, String?> newDependencies = {
    "auto_route": null, // No version defined
    "get_it": "^8.0.0",
    "flutter_bloc": "^8.1.6",
    "equatable": "^2.0.7",
    "dio": "^5.7.0",
  };

  // New dev_dependencies to add
  Map<String, String> newDevDependencies = {
    "auto_route_generator": "^8.0.0",
    "build_runner": "^2.4.12",
    "json_serializable": "^6.8.0",
    "freezed": "^2.5.7",
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
          finalLines.add(
            entry.value == null
                ? "  ${entry.key}:"
                : "  ${entry.key}: ${entry.value}",
          );
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

/// Updates `lib/config.dart`
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

  File("lib/config.dart").writeAsStringSync(content);
  print("✅ Created lib/config.dart");
}

/// Generates `main_<flavor>.dart` for each flavor
Future<void> _generateMainFiles(List<String> flavors) async {
  String mainContent = '''
import 'package:flutter/material.dart';
import 'config.dart';
import 'locator.dart';
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
import 'config.dart';
import 'locator.dart';
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
  print("🔧 Setting up iOS flavors...");

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

  // Update Xcode project configurations
  await _updateXcodeBuildConfigurations(flavors);

  // Generate xcodegen configuration file
  await _generateXcodegenConfig(flavors, packageIds);

  // Run xcodegen to generate the Xcode project
  await _runXcodegen();
}

/// Updates Xcode build configurations for flavors
Future<void> _updateXcodeBuildConfigurations(List<String> flavors) async {
  String pbxprojPath = "ios/Runner.xcodeproj/project.pbxproj";

  if (!File(pbxprojPath).existsSync()) {
    print("⚠️ Xcode project file not found at $pbxprojPath. Skipping build configuration setup.");
    return;
  }

  String pbxprojContent = File(pbxprojPath).readAsStringSync();

  for (var flavor in flavors) {
    // Duplicate Debug, Release, and Profile configurations for each flavor
    for (var config in ['Debug', 'Release', 'Profile']) {
      String originalConfig = "$config /* $config */";
      String newConfig = "$config-$flavor /* $config-$flavor */";

      if (!pbxprojContent.contains(newConfig)) {
        pbxprojContent = pbxprojContent.replaceFirst(
          originalConfig,
          "$originalConfig\n        $newConfig",
        );

        String buildSettings = '''
        $newConfig = {
          isa = XCBuildConfiguration;
          buildSettings = {
            PRODUCT_NAME = "Runner";
            CONFIGURATION_BUILD_DIR = "\$(BUILD_DIR)/\$(CONFIGURATION)/$flavor";
          };
          name = $config-$flavor;
        };
        ''';

        pbxprojContent = pbxprojContent.replaceFirst(
          "/* End XCBuildConfiguration section */",
          "$buildSettings\n/* End XCBuildConfiguration section */",
        );
      }
    }
  }

  // Write the updated content back to the pbxproj file
  File(pbxprojPath).writeAsStringSync(pbxprojContent);
  print("✅ Updated Xcode build configurations for flavors.");
}

/// Generates the xcodegen configuration file
Future<void> _generateXcodegenConfig(
  List<String> flavors,
  Map<String, String> packageIds,
) async {
  String configContent = '''
name: Runner
options:
  bundleIdPrefix: com.example
  createIntermediateGroups: true
configs:
${flavors.map((flavor) => '''
  ${flavor}-Debug:
    type: debug
  ${flavor}-Release:
    type: release
''').join('')}
schemes:
${flavors.map((flavor) => '''
  ${flavor}:
    build:
      targets:
        Runner:
          buildTypes: [${flavor}-Debug, ${flavor}-Release]
    run:
      config: ${flavor}-Debug
''').join('')}
targets:
  Runner:
    type: application
    platform: iOS
    sources: [Runner]
    configFiles:
${flavors.map((flavor) => '''
      ${flavor}-Debug: Flutter/flavors/${flavor}.xcconfig
      ${flavor}-Release: Flutter/flavors/${flavor}.xcconfig
''').join('')}
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: ${packageIds['prod']}
''';

  File("ios/project.yml").writeAsStringSync(configContent);
  print("✅ Created ios/project.yml for xcodegen with matching schemes and flavors.");
}

/// Runs xcodegen to generate the Xcode project
Future<void> _runXcodegen() async {
  print("🔧 Checking if xcodegen is installed...");
  bool isXcodegenInstalled = _isXcodegenInstalled();

  if (!isXcodegenInstalled) {
    stdout.write("⚠️ xcodegen is not installed. Would you like to install it? (y/n): ");
    bool installXcodegen = stdin.readLineSync()?.trim().toLowerCase() == 'y';

    if (!installXcodegen) {
      print("⚠️ xcodegen is required to generate the Xcode project. Exiting.");
      _provideManualXcodeSetupGuide();
      return;
    }

    print("🔧 Installing xcodegen...");
    try {
      ProcessResult result = Process.runSync('brew', ['install', 'xcodegen']);
      if (result.exitCode == 0) {
        print("✅ xcodegen installed successfully.");
      } else {
        print("⚠️ Failed to install xcodegen: ${result.stderr}");
        _provideManualXcodeSetupGuide();
        return;
      }
    } catch (e) {
      print("⚠️ Homebrew is not installed or an error occurred: $e");
      print("ℹ️ Please install Homebrew (https://brew.sh/) and try again.");
      _provideManualXcodeSetupGuide();
      return;
    }
  }

  print("🔧 Running xcodegen to generate Xcode project...");
  try {
    ProcessResult result = Process.runSync('xcodegen', ['generate', '--project', 'ios']);
    if (result.exitCode == 0) {
      print("✅ Successfully generated Xcode project using xcodegen.");
    } else {
      print("⚠️ Failed to run xcodegen: ${result.stderr}");
      _provideManualXcodeSetupGuide();
    }
  } catch (e) {
    print("⚠️ An error occurred while running xcodegen: $e");
    _provideManualXcodeSetupGuide();
  }
}

/// Provides a step-by-step guide for manual Xcode flavor setup
void _provideManualXcodeSetupGuide() {
  print("\n⚠️ Manual Xcode Flavor Setup Required:");
  print("1. Open `ios/Runner.xcodeproj` in Xcode.");
  print("2. Go to the `Product` menu and select `Scheme` > `Manage Schemes...`.");
  print("3. For each flavor (e.g., `dev`, `uat`, `prod`):");
  print("   a. Duplicate the existing `Runner` scheme.");
  print("   b. Rename the scheme to match the flavor name exactly (e.g., `dev`, `uat`, `prod`).");
  print("4. Edit each scheme:");
  print("   a. Select the scheme and click `Edit...`.");
  print("   b. Under the `Build` section, set the `Build Configuration` to:");
  print("      - `Debug-<flavor>` for the `Run` action.");
  print("      - `Release-<flavor>` for the `Archive` action.");
  print("      - `Profile-<flavor>` for the `Profile` action.");
  print("   c. Ensure the `Info.plist` file is set to the corresponding flavor's configuration.");
  print("5. Duplicate the `Debug`, `Release`, and `Profile` build configurations:");
  print("   a. In the Xcode project navigator, select the `Runner` project.");
  print("   b. Go to the `Info` tab.");
  print("   c. Duplicate the `Debug`, `Release`, and `Profile` configurations for each flavor:");
  print("      - Rename them to `Debug-<flavor>`, `Release-<flavor>`, and `Profile-<flavor>`.");
  print("   d. Update the `Build Settings` for each configuration to use the corresponding flavor's `xcconfig` file.");
  print("6. Update the `Info.plist` file for each flavor if needed (e.g., app name, icons).");
  print("7. Ensure the schemes are shared:");
  print("   a. In the `Manage Schemes...` window, check the `Shared` checkbox for each scheme.");
  print("8. Save the changes and close Xcode.");
  print("9. Build and run the app using the appropriate scheme.");
  print("\nℹ️ For more details, refer to the Flutter documentation on flavors: https://docs.flutter.dev/deployment/flavors");
}

/// Checks if xcodegen is installed
bool _isXcodegenInstalled() {
  try {
    ProcessResult result = Process.runSync('xcodegen', ['--version']);
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}

/// Removes the default main.dart file if flavors are added
void _removeMainFile() {
  File mainFile = File("lib/main.dart");
  if (mainFile.existsSync()) {
    mainFile.deleteSync();
    print("🗑️ Removed lib/main.dart as flavors are added.");
  }
}
