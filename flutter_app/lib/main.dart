import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

part 'domain/entities.dart';
part 'domain/access.dart';
part 'domain/metrics.dart';
part 'domain/sync.dart';
part 'data/record_store.dart';
part 'data/seed_data.dart';
part 'data/sync_queue.dart';
part 'services/sync_coordinator.dart';
part 'presentation/screens.dart';
part 'presentation/widgets.dart';

const _recordsBox = 'daily_records';
const _maintenanceRecordsBox = 'maintenance_records';
const _metaBox = 'meta';
const _syncQueueBox = 'sync_queue';
const _syncFileName = 'control_tuk_tuk_backup.json';
const _seedVersion = 'earnings-odometer-charge80v-maintenance-2026-07-03';
const _defaultMaintenanceIntervalKm = 5000.0;
const _databaseSchemaVersion = 3;

const kBg = Color(0xFF080D14);
const kSurface = Color(0xFF111923);
const kSurfaceHigh = Color(0xFF182331);
const kOutline = Color(0xFF29384A);
const kPrimary = Color(0xFF2DD4A3);
const kSecondary = Color(0xFF70A7FF);
const kTertiary = Color(0xFFF59E0B);
const kText = Color(0xFFF5F8FC);
const kMuted = Color(0xFF93A2B5);
const kDanger = Color(0xFFFB7185);
const kAccentPink = Color(0xFFF472B6);
const kCardGradientTop = Color(0xFF151F2B);
const kCardGradientBottom = Color(0xFF0D141D);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  await Hive.initFlutter();
  await Hive.openBox(_recordsBox);
  await Hive.openBox(_maintenanceRecordsBox);
  await Hive.openBox(_metaBox);
  await Hive.openBox(_syncQueueBox);
  runApp(const ControlTukTukApp());
}

class ControlTukTukApp extends StatelessWidget {
  const ControlTukTukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TukTuk Control',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary,
          secondary: kSecondary,
          tertiary: kTertiary,
          surface: kSurface,
          error: kDanger,
        ),
        fontFamily: 'Roboto',
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            color: kText,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
          titleMedium: TextStyle(color: kText, fontWeight: FontWeight.w800),
          bodyMedium: TextStyle(color: kText, height: 1.35),
          bodySmall: TextStyle(color: kMuted, height: 1.35),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: kBg,
          foregroundColor: kText,
          titleTextStyle: TextStyle(
            color: kText,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: const Color(0xFF06251C),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kSecondary,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kSecondary,
            side: const BorderSide(color: Color(0xFF35506B)),
            minimumSize: const Size.fromHeight(46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: kSurfaceHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: kSurfaceHigh,
          contentTextStyle: const TextStyle(color: kText),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          behavior: SnackBarBehavior.floating,
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 76,
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: kPrimary.withValues(alpha: .18),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? kPrimary : kMuted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? kPrimary : kMuted,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurfaceHigh,
          labelStyle: const TextStyle(color: kMuted),
          prefixIconColor: kSecondary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF263241)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF263241)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kPrimary, width: 1.5),
          ),
        ),
      ),
      home: const AppShell(),
    );
  }
}
