# Copilot instructions for realtorone

## Project snapshot
- This is a stock Flutter app scaffold. The only app code lives in [lib/main.dart](lib/main.dart) and uses a `MaterialApp` with a `StatefulWidget` counter demo.
- Tests are the default widget smoke test in [test/widget_test.dart](test/widget_test.dart).
- Linting is configured via `flutter_lints` in [analysis_options.yaml](analysis_options.yaml).
- Dependencies are minimal: `flutter` + `cupertino_icons` in [pubspec.yaml](pubspec.yaml).

## Architecture & patterns
- No custom layers or folders exist yet (no `models/`, `services/`, or `screens/`). Keep changes consistent with a single-file app unless you introduce new structure intentionally.
- App entry point is `main()` in [lib/main.dart](lib/main.dart). `MyApp` is the root widget and `MyHomePage` owns state via `StatefulWidget`.
- UI is pure Material components; the theme uses `ThemeData` with `colorScheme` derived from a seed color.

## Developer workflows (documented in code comments)
- Run the app with `flutter run` (referenced in comments inside [lib/main.dart](lib/main.dart)).
- Analyzer/lints are enabled via `flutter analyze` (documented in [analysis_options.yaml](analysis_options.yaml)).
- Widget tests can be run with `flutter test` and are currently limited to the counter smoke test in [test/widget_test.dart](test/widget_test.dart).

## When editing or adding code
- Preserve the current app entry wiring: `runApp(const MyApp())` and `MaterialApp(home: ...)` in [lib/main.dart](lib/main.dart).
- If you add screens or state, be explicit about new folders and update imports in [lib/main.dart](lib/main.dart) and [test/widget_test.dart](test/widget_test.dart).
- Keep widget tests using `flutter_test` and `WidgetTester` patterns, matching the existing test style in [test/widget_test.dart](test/widget_test.dart).
