import 'dart:io';

void main() async {
  print("🚀 Welcome to Flavor Setup CLI!");

  // Step 1: Ask user for flavor names
  stdout.write("Enter flavors (comma-separated, e.g., dev,uat,prod): ");
  String? flavorsInput = stdin.readLineSync();
  List<String> flavors =
      flavorsInput?.split(",").map((e) => e.trim()).toList() ?? [];

  if (flavors.isEmpty) {
    print("⚠️ No flavors provided. Exiting.");
    return;
  }

  Map<String, String> baseUrls = {};
  Map<String, String> packageIds = {};

  for (var flavor in flavors) {
    stdout.write("Enter Base URL for $flavor: ");
    baseUrls[flavor] = stdin.readLineSync() ?? "";

    stdout.write(
      "Enter Bundle ID for $flavor (e.g., com.example.app.$flavor): ",
    );
    packageIds[flavor] = stdin.readLineSync() ?? "";
  }

  print("\n🛠 Generating flavor setup...\n");
  await _updateConfigFile(flavors, baseUrls);
  await _updateAndroidFiles(flavors, packageIds);
  await _updateIOSFiles(flavors, packageIds);
  await _generateMainFiles(flavors);

  print("\n✅ Flavor setup completed!");
}

/// Updates `lib/config.dart`
Future<void> _updateConfigFile(
  List<String> flavors,
  Map<String, String> baseUrls,
) async {
  File configFile = File("lib/config.dart");

  String content = '''
enum Flavor { ${flavors.join(", ")} }

class Config {
  static Flavor appFlavor = Flavor.${flavors.first};

  static String get baseUrl {
    switch (appFlavor) {
      ${flavors.map((f) => 'case Flavor.$f: return "${baseUrls[f]}";').join("\n      ")}
    }
  }
}
  ''';

  configFile.writeAsStringSync(content);
  print("✅ Updated lib/config.dart");
}

/// Generates `main_<flavor>.dart` files
Future<void> _generateMainFiles(List<String> flavors) async {
  for (var flavor in flavors) {
    File mainFile = File('lib/main_$flavor.dart');
    String content = '''
import 'package:flutter/material.dart';
import 'config.dart';
import 'app.dart'; // Ensure this file exists in your project

void main() {
  Config.appFlavor = Flavor.$flavor;
  runApp(const App());
}
''';

    mainFile.writeAsStringSync(content);
    print("✅ Created lib/main_$flavor.dart");
  }
}

/// Updates `android/app/build.gradle`
Future<void> _updateAndroidFiles(
  List<String> flavors,
  Map<String, String> packageIds,
) async {
  File gradleFile = File("android/app/build.gradle");

  if (!gradleFile.existsSync()) {
    print("⚠️ Android build.gradle not found. Skipping.");
    return;
  }

  String flavorConfig = flavors
      .map(
        (f) => '''
        $f {
            applicationId "${packageIds[f]}"
            dimension "flavor"
        }''',
      )
      .join("\n");

  String gradleContent = '''
android {
    flavorDimensions "flavor"
    productFlavors {
        $flavorConfig
    }
}
  ''';

  gradleFile.writeAsStringSync(gradleContent, mode: FileMode.append);
  print("✅ Updated android/app/build.gradle");
}

/// Updates iOS Xcode configuration
Future<void> _updateIOSFiles(
  List<String> flavors,
  Map<String, String> packageIds,
) async {
  String iosProjectPath = "ios/Runner.xcodeproj/project.pbxproj";
  File iosProjectFile = File(iosProjectPath);

  if (!iosProjectFile.existsSync()) {
    print("⚠️ iOS project file not found. Skipping iOS setup.");
    return;
  }

  String iosContent = iosProjectFile.readAsStringSync();
  for (var flavor in flavors) {
    if (!iosContent.contains("XCBuildConfiguration = $flavor")) {
      iosContent += '''
        XCBuildConfiguration = {
          name = $flavor;
          buildSettings = {
            PRODUCT_BUNDLE_IDENTIFIER = ${packageIds[flavor]};
          };
        };
      ''';
    }
  }

  iosProjectFile.writeAsStringSync(iosContent);
  print("✅ Updated iOS Xcode project for flavors.");
}
