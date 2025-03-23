import 'dart:io';

void main() async {
  print("🚀 Welcome to Flutter App Setup CLI!");

  stdout.write("Enter the name of your entry page (default: Intro): ");
  String entryPage = stdin.readLineSync()?.trim() ?? "Intro";
  if (entryPage.isEmpty) entryPage = "Intro";

  stdout.write("Would you like to add flavors? (y/n): ");
  bool useFlavors = (stdin.readLineSync()?.trim().toLowerCase() == 'y');

  List<String> flavors = [];
  Map<String, String> baseUrls = {};
  Map<String, String> packageIds = {};

  if (useFlavors) {
    stdout.write("Enter flavors (comma-separated, e.g., dev,uat,prod): ");
    String? flavorsInput = stdin.readLineSync();
    flavors = flavorsInput?.split(",").map((e) => e.trim()).toList() ?? [];

    if (flavors.isEmpty) {
      print("⚠️ No flavors provided. Exiting.");
      return;
    }

    for (var flavor in flavors) {
      stdout.write("Enter Base URL for $flavor: ");
      baseUrls[flavor] = stdin.readLineSync() ?? "";

      stdout.write(
        "Enter Bundle ID for $flavor (e.g., com.example.app.$flavor): ",
      );
      packageIds[flavor] = stdin.readLineSync() ?? "";
    }
  }

  print("\n🛠 Generating project structure...\n");

  await _updatePubspec();
  await _runPubGet();
  await _generateAppFile();
  await _generateRouterFile(entryPage);
  await _generateLocatorFile();
  await _generatePresentationFiles(entryPage);
  await _runBuildRunner();

  if (useFlavors) {
    await _updateConfigFile(flavors, baseUrls);
    await _generateMainFiles(flavors);
    await _updateAndroidFiles(flavors, packageIds);
    await _updateIOSFiles(flavors, packageIds);
  }

  print(
    "\n🎉 Setup Complete! Run `flutter run ${useFlavors ? '--flavor <flavor>' : ''}` to test.",
  );
  print("🤝 Happy coding! Hope this setup makes your development smoother.");
}

/// Generates `lib/app.dart`
Future<void> _generateAppFile() async {
  String content = '''
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'locator.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = locator<AppRouter>();
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "Flutter App",
      routerConfig: router.config(),
    );
  }
}
''';

  File("lib/app.dart").writeAsStringSync(content);
  print("✅ Created lib/app.dart");
}

/// Generates `lib/router.dart`
Future<void> _generateRouterFile(String entryPage) async {
  String content = '''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'presentation/pages/$entryPage.dart';

part 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends \$AppRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: $entryPage.page, initial: true),
      ];
}

@RoutePage()
class $entryPage extends StatelessWidget {
  const $entryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("$entryPage Page")),
      body: const Center(child: Text("Welcome to $entryPage!")),
    );
  }
}
''';

  File("lib/router.dart").writeAsStringSync(content);
  print("✅ Created lib/router.dart");
}

/// Generates `lib/locator.dart`
Future<void> _generateLocatorFile() async {
  String content = '''
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register services and repositories here
}
''';

  File("lib/locator.dart").writeAsStringSync(content);
  print("✅ Created lib/locator.dart");
}

/// Creates `presentation/pages` folder and entry page
Future<void> _generatePresentationFiles(String entryPage) async {
  Directory("lib/presentation/pages").createSync(recursive: true);

  String content = '''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class $entryPage extends StatelessWidget {
  const $entryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("$entryPage Page")),
      body: const Center(child: Text("Welcome to $entryPage!")),
    );
  }
}
''';

  File("lib/presentation/pages/$entryPage.dart").writeAsStringSync(content);
  print("✅ Created lib/presentation/pages/$entryPage.dart");
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

  // New dependencies to add
  Map<String, String> newDependencies = {
    "auto_route": "^7.8.4",
    "get_it": "^7.6.7",
    "flutter_bloc": "^8.1.3",
  };

  // New dev_dependencies to add
  Map<String, String> newDevDependencies = {
    "auto_route_generator": "^8.0.0",
    "build_runner": "^2.3.3",
    "json_serializable": "^6.6.1",
    "freezed": "^2.3.2",
  };

  // Track which dependencies exist
  Set<String> existingDependencies = {};
  Set<String> existingDevDependencies = {};

  for (String line in lines) {
    String trimmed = line.trim();

    if (trimmed.startsWith("dependencies:")) {
      inDependencies = true;
      inDevDependencies = false;
      dependenciesUpdated = true;
    } else if (trimmed.startsWith("dev_dependencies:")) {
      inDependencies = false;
      inDevDependencies = true;
      devDependenciesUpdated = true;
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

  // Append missing dependencies to the correct section
  if (dependenciesUpdated) {
    for (var entry in newDependencies.entries) {
      if (!existingDependencies.contains(entry.key)) {
        updatedLines.add("  ${entry.key}: ${entry.value}");
      }
    }
  } else {
    updatedLines.add("\ndependencies:");
    for (var entry in newDependencies.entries) {
      updatedLines.add("  ${entry.key}: ${entry.value}");
    }
  }

  if (devDependenciesUpdated) {
    for (var entry in newDevDependencies.entries) {
      if (!existingDevDependencies.contains(entry.key)) {
        updatedLines.add("  ${entry.key}: ${entry.value}");
      }
    }
  } else {
    updatedLines.add("\ndev_dependencies:");
    for (var entry in newDevDependencies.entries) {
      updatedLines.add("  ${entry.key}: ${entry.value}");
    }
  }

  // Write back the modified content
  pubspecFile.writeAsStringSync(updatedLines.join("\n"));
  print("✅ Successfully updated pubspec.yaml without duplicates.");
}

/// Updates `config.dart`
Future<void> _updateConfigFile(
  List<String> flavors,
  Map<String, String> baseUrls,
) async {
  String content = '''
enum Flavor { ${flavors.join(', ')} }

class Config {
  static Flavor appFlavor = Flavor.${flavors.first};

  static String get baseUrl {
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
  for (var flavor in flavors) {
    String content = '''
import 'package:flutter/material.dart';
import 'config.dart';
import 'app.dart';

void main() {
  Config.appFlavor = Flavor.$flavor;
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

  String flavorConfig = "flavorDimensions \"flavor\"\nproductFlavors {";
  for (var flavor in flavors) {
    flavorConfig += '''
      $flavor {
        dimension "flavor"
        applicationId "${packageIds[flavor]}"
      }
    ''';
  }
  flavorConfig += "}";

  if (!gradleContent.contains("productFlavors")) {
    gradleFile.writeAsStringSync(gradleContent + "\n$flavorConfig");
    print("✅ Modified android/app/build.gradle for flavors.");
  }
}

/// Updates `ios/Runner.xcodeproj/project.pbxproj` for flavors
Future<void> _updateIOSFiles(
  List<String> flavors,
  Map<String, String> packageIds,
) async {
  String iosPath = "ios/Runner.xcodeproj/project.pbxproj";
  File iosFile = File(iosPath);

  if (!iosFile.existsSync()) {
    print("⚠️ iOS project file not found. Skipping iOS setup.");
    return;
  }

  String iosContent = iosFile.readAsStringSync();
  for (var flavor in flavors) {
    if (!iosContent.contains(flavor)) {
      iosContent += '''
        $flavor {
          PRODUCT_BUNDLE_IDENTIFIER = ${packageIds[flavor]};
        }
      ''';
    }
  }
  iosFile.writeAsStringSync(iosContent);
  print("✅ Updated iOS Xcode project for flavors.");
}
