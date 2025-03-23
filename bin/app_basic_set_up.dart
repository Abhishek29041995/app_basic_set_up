import 'dart:io';

void main() async {
  print("🚀 Welcome to Flutter App Setup CLI!");

  stdout.write("Enter the name of your entry page (default: HomePage): ");
  String entryPage = stdin.readLineSync()?.trim() ?? "HomePage";
  if (entryPage.isEmpty) entryPage = "HomePage";

  // Ask user if they want to use flavors
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

  await _generateAppFile();
  await _generateRouterFile(entryPage);
  await _generateLocatorFile();
  await _generatePresentationFiles(entryPage);

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
  File appFile = File("lib/app.dart");
  String content = '''
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'locator.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [], // Add BLoC providers here
      child: MaterialApp.router(
        title: 'Flutter App',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter.config(),
      ),
    );
  }
}
''';
  appFile.writeAsStringSync(content);
  print("✅ Created lib/app.dart");
}

/// Generates `lib/router.dart`
Future<void> _generateRouterFile(String entryPage) async {
  File routerFile = File("lib/router.dart");
  String content = '''
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'presentation/pages/$entryPage.dart';

part 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends \$AppRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: $entryPage, initial: true),
      ];
}

final appRouter = AppRouter();
''';
  routerFile.writeAsStringSync(content);
  print("✅ Created lib/router.dart");
}

/// Generates `lib/locator.dart`
Future<void> _generateLocatorFile() async {
  File locatorFile = File("lib/locator.dart");
  String content = '''
import 'package:get_it/get_it.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Register services, repositories, and BLoCs here
}
''';
  locatorFile.writeAsStringSync(content);
  print("✅ Created lib/locator.dart");
}

/// Generates `lib/presentation/pages/<entryPage>.dart`
Future<void> _generatePresentationFiles(String entryPage) async {
  Directory("lib/presentation/pages").createSync(recursive: true);

  File entryPageFile = File("lib/presentation/pages/$entryPage.dart");
  String content = '''
import 'package:flutter/material.dart';

class $entryPage extends StatelessWidget {
  const $entryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$entryPage')),
      body: const Center(child: Text('Welcome to $entryPage!')),
    );
  }
}
''';
  entryPageFile.writeAsStringSync(content);
  print("✅ Created lib/presentation/pages/$entryPage.dart");
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
import 'app.dart';

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
