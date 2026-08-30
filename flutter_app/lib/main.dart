import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'services/push_notification_service.dart';
import 'services/push_token_registration_coordinator.dart';
import 'services/install_referrer_service.dart';
import 'services/referral_link_listener.dart';
import 'services/referral_share.dart';

part 'domain/entities.dart';
part 'domain/access.dart';
part 'domain/saas_foundation.dart';
part 'domain/metrics.dart';
part 'domain/referrals.dart';
part 'domain/sync.dart';
part 'data/referral_service.dart';
part 'data/record_store.dart';
part 'data/seed_data.dart';
part 'data/sync_queue.dart';
part 'data/supabase_license_service.dart';
part 'data/supabase_sync_gateway.dart';
part 'data/whatsapp_settings_service.dart';
part 'services/sync_coordinator.dart';
part 'presentation/screens.dart';
part 'presentation/widgets.dart';

const _recordsBox = 'daily_records';
const _maintenanceRecordsBox = 'maintenance_records';
const _metaBox = 'meta';
const _syncQueueBox = 'sync_queue';
const _seedVersion = 'earnings-odometer-charge80v-maintenance-2026-07-03';
const _defaultMaintenanceIntervalKm = 5000.0;
const _databaseSchemaVersion = 5;
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://vvxvnywzgtqhlaqpxyqh.supabase.co',
);
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: 'sb_publishable_MOmcX334dezcrlRAaQlvbg_Scd-RJTV',
);
const _supabaseMobileRedirect =
    'com.alejandrocruz.tuktukcontrol://login-callback/';
const _projectId = String.fromEnvironment(
  'PROJECT_ID',
  defaultValue: 'dfb41cea-a812-46f2-b511-7a60bd3d78af',
);

const kBg = Color(0xFF080D14);
const kSurface = Color(0xFF111923);
const kSurfaceHigh = Color(0xFF182331);
const kOutline = Color(0xFF29384A);
const kPrimary = Color(0xFF2DD4A3);
const kSecondary = Color(0xFF00CFA0);
const kTertiary = Color(0xFFFFC400);
const kText = Color(0xFFF5F8FC);
const kMuted = Color(0xFF93A2B5);
const kDanger = Color(0xFFFB7185);
const kAccentPink = Color(0xFFFFA800);
const kCardGradientTop = Color(0xFF151F2B);
const kCardGradientBottom = Color(0xFF0D141D);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final referralAppLinks = kIsWeb ? null : AppLinks();
  for (final locale in ['es', 'en', 'pt', 'fr']) {
    await initializeDateFormatting(locale);
  }
  Intl.defaultLocale = 'es';
  await Hive.initFlutter();
  await Hive.openBox(_recordsBox);
  await Hive.openBox(_maintenanceRecordsBox);
  await Hive.openBox(_metaBox);
  await Hive.openBox(_syncQueueBox);
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  final pushNotifications = PushNotificationService();
  await pushNotifications.initialize(onMessageOpened: openPushMessageAction);
  final pushTokenCoordinator = PushTokenRegistrationCoordinator.supabase(
    client: Supabase.instance.client,
    cache: Hive.box(_metaBox),
    tokenProvider: pushNotifications.getToken,
  );
  pushTokenCoordinator.listenToTokenRefreshes(pushNotifications.tokenRefreshes);
  runApp(
    ControlTukTukApp(
      store: RecordStore(
        pushTokenCoordinator: pushTokenCoordinator,
        referralAppLinks: referralAppLinks,
      ),
    ),
  );
}

class ControlTukTukApp extends StatefulWidget {
  const ControlTukTukApp({required this.store, super.key});

  final RecordStore store;

  @override
  State<ControlTukTukApp> createState() => _ControlTukTukAppState();
}

class _ControlTukTukAppState extends State<ControlTukTukApp>
    with WidgetsBindingObserver {
  RecordStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        activeCurrency = store.preferredCurrency;
        activeLanguage = store.preferredLanguage;
        Intl.defaultLocale = activeLanguage;
        final themeMode = switch (store.preferredTheme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'TukTuk Control',
          themeMode: themeMode,
          theme: _appTheme(Brightness.light),
          darkTheme: _appTheme(Brightness.dark),
          home: AppShell(store: store),
        );
      },
    );
  }

  ThemeData _appTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? kBg : const Color(0xFFF3F7FC);
    final surface = dark ? kSurface : Colors.white;
    final surfaceHigh = dark ? kSurfaceHigh : const Color(0xFFE8F0F8);
    final text = dark ? kText : const Color(0xFF142033);
    final muted = dark ? kMuted : const Color(0xFF5E7087);
    final outline = dark ? const Color(0xFF263241) : const Color(0xFFCBD8E7);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: kPrimary,
        primary: kPrimary,
        secondary: kSecondary,
        surface: surface,
      ),
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          color: text,
          fontWeight: FontWeight.w900,
          letterSpacing: -.4,
        ),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w800),
        bodyMedium: TextStyle(color: text, height: 1.35),
        bodySmall: TextStyle(color: muted, height: 1.35),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: text,
        titleTextStyle: TextStyle(
          color: text,
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
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: dark ? kSurfaceHigh : const Color(0xFF203147),
        contentTextStyle: const TextStyle(color: Colors.white),
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
            color: states.contains(WidgetState.selected) ? kPrimary : muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? kPrimary : muted,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        labelStyle: TextStyle(color: muted),
        prefixIconColor: kSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
      ),
    );
  }
}

String activeCurrency = 'CUP';
String activeLanguage = 'es';

/// Keeps the deployed web base path (for example `/tuktuk/`) while removing
/// transient OAuth preview parameters and fragments.
String webOAuthRedirect(Uri currentUri) =>
    '${currentUri.origin}${currentUri.path.isEmpty ? '/' : currentUri.path}';

String tr(String key) {
  const translations = <String, Map<String, String>>{
    'en': {
      'Tu licencia no permite realizar cambios.':
          'Your license does not allow changes.',
      'Tu licencia no permite realizar cambios. Puedes consultar tus datos en modo solo lectura.':
          'Your license does not allow changes. You can view your data in read-only mode.',
      'Estado': 'Status',
      'Vencimiento': 'Expiration',
      'Contacta al administrador para revisar tu licencia.':
          'Contact the administrator to review your license.',
      'Para renovar tu licencia o resolver cualquier problema, contáctanos por WhatsApp.':
          'To renew your license or resolve any issue, contact us on WhatsApp.',
      'Renovar o solicitar ayuda': 'Renew or request help',
      'Inicio': 'Home',
      'Nuevo': 'New',
      'Historial': 'History',
      'Estads.': 'Stats',
      'Usuario': 'User',
      'Atención al cliente': 'Customer support',
      'Soporte y pagos': 'Support and payments',
      'Pagos, soporte y licencias': 'Payments, support and licenses',
      'Referidos': 'Referrals',
      'Compartir mi código': 'Share my code',
      'Próximamente': 'Coming soon',
      'Invita a otros conductores y gana días adicionales.':
          'Invite other drivers and earn additional days.',
      'Tu código': 'Your code',
      'Días acumulados': 'Days earned',
      '¿Necesitas ayuda con TukTuk Control? Escríbenos por WhatsApp.':
          'Need help with TukTuk Control? Message us on WhatsApp.',
      'Contactar por WhatsApp': 'Contact via WhatsApp',
      'No se pudo abrir WhatsApp': 'WhatsApp could not be opened',
      'Ajustes': 'Settings',
      'Guardar ajustes': 'Save settings',
      'Moneda de trabajo': 'Currency',
      'Idioma': 'Language',
      'Modo visual': 'Appearance',
      'Predeterminado': 'System default',
      'Oscuro': 'Dark',
      'Claro': 'Light',
      'Nuevo registro': 'New record',
      'Editar registro': 'Edit record',
      'Historial editable': 'Editable history',
      'Estadísticas': 'Statistics',
      'Ganancia por mes': 'Monthly earnings',
      'Tendencia de días trabajados': 'Working days trend',
      'Información relevante': 'Relevant information',
      'Cuenta de usuario': 'User account',
      'Google y respaldo': 'Google and backup',
      'Vehiculo activo': 'Active vehicle',
      'Ajustes de mantenimiento': 'Maintenance settings',
      'Actividad reciente': 'Recent activity',
      'Agrega ganancia, odometro, carga o una nota':
          'Add earnings, odometer, charge, or a note',
      'Ajustes guardados': 'Settings saved',
      'Aun no hay recorridos. Registra el primer dia.':
          'No trips yet. Add the first day.',
      'bateria': 'battery',
      'Batería o carga (%)': 'Battery or charge (%)',
      'Voltaje de batería': 'Battery voltage',
      'El voltaje no puede ser negativo': 'Voltage cannot be negative',
      'Buscar por fecha, nota o km': 'Search by date, note, or km',
      'Cada cambio recalcula el inicio y las estadísticas.':
          'Every change recalculates Home and Statistics.',
      'Cancelar': 'Cancel',
      'Carga': 'Charge',
      'Carga completada hasta 80 V': 'Charge completed to 80 V',
      'Carga hasta 80 V': 'Charge to 80 V',
      'Cargas a 80 V': 'Charges to 80 V',
      'Cerrar sesion': 'Sign out',
      'Comenzar': 'Start',
      'Completar mantenimiento': 'Complete maintenance',
      'Conecta Google para guardar la base de datos en Google Drive y recuperarla al reinstalar.':
          'Connect Google to save the database to Google Drive and recover it after reinstalling.',
      'Configura tu primer Tuk Tuk': 'Set up your first Tuk Tuk',
      'Bienvenido a TukTuk': 'Welcome to TukTuk',
      'Controla tus ingresos, gastos y mantenimiento de forma sencilla.':
          'Manage your income, expenses, and maintenance with ease.',
      'Puedes registrarte con Google para respaldar tus datos o entrar directamente y usar la aplicacion sin conexion.':
          'You can sign in with Google to back up your data or enter directly and use the app offline.',
      'Continuar con Google': 'Continue with Google',
      'Entrar directamente': 'Enter directly',
      'No se pudo iniciar la aplicacion.': 'The app could not be started.',
      'No se pudo iniciar con Google.': 'Could not sign in with Google.',
      'Mi Tuk Tuk': 'My Tuk Tuk',
      'Costo opcional': 'Optional cost',
      'Cuando guardes registros, apareceran aqui.':
          'Saved records will appear here.',
      'Descripcion': 'Description',
      'Editar mantenimiento': 'Edit maintenance',
      'El costo no es valido': 'The cost is not valid',
      'El intervalo debe ser mayor que 0':
          'The interval must be greater than 0',
      'El kilometraje debe ser valido': 'The mileage must be valid',
      'El proximo mantenimiento se recalculara.':
          'The next maintenance will be recalculated.',
      'El respaldo JSON no es válido': 'The JSON backup is not valid',
      'Eliminar': 'Delete',
      'Eliminar mantenimiento': 'Delete maintenance',
      'Eliminar registro': 'Delete record',
      'Entrar con Google': 'Sign in with Google',
      'Entrar con Google primero': 'Sign in with Google first',
      'Esto cambiara todos los calculos derivados.':
          'This will change all derived calculations.',
      'Exportar CSV': 'Export CSV',
      'Exportar JSON': 'Export JSON',
      'Faltan tipo o descripcion': 'Type or description is missing',
      'Ganancia': 'Earnings',
      'Ganancia del día': 'Daily earnings',
      'Ganancia y odometro no pueden ser negativos':
          'Earnings and odometer cannot be negative',
      'Ganancias sin odometro': 'Earnings without odometer',
      'Guarda kilometraje, trabajo realizado, fecha, hora y costo.':
          'Save mileage, work performed, date, time, and cost.',
      'Guardar': 'Save',
      'Guardar intervalo': 'Save interval',
      'Guardar mantenimiento': 'Save maintenance',
      'Guardar vehiculo': 'Save vehicle',
      'ID interno': 'Internal ID',
      'Intervalo de mantenimiento (km)': 'Maintenance interval (km)',
      'Intervalo guardado': 'Interval saved',
      'Kilometraje del mantenimiento': 'Maintenance mileage',
      'Km del ultimo mantenimiento': 'Last maintenance km',
      'Km restantes': 'Remaining km',
      'La bateria debe estar entre 0 y 100':
          'Battery must be between 0 and 100',
      'Lecturas sospechosas': 'Suspicious readings',
      'Mant.': 'Maint.',
      'Mantenimiento general': 'General maintenance',
      'Mantenimiento guardado': 'Maintenance saved',
      'Matricula o identificador': 'Plate or identifier',
      'Matricula o identificador (opcional)': 'Plate or identifier (optional)',
      'Meta': 'Target',
      'No conectado': 'Not connected',
      'Nombre de usuario': 'User name',
      'Nombre del vehiculo': 'Vehicle name',
      'Nota opcional': 'Optional note',
      'Nuevo mantenimiento': 'New maintenance',
      'Observaciones': 'Notes',
      'Odómetro': 'Odometer',
      'Odometro actual (opcional)': 'Current odometer (optional)',
      'Odómetro final (km, opcional)': 'Final odometer (km, optional)',
      'Pega aquí el contenido del respaldo JSON':
          'Paste the JSON backup content here',
      'Personalizar perfil': 'Customize profile',
      'Proximo mantenimiento': 'Next maintenance',
      'Recuperar desde Drive': 'Restore from Drive',
      'Registrar mantenimiento': 'Add maintenance',
      'Registro guardado': 'Record saved',
      'Registros con ganancia': 'Records with earnings',
      'Respaldar ahora': 'Back up now',
      'Respaldo local': 'Local backup',
      'Respaldo restaurado': 'Backup restored',
      'Restaurar': 'Restore',
      'Restaurar JSON': 'Restore JSON',
      'Restaurar respaldo JSON': 'Restore JSON backup',
      'Salud de datos': 'Data health',
      'Selecciona qué dato vas a guardar.': 'Select the data you want to save.',
      'Sin cuenta Google vinculada · Guardado local':
          'No Google account linked · Saved locally',
      'Sin detalles': 'No details',
      'Sin mantenimientos registrados.': 'No maintenance records.',
      'Tipo de mantenimiento': 'Maintenance type',
      'Todavía no hay ganancias para graficar.':
          'There are no earnings to chart yet.',
      'Todavía no hay ganancias para mostrar.':
          'There are no earnings to show yet.',
      'Todos': 'All',
      'Tu espacio comienza vacio. Estos datos identifican el vehiculo al que perteneceran tus registros.':
          'Your space starts empty. This information identifies the vehicle that owns your records.',
      'Ultimo mantenimiento': 'Last maintenance',
      'Vehiculo actualizado': 'Vehicle updated',
      'Vencido por': 'Overdue by',
      'Agregar nuevo': 'Add new',
      'Agregar nuevo registro': 'Add new record',
      'Base local pendiente de respaldo': 'Local database awaiting backup',
      'Base recuperada desde Google Drive':
          'Database restored from Google Drive',
      'Base respaldada en Google Drive': 'Database backed up to Google Drive',
      'Configura tu primer vehiculo para comenzar':
          'Set up your first vehicle to begin',
      'Entra con Google para respaldar en Drive':
          'Sign in with Google to back up to Drive',
      'Este dispositivo ya contiene datos de otro usuario':
          'This device already contains another user’s data',
      'Sesion cerrada. La base local sigue en este dispositivo':
          'Signed out. The local database remains on this device',
      'Sincronizando...': 'Syncing...',
      'No se pudo sincronizar': 'Could not sync',
      'Escribe un nombre para tu vehiculo.': 'Enter a name for your vehicle.',
      'El odometro no puede ser negativo.': 'The odometer cannot be negative.',
      'No se pudo guardar el vehiculo.': 'Could not save the vehicle.',
      'Ganancia de hoy': 'Today’s earnings',
      'Mes actual': 'Current month',
      'Mes': 'Month',
      'Distancia del mes': 'Monthly distance',
      'Total historico': 'Historical total',
      'Eficiencia': 'Efficiency',
      'registros': 'records',
      'Guardar cambios': 'Save changes',
      'Guardar carga': 'Save charge',
      'Guardar ganancia': 'Save earnings',
      'Ganancia total': 'Total earnings',
      'Promedio por día trabajado': 'Average per working day',
      'Mejor día': 'Best day',
      'Mejor mes': 'Best month',
      'Sin datos': 'No data',
      'Sin datos mensuales': 'No monthly data',
      'Mantenimiento': 'Maintenance',
      'Próximo en': 'Next in',
      'Ultima sincronizacion': 'Last sync',
      'cambios locales preparados para futura sincronizacion':
          'local changes ready for future sync',
      'CSV copiado al portapapeles': 'CSV copied to clipboard',
      'JSON copiado': 'JSON copied',
      'Sin registrar': 'Not recorded',
      'Revisa': 'Review',
      'km es menor que': 'km is lower than',
      'registros con ganancia no tienen odometro.':
          'earning records have no odometer.',
      'Mes anterior': 'Previous month',
      'Mes siguiente': 'Next month',
      'Sincronizar': 'Sync',
      'Tu suscripción de ejemplo vence en 7 días':
          'Your example subscription expires in 7 days',
      'Peso cubano': 'Cuban peso',
      'Dólar estadounidense': 'US dollar',
      'Euro': 'Euro',
      'Peso mexicano': 'Mexican peso',
      'Mantenimiento vencido': 'Maintenance overdue',
      'Mantenimiento pendiente': 'Maintenance pending',
      'Programe el mantenimiento': 'Schedule maintenance',
      'Se aproxima el mantenimiento': 'Maintenance approaching',
      'Estado normal': 'Normal status',
      'Tienda': 'Store',
      'Encuentra piezas, accesorios y servicios para tu vehículo.':
          'Find parts, accessories, and services for your vehicle.',
      'Las búsquedas se abren externamente en Revolico. TukTuk Control no copia ni almacena anuncios.':
          'Searches open externally in Revolico. TukTuk Control does not copy or store listings.',
      'Buscar en Revolico': 'Search Revolico',
      '¿Qué necesitas para tu vehículo?': 'What do you need for your vehicle?',
      'Categorías': 'Categories',
      'Búsquedas rápidas': 'Quick searches',
      'Abrir búsqueda': 'Open search',
      'Escribe lo que deseas buscar': 'Enter what you want to search for',
      'No se pudo abrir el navegador': 'Could not open the browser',
      'Baterías': 'Batteries',
      'Cargadores': 'Chargers',
      'Neumáticos': 'Tires',
      'Motores': 'Motors',
      'Controladores': 'Controllers',
      'Piezas eléctricas': 'Electrical parts',
      'Repuestos mecánicos': 'Mechanical parts',
      'Luces y accesorios': 'Lights and accessories',
      'Herramientas': 'Tools',
      'Triciclos eléctricos': 'Electric tricycles',
      'Talleres y reparación': 'Workshops and repair',
      'Comparación de ingresos': 'Income comparison',
      'Mes anterior = 100%': 'Previous month = 100%',
      'Ingreso actual': 'Current income',
      'Ingreso': 'Income',
      'Ingreso de hoy': "Today's income",
      'Ingreso del día': 'Daily income',
      'Guardar ingreso': 'Save income',
      'Ingresos históricos': 'Historical income',
      'Ingresos totales': 'Total income',
      'Ingresos por mes': 'Monthly income',
      'Ingresos y gastos por mes': 'Monthly income and expenses',
      'Ingreso promedio por día trabajado': 'Average income per working day',
      'Ganancia neta': 'Net profit',
      'Ganancia neta del mes': 'Monthly net profit',
      'Registros con ingreso': 'Records with income',
      'Ingresos sin odometro': 'Income without odometer',
      'registros con ingreso no tienen odometro.':
          'income records have no odometer.',
      'Todavía no hay ingresos para graficar.':
          'There is no income to chart yet.',
      'Todavía no hay ingresos para mostrar.':
          'There is no income to show yet.',
      'Ingreso, gasto y odometro no pueden ser negativos':
          'Income, expense, and odometer cannot be negative',
      'Agrega ingreso, gasto, odometro, carga o una nota':
          'Add income, expense, odometer, charge, or a note',
      'Google no está configurado para la web':
          'Google is not configured for the web',
      'Gasto': 'Expense',
      'Importe del gasto': 'Expense amount',
      'Categoría del gasto': 'Expense category',
      'Guardar gasto': 'Save expense',
      'Gastos del mes': 'Monthly expenses',
      'Gastos totales': 'Total expenses',
      'Balance neto': 'Net balance',
      'Hitos y mensajes del sistema': 'Milestones and system messages',
      'Hitos y mensajes': 'Milestones and messages',
      'Comienza tu recorrido': 'Start your route',
      'Agrega registros para recibir recomendaciones personalizadas.':
          'Add records to receive personalized recommendations.',
      'El mantenimiento esta vencido por': 'Maintenance is overdue by',
      'Atiendelo cuanto antes.': 'Take care of it as soon as possible.',
      'Proximo servicio en': 'Next service in',
      'Meta mensual superada': 'Monthly target exceeded',
      'Avance del mes': 'Monthly progress',
      'Has alcanzado': 'You have reached',
      'del resultado del mes anterior': "of the previous month's result",
      'Mejor jornada registrada': 'Best recorded day',
    },
    'pt': {
      'Tu licencia no permite realizar cambios.':
          'Sua licença não permite alterações.',
      'Tu licencia no permite realizar cambios. Puedes consultar tus datos en modo solo lectura.':
          'Sua licença não permite alterações. Você pode consultar seus dados no modo somente leitura.',
      'Estado': 'Status',
      'Vencimiento': 'Vencimento',
      'Contacta al administrador para revisar tu licencia.':
          'Entre em contato com o administrador para revisar sua licença.',
      'Para renovar tu licencia o resolver cualquier problema, contáctanos por WhatsApp.':
          'Para renovar sua licença ou resolver qualquer problema, fale conosco pelo WhatsApp.',
      'Renovar o solicitar ayuda': 'Renovar ou pedir ajuda',
      'Inicio': 'Início',
      'Nuevo': 'Novo',
      'Historial': 'Histórico',
      'Estads.': 'Estat.',
      'Usuario': 'Usuário',
      'Atención al cliente': 'Atendimento ao cliente',
      'Soporte y pagos': 'Suporte e pagamentos',
      'Pagos, soporte y licencias': 'Pagamentos, suporte e licenças',
      'Referidos': 'Indicações',
      'Compartir mi código': 'Compartilhar meu código',
      'Próximamente': 'Em breve',
      'Invita a otros conductores y gana días adicionales.':
          'Convide outros motoristas e ganhe dias adicionais.',
      'Tu código': 'Seu código',
      'Días acumulados': 'Dias acumulados',
      '¿Necesitas ayuda con TukTuk Control? Escríbenos por WhatsApp.':
          'Precisa de ajuda com o TukTuk Control? Fale conosco pelo WhatsApp.',
      'Contactar por WhatsApp': 'Contatar pelo WhatsApp',
      'No se pudo abrir WhatsApp': 'Não foi possível abrir o WhatsApp',
      'Ajustes': 'Ajustes',
      'Guardar ajustes': 'Salvar ajustes',
      'Moneda de trabajo': 'Moeda',
      'Idioma': 'Idioma',
      'Modo visual': 'Aparência',
      'Predeterminado': 'Padrão do sistema',
      'Oscuro': 'Escuro',
      'Claro': 'Claro',
      'Nuevo registro': 'Novo registro',
      'Editar registro': 'Editar registro',
      'Historial editable': 'Histórico editável',
      'Estadísticas': 'Estatísticas',
      'Ganancia por mes': 'Ganhos por mês',
      'Tendencia de días trabajados': 'Tendência de dias trabalhados',
      'Información relevante': 'Informação relevante',
      'Cuenta de usuario': 'Conta de usuário',
      'Google y respaldo': 'Google e backup',
      'Vehiculo activo': 'Veículo ativo',
      'Ajustes de mantenimiento': 'Ajustes de manutenção',
      'Actividad reciente': 'Atividade recente',
      'Agrega ganancia, odometro, carga o una nota':
          'Adicione ganho, odômetro, carga ou uma nota',
      'Ajustes guardados': 'Ajustes salvos',
      'Aun no hay recorridos. Registra el primer dia.':
          'Ainda não há trajetos. Registre o primeiro dia.',
      'bateria': 'bateria',
      'Batería o carga (%)': 'Bateria ou carga (%)',
      'Voltaje de batería': 'Tensão da bateria',
      'El voltaje no puede ser negativo': 'A tensão não pode ser negativa',
      'Buscar por fecha, nota o km': 'Buscar por data, nota ou km',
      'Cada cambio recalcula el inicio y las estadísticas.':
          'Cada alteração recalcula o início e as estatísticas.',
      'Cancelar': 'Cancelar',
      'Carga': 'Carga',
      'Carga completada hasta 80 V': 'Carga concluída até 80 V',
      'Carga hasta 80 V': 'Carga até 80 V',
      'Cargas a 80 V': 'Cargas até 80 V',
      'Cerrar sesion': 'Sair',
      'Comenzar': 'Começar',
      'Completar mantenimiento': 'Preencher manutenção',
      'Conecta Google para guardar la base de datos en Google Drive y recuperarla al reinstalar.':
          'Conecte o Google para salvar o banco de dados no Google Drive e recuperá-lo após reinstalar.',
      'Configura tu primer Tuk Tuk': 'Configure seu primeiro Tuk Tuk',
      'Bienvenido a TukTuk': 'Bem-vindo ao TukTuk',
      'Controla tus ingresos, gastos y mantenimiento de forma sencilla.':
          'Controle suas receitas, despesas e manutenção com facilidade.',
      'Puedes registrarte con Google para respaldar tus datos o entrar directamente y usar la aplicacion sin conexion.':
          'Você pode entrar com o Google para proteger seus dados ou entrar diretamente e usar o aplicativo offline.',
      'Continuar con Google': 'Continuar com o Google',
      'Entrar directamente': 'Entrar diretamente',
      'No se pudo iniciar la aplicacion.':
          'Não foi possível iniciar o aplicativo.',
      'No se pudo iniciar con Google.': 'Não foi possível entrar com o Google.',
      'Mi Tuk Tuk': 'Meu Tuk Tuk',
      'Costo opcional': 'Custo opcional',
      'Cuando guardes registros, apareceran aqui.':
          'Os registros salvos aparecerão aqui.',
      'Descripcion': 'Descrição',
      'Editar mantenimiento': 'Editar manutenção',
      'El costo no es valido': 'O custo não é válido',
      'El intervalo debe ser mayor que 0': 'O intervalo deve ser maior que 0',
      'El kilometraje debe ser valido': 'A quilometragem deve ser válida',
      'El proximo mantenimiento se recalculara.':
          'A próxima manutenção será recalculada.',
      'El respaldo JSON no es válido': 'O backup JSON não é válido',
      'Eliminar': 'Excluir',
      'Eliminar mantenimiento': 'Excluir manutenção',
      'Eliminar registro': 'Excluir registro',
      'Entrar con Google': 'Entrar com Google',
      'Entrar con Google primero': 'Entre com Google primeiro',
      'Esto cambiara todos los calculos derivados.':
          'Isso alterará todos os cálculos derivados.',
      'Exportar CSV': 'Exportar CSV',
      'Exportar JSON': 'Exportar JSON',
      'Faltan tipo o descripcion': 'Falta o tipo ou a descrição',
      'Ganancia': 'Ganho',
      'Ganancia del día': 'Ganho diário',
      'Ganancia y odometro no pueden ser negativos':
          'Ganho e odômetro não podem ser negativos',
      'Ganancias sin odometro': 'Ganhos sem odômetro',
      'Guarda kilometraje, trabajo realizado, fecha, hora y costo.':
          'Salve quilometragem, serviço realizado, data, hora e custo.',
      'Guardar': 'Salvar',
      'Guardar intervalo': 'Salvar intervalo',
      'Guardar mantenimiento': 'Salvar manutenção',
      'Guardar vehiculo': 'Salvar veículo',
      'ID interno': 'ID interno',
      'Intervalo de mantenimiento (km)': 'Intervalo de manutenção (km)',
      'Intervalo guardado': 'Intervalo salvo',
      'Kilometraje del mantenimiento': 'Quilometragem da manutenção',
      'Km del ultimo mantenimiento': 'Km da última manutenção',
      'Km restantes': 'Km restantes',
      'La bateria debe estar entre 0 y 100':
          'A bateria deve estar entre 0 e 100',
      'Lecturas sospechosas': 'Leituras suspeitas',
      'Mant.': 'Manut.',
      'Mantenimiento general': 'Manutenção geral',
      'Mantenimiento guardado': 'Manutenção salva',
      'Matricula o identificador': 'Placa ou identificador',
      'Matricula o identificador (opcional)':
          'Placa ou identificador (opcional)',
      'Meta': 'Meta',
      'No conectado': 'Não conectado',
      'Nombre de usuario': 'Nome de usuário',
      'Nombre del vehiculo': 'Nome do veículo',
      'Nota opcional': 'Nota opcional',
      'Nuevo mantenimiento': 'Nova manutenção',
      'Observaciones': 'Observações',
      'Odómetro': 'Odômetro',
      'Odometro actual (opcional)': 'Odômetro atual (opcional)',
      'Odómetro final (km, opcional)': 'Odômetro final (km, opcional)',
      'Pega aquí el contenido del respaldo JSON':
          'Cole aqui o conteúdo do backup JSON',
      'Personalizar perfil': 'Personalizar perfil',
      'Proximo mantenimiento': 'Próxima manutenção',
      'Recuperar desde Drive': 'Restaurar do Drive',
      'Registrar mantenimiento': 'Registrar manutenção',
      'Registro guardado': 'Registro salvo',
      'Registros con ganancia': 'Registros com ganho',
      'Respaldar ahora': 'Fazer backup agora',
      'Respaldo local': 'Backup local',
      'Respaldo restaurado': 'Backup restaurado',
      'Restaurar': 'Restaurar',
      'Restaurar JSON': 'Restaurar JSON',
      'Restaurar respaldo JSON': 'Restaurar backup JSON',
      'Salud de datos': 'Saúde dos dados',
      'Selecciona qué dato vas a guardar.':
          'Selecione o dado que deseja salvar.',
      'Sin cuenta Google vinculada · Guardado local':
          'Nenhuma conta Google vinculada · Salvo localmente',
      'Sin detalles': 'Sem detalhes',
      'Sin mantenimientos registrados.': 'Nenhuma manutenção registrada.',
      'Tipo de mantenimiento': 'Tipo de manutenção',
      'Todavía no hay ganancias para graficar.':
          'Ainda não há ganhos para o gráfico.',
      'Todavía no hay ganancias para mostrar.':
          'Ainda não há ganhos para mostrar.',
      'Todos': 'Todos',
      'Tu espacio comienza vacio. Estos datos identifican el vehiculo al que perteneceran tus registros.':
          'Seu espaço começa vazio. Estes dados identificam o veículo ao qual pertencem seus registros.',
      'Ultimo mantenimiento': 'Última manutenção',
      'Vehiculo actualizado': 'Veículo atualizado',
      'Vencido por': 'Atrasado em',
      'Agregar nuevo': 'Adicionar novo',
      'Agregar nuevo registro': 'Adicionar novo registro',
      'Base local pendiente de respaldo': 'Banco local aguardando backup',
      'Base recuperada desde Google Drive': 'Banco restaurado do Google Drive',
      'Base respaldada en Google Drive': 'Banco salvo no Google Drive',
      'Configura tu primer vehiculo para comenzar':
          'Configure seu primeiro veículo para começar',
      'Entra con Google para respaldar en Drive':
          'Entre com Google para fazer backup no Drive',
      'Este dispositivo ya contiene datos de otro usuario':
          'Este dispositivo já contém dados de outro usuário',
      'Sesion cerrada. La base local sigue en este dispositivo':
          'Sessão encerrada. O banco local permanece neste dispositivo',
      'Sincronizando...': 'Sincronizando...',
      'No se pudo sincronizar': 'Não foi possível sincronizar',
      'Escribe un nombre para tu vehiculo.': 'Digite um nome para o veículo.',
      'El odometro no puede ser negativo.': 'O odômetro não pode ser negativo.',
      'No se pudo guardar el vehiculo.': 'Não foi possível salvar o veículo.',
      'Ganancia de hoy': 'Ganho de hoje',
      'Mes actual': 'Mês atual',
      'Mes': 'Mês',
      'Distancia del mes': 'Distância do mês',
      'Total historico': 'Total histórico',
      'Eficiencia': 'Eficiência',
      'registros': 'registros',
      'Guardar cambios': 'Salvar alterações',
      'Guardar carga': 'Salvar carga',
      'Guardar ganancia': 'Salvar ganho',
      'Ganancia total': 'Ganho total',
      'Promedio por día trabajado': 'Média por dia trabalhado',
      'Mejor día': 'Melhor dia',
      'Mejor mes': 'Melhor mês',
      'Sin datos': 'Sem dados',
      'Sin datos mensuales': 'Sem dados mensais',
      'Mantenimiento': 'Manutenção',
      'Próximo en': 'Próximo em',
      'Ultima sincronizacion': 'Última sincronização',
      'cambios locales preparados para futura sincronizacion':
          'alterações locais prontas para sincronização futura',
      'CSV copiado al portapapeles': 'CSV copiado para a área de transferência',
      'JSON copiado': 'JSON copiado',
      'Sin registrar': 'Não registrado',
      'Revisa': 'Revise',
      'km es menor que': 'km é menor que',
      'registros con ganancia no tienen odometro.':
          'registros com ganho não têm odômetro.',
      'Mes anterior': 'Mês anterior',
      'Mes siguiente': 'Próximo mês',
      'Sincronizar': 'Sincronizar',
      'Tu suscripción de ejemplo vence en 7 días':
          'Sua assinatura de exemplo vence em 7 dias',
      'Peso cubano': 'Peso cubano',
      'Dólar estadounidense': 'Dólar americano',
      'Euro': 'Euro',
      'Peso mexicano': 'Peso mexicano',
      'Mantenimiento vencido': 'Manutenção atrasada',
      'Mantenimiento pendiente': 'Manutenção pendente',
      'Programe el mantenimiento': 'Agende a manutenção',
      'Se aproxima el mantenimiento': 'A manutenção se aproxima',
      'Estado normal': 'Estado normal',
      'Tienda': 'Loja',
      'Encuentra piezas, accesorios y servicios para tu vehículo.':
          'Encontre peças, acessórios e serviços para seu veículo.',
      'Las búsquedas se abren externamente en Revolico. TukTuk Control no copia ni almacena anuncios.':
          'As buscas abrem externamente no Revolico. TukTuk Control não copia nem armazena anúncios.',
      'Buscar en Revolico': 'Buscar no Revolico',
      '¿Qué necesitas para tu vehículo?':
          'O que você precisa para seu veículo?',
      'Categorías': 'Categorias',
      'Búsquedas rápidas': 'Buscas rápidas',
      'Abrir búsqueda': 'Abrir busca',
      'Escribe lo que deseas buscar': 'Digite o que deseja buscar',
      'No se pudo abrir el navegador': 'Não foi possível abrir o navegador',
      'Baterías': 'Baterias',
      'Cargadores': 'Carregadores',
      'Neumáticos': 'Pneus',
      'Motores': 'Motores',
      'Controladores': 'Controladores',
      'Piezas eléctricas': 'Peças elétricas',
      'Repuestos mecánicos': 'Peças mecânicas',
      'Luces y accesorios': 'Luzes e acessórios',
      'Herramientas': 'Ferramentas',
      'Triciclos eléctricos': 'Triciclos elétricos',
      'Talleres y reparación': 'Oficinas e reparação',
      'Comparación de ingresos': 'Comparação de receitas',
      'Mes anterior = 100%': 'Mês anterior = 100%',
      'Ingreso actual': 'Receita atual',
      'Ingreso': 'Receita',
      'Ingreso de hoy': 'Receita de hoje',
      'Ingreso del día': 'Receita do dia',
      'Guardar ingreso': 'Salvar receita',
      'Ingresos históricos': 'Receitas históricas',
      'Ingresos totales': 'Receitas totais',
      'Ingresos por mes': 'Receitas por mês',
      'Ingresos y gastos por mes': 'Receitas e despesas por mês',
      'Ingreso promedio por día trabajado': 'Receita média por dia trabalhado',
      'Ganancia neta': 'Lucro líquido',
      'Ganancia neta del mes': 'Lucro líquido do mês',
      'Registros con ingreso': 'Registros com receita',
      'Ingresos sin odometro': 'Receitas sem odômetro',
      'registros con ingreso no tienen odometro.':
          'registros com receita não têm odômetro.',
      'Todavía no hay ingresos para graficar.':
          'Ainda não há receitas para o gráfico.',
      'Todavía no hay ingresos para mostrar.':
          'Ainda não há receitas para mostrar.',
      'Ingreso, gasto y odometro no pueden ser negativos':
          'Receita, despesa e odômetro não podem ser negativos',
      'Agrega ingreso, gasto, odometro, carga o una nota':
          'Adicione receita, despesa, odômetro, carga ou uma nota',
      'Google no está configurado para la web':
          'Google não está configurado para a web',
      'Gasto': 'Despesa',
      'Importe del gasto': 'Valor da despesa',
      'Categoría del gasto': 'Categoria da despesa',
      'Guardar gasto': 'Salvar despesa',
      'Gastos del mes': 'Despesas do mês',
      'Gastos totales': 'Despesas totais',
      'Balance neto': 'Saldo líquido',
      'Hitos y mensajes del sistema': 'Marcos e mensagens do sistema',
      'Hitos y mensajes': 'Marcos e mensagens',
      'Comienza tu recorrido': 'Comece sua rota',
      'Agrega registros para recibir recomendaciones personalizadas.':
          'Adicione registros para receber recomendações personalizadas.',
      'El mantenimiento esta vencido por': 'A manutenção está atrasada em',
      'Atiendelo cuanto antes.': 'Resolva o quanto antes.',
      'Proximo servicio en': 'Próximo serviço em',
      'Meta mensual superada': 'Meta mensal superada',
      'Avance del mes': 'Progresso do mês',
      'Has alcanzado': 'Você alcançou',
      'del resultado del mes anterior': 'do resultado do mês anterior',
      'Mejor jornada registrada': 'Melhor dia registrado',
    },
    'fr': {
      'Tu licencia no permite realizar cambios.':
          'Votre licence ne permet pas les modifications.',
      'Tu licencia no permite realizar cambios. Puedes consultar tus datos en modo solo lectura.':
          'Votre licence ne permet pas les modifications. Vous pouvez consulter vos données en lecture seule.',
      'Estado': 'État',
      'Vencimiento': 'Expiration',
      'Contacta al administrador para revisar tu licencia.':
          'Contactez l’administrateur pour vérifier votre licence.',
      'Para renovar tu licencia o resolver cualquier problema, contáctanos por WhatsApp.':
          'Pour renouveler votre licence ou résoudre un problème, contactez-nous sur WhatsApp.',
      'Renovar o solicitar ayuda': 'Renouveler ou demander de l’aide',
      'Inicio': 'Accueil',
      'Nuevo': 'Nouveau',
      'Historial': 'Historique',
      'Estads.': 'Stats',
      'Usuario': 'Utilisateur',
      'Atención al cliente': 'Service client',
      'Soporte y pagos': 'Assistance et paiements',
      'Pagos, soporte y licencias': 'Paiements, assistance et licences',
      'Referidos': 'Parrainages',
      'Compartir mi código': 'Partager mon code',
      'Próximamente': 'Bientôt disponible',
      'Invita a otros conductores y gana días adicionales.':
          'Invitez d’autres conducteurs et gagnez des jours supplémentaires.',
      'Tu código': 'Votre code',
      'Días acumulados': 'Jours cumulés',
      '¿Necesitas ayuda con TukTuk Control? Escríbenos por WhatsApp.':
          'Besoin d’aide avec TukTuk Control ? Écrivez-nous sur WhatsApp.',
      'Contactar por WhatsApp': 'Contacter sur WhatsApp',
      'No se pudo abrir WhatsApp': 'Impossible d’ouvrir WhatsApp',
      'Ajustes': 'Paramètres',
      'Guardar ajustes': 'Enregistrer',
      'Moneda de trabajo': 'Devise',
      'Idioma': 'Langue',
      'Modo visual': 'Apparence',
      'Predeterminado': 'Système',
      'Oscuro': 'Sombre',
      'Claro': 'Clair',
      'Nuevo registro': 'Nouveau registre',
      'Editar registro': 'Modifier le registre',
      'Historial editable': 'Historique modifiable',
      'Estadísticas': 'Statistiques',
      'Ganancia por mes': 'Gains mensuels',
      'Tendencia de días trabajados': 'Tendance des jours travaillés',
      'Información relevante': 'Informations pertinentes',
      'Cuenta de usuario': 'Compte utilisateur',
      'Google y respaldo': 'Google et sauvegarde',
      'Vehiculo activo': 'Véhicule actif',
      'Ajustes de mantenimiento': 'Paramètres de maintenance',
      'Actividad reciente': 'Activité récente',
      'Agrega ganancia, odometro, carga o una nota':
          'Ajoutez un gain, un odomètre, une charge ou une note',
      'Ajustes guardados': 'Paramètres enregistrés',
      'Aun no hay recorridos. Registra el primer dia.':
          'Aucun trajet. Enregistrez le premier jour.',
      'bateria': 'batterie',
      'Batería o carga (%)': 'Batterie ou charge (%)',
      'Voltaje de batería': 'Tension de la batterie',
      'El voltaje no puede ser negativo':
          'La tension ne peut pas être négative',
      'Buscar por fecha, nota o km': 'Rechercher par date, note ou km',
      'Cada cambio recalcula el inicio y las estadísticas.':
          'Chaque modification recalcule l’accueil et les statistiques.',
      'Cancelar': 'Annuler',
      'Carga': 'Charge',
      'Carga completada hasta 80 V': 'Charge terminée à 80 V',
      'Carga hasta 80 V': 'Charge à 80 V',
      'Cargas a 80 V': 'Charges à 80 V',
      'Cerrar sesion': 'Se déconnecter',
      'Comenzar': 'Commencer',
      'Completar mantenimiento': 'Compléter la maintenance',
      'Conecta Google para guardar la base de datos en Google Drive y recuperarla al reinstalar.':
          'Connectez Google pour enregistrer la base dans Google Drive et la récupérer après réinstallation.',
      'Configura tu primer Tuk Tuk': 'Configurez votre premier Tuk Tuk',
      'Bienvenido a TukTuk': 'Bienvenue sur TukTuk',
      'Controla tus ingresos, gastos y mantenimiento de forma sencilla.':
          'Gérez facilement vos revenus, dépenses et entretiens.',
      'Puedes registrarte con Google para respaldar tus datos o entrar directamente y usar la aplicacion sin conexion.':
          'Vous pouvez vous connecter avec Google pour sauvegarder vos données ou entrer directement et utiliser l’application hors ligne.',
      'Continuar con Google': 'Continuer avec Google',
      'Entrar directamente': 'Entrer directement',
      'No se pudo iniciar la aplicacion.':
          'Impossible de démarrer l’application.',
      'No se pudo iniciar con Google.': 'Connexion avec Google impossible.',
      'Mi Tuk Tuk': 'Mon Tuk Tuk',
      'Costo opcional': 'Coût facultatif',
      'Cuando guardes registros, apareceran aqui.':
          'Les enregistrements apparaîtront ici.',
      'Descripcion': 'Description',
      'Editar mantenimiento': 'Modifier la maintenance',
      'El costo no es valido': 'Le coût n’est pas valide',
      'El intervalo debe ser mayor que 0':
          'L’intervalle doit être supérieur à 0',
      'El kilometraje debe ser valido': 'Le kilométrage doit être valide',
      'El proximo mantenimiento se recalculara.':
          'La prochaine maintenance sera recalculée.',
      'El respaldo JSON no es válido': 'La sauvegarde JSON n’est pas valide',
      'Eliminar': 'Supprimer',
      'Eliminar mantenimiento': 'Supprimer la maintenance',
      'Eliminar registro': 'Supprimer l’enregistrement',
      'Entrar con Google': 'Se connecter avec Google',
      'Entrar con Google primero': 'Connectez-vous d’abord avec Google',
      'Esto cambiara todos los calculos derivados.':
          'Cela modifiera tous les calculs dérivés.',
      'Exportar CSV': 'Exporter CSV',
      'Exportar JSON': 'Exporter JSON',
      'Faltan tipo o descripcion': 'Le type ou la description manque',
      'Ganancia': 'Gain',
      'Ganancia del día': 'Gain quotidien',
      'Ganancia y odometro no pueden ser negativos':
          'Le gain et l’odomètre ne peuvent pas être négatifs',
      'Ganancias sin odometro': 'Gains sans odomètre',
      'Guarda kilometraje, trabajo realizado, fecha, hora y costo.':
          'Enregistrez le kilométrage, le travail, la date, l’heure et le coût.',
      'Guardar': 'Enregistrer',
      'Guardar intervalo': 'Enregistrer l’intervalle',
      'Guardar mantenimiento': 'Enregistrer la maintenance',
      'Guardar vehiculo': 'Enregistrer le véhicule',
      'ID interno': 'ID interne',
      'Intervalo de mantenimiento (km)': 'Intervalle de maintenance (km)',
      'Intervalo guardado': 'Intervalle enregistré',
      'Kilometraje del mantenimiento': 'Kilométrage de maintenance',
      'Km del ultimo mantenimiento': 'Km de la dernière maintenance',
      'Km restantes': 'Km restants',
      'La bateria debe estar entre 0 y 100':
          'La batterie doit être entre 0 et 100',
      'Lecturas sospechosas': 'Lectures suspectes',
      'Mant.': 'Maint.',
      'Mantenimiento general': 'Maintenance générale',
      'Mantenimiento guardado': 'Maintenance enregistrée',
      'Matricula o identificador': 'Plaque ou identifiant',
      'Matricula o identificador (opcional)':
          'Plaque ou identifiant (facultatif)',
      'Meta': 'Objectif',
      'No conectado': 'Non connecté',
      'Nombre de usuario': 'Nom d’utilisateur',
      'Nombre del vehiculo': 'Nom du véhicule',
      'Nota opcional': 'Note facultative',
      'Nuevo mantenimiento': 'Nouvelle maintenance',
      'Observaciones': 'Observations',
      'Odómetro': 'Odomètre',
      'Odometro actual (opcional)': 'Odomètre actuel (facultatif)',
      'Odómetro final (km, opcional)': 'Odomètre final (km, facultatif)',
      'Pega aquí el contenido del respaldo JSON':
          'Collez ici le contenu de la sauvegarde JSON',
      'Personalizar perfil': 'Personnaliser le profil',
      'Proximo mantenimiento': 'Prochaine maintenance',
      'Recuperar desde Drive': 'Restaurer depuis Drive',
      'Registrar mantenimiento': 'Enregistrer une maintenance',
      'Registro guardado': 'Enregistrement sauvegardé',
      'Registros con ganancia': 'Enregistrements avec gain',
      'Respaldar ahora': 'Sauvegarder maintenant',
      'Respaldo local': 'Sauvegarde locale',
      'Respaldo restaurado': 'Sauvegarde restaurée',
      'Restaurar': 'Restaurer',
      'Restaurar JSON': 'Restaurer JSON',
      'Restaurar respaldo JSON': 'Restaurer la sauvegarde JSON',
      'Salud de datos': 'Santé des données',
      'Selecciona qué dato vas a guardar.':
          'Sélectionnez les données à enregistrer.',
      'Sin cuenta Google vinculada · Guardado local':
          'Aucun compte Google lié · Enregistré localement',
      'Sin detalles': 'Aucun détail',
      'Sin mantenimientos registrados.': 'Aucune maintenance enregistrée.',
      'Tipo de mantenimiento': 'Type de maintenance',
      'Todavía no hay ganancias para graficar.': 'Aucun gain à représenter.',
      'Todavía no hay ganancias para mostrar.': 'Aucun gain à afficher.',
      'Todos': 'Tous',
      'Tu espacio comienza vacio. Estos datos identifican el vehiculo al que perteneceran tus registros.':
          'Votre espace commence vide. Ces données identifient le véhicule auquel appartiennent vos enregistrements.',
      'Ultimo mantenimiento': 'Dernière maintenance',
      'Vehiculo actualizado': 'Véhicule mis à jour',
      'Vencido por': 'En retard de',
      'Agregar nuevo': 'Ajouter',
      'Agregar nuevo registro': 'Ajouter un enregistrement',
      'Base local pendiente de respaldo':
          'Base locale en attente de sauvegarde',
      'Base recuperada desde Google Drive':
          'Base restaurée depuis Google Drive',
      'Base respaldada en Google Drive': 'Base sauvegardée dans Google Drive',
      'Configura tu primer vehiculo para comenzar':
          'Configurez votre premier véhicule pour commencer',
      'Entra con Google para respaldar en Drive':
          'Connectez-vous avec Google pour sauvegarder dans Drive',
      'Este dispositivo ya contiene datos de otro usuario':
          'Cet appareil contient déjà les données d’un autre utilisateur',
      'Sesion cerrada. La base local sigue en este dispositivo':
          'Session fermée. La base locale reste sur cet appareil',
      'Sincronizando...': 'Synchronisation...',
      'No se pudo sincronizar': 'Échec de la synchronisation',
      'Escribe un nombre para tu vehiculo.':
          'Saisissez un nom pour le véhicule.',
      'El odometro no puede ser negativo.':
          'L’odomètre ne peut pas être négatif.',
      'No se pudo guardar el vehiculo.':
          'Impossible d’enregistrer le véhicule.',
      'Ganancia de hoy': 'Gain du jour',
      'Mes actual': 'Mois actuel',
      'Mes': 'Mois',
      'Distancia del mes': 'Distance du mois',
      'Total historico': 'Total historique',
      'Eficiencia': 'Efficacité',
      'registros': 'enregistrements',
      'Guardar cambios': 'Enregistrer les modifications',
      'Guardar carga': 'Enregistrer la charge',
      'Guardar ganancia': 'Enregistrer le gain',
      'Ganancia total': 'Gain total',
      'Promedio por día trabajado': 'Moyenne par jour travaillé',
      'Mejor día': 'Meilleur jour',
      'Mejor mes': 'Meilleur mois',
      'Sin datos': 'Aucune donnée',
      'Sin datos mensuales': 'Aucune donnée mensuelle',
      'Mantenimiento': 'Maintenance',
      'Próximo en': 'Prochaine dans',
      'Ultima sincronizacion': 'Dernière synchronisation',
      'cambios locales preparados para futura sincronizacion':
          'modifications locales prêtes pour une future synchronisation',
      'CSV copiado al portapapeles': 'CSV copié dans le presse-papiers',
      'JSON copiado': 'JSON copié',
      'Sin registrar': 'Non enregistré',
      'Revisa': 'Vérifiez',
      'km es menor que': 'km est inférieur à',
      'registros con ganancia no tienen odometro.':
          'enregistrements avec gain n’ont pas d’odomètre.',
      'Mes anterior': 'Mois précédent',
      'Mes siguiente': 'Mois suivant',
      'Sincronizar': 'Synchroniser',
      'Tu suscripción de ejemplo vence en 7 días':
          'Votre abonnement d’exemple expire dans 7 jours',
      'Peso cubano': 'Peso cubain',
      'Dólar estadounidense': 'Dollar américain',
      'Euro': 'Euro',
      'Peso mexicano': 'Peso mexicain',
      'Mantenimiento vencido': 'Maintenance en retard',
      'Mantenimiento pendiente': 'Maintenance en attente',
      'Programe el mantenimiento': 'Planifiez la maintenance',
      'Se aproxima el mantenimiento': 'Maintenance prochaine',
      'Estado normal': 'État normal',
      'Tienda': 'Boutique',
      'Encuentra piezas, accesorios y servicios para tu vehículo.':
          'Trouvez des pièces, accessoires et services pour votre véhicule.',
      'Las búsquedas se abren externamente en Revolico. TukTuk Control no copia ni almacena anuncios.':
          'Les recherches s’ouvrent dans Revolico. TukTuk Control ne copie ni ne stocke les annonces.',
      'Buscar en Revolico': 'Rechercher sur Revolico',
      '¿Qué necesitas para tu vehículo?':
          'De quoi avez-vous besoin pour votre véhicule ?',
      'Categorías': 'Catégories',
      'Búsquedas rápidas': 'Recherches rapides',
      'Abrir búsqueda': 'Ouvrir la recherche',
      'Escribe lo que deseas buscar': 'Saisissez ce que vous recherchez',
      'No se pudo abrir el navegador': 'Impossible d’ouvrir le navigateur',
      'Baterías': 'Batteries',
      'Cargadores': 'Chargeurs',
      'Neumáticos': 'Pneus',
      'Motores': 'Moteurs',
      'Controladores': 'Contrôleurs',
      'Piezas eléctricas': 'Pièces électriques',
      'Repuestos mecánicos': 'Pièces mécaniques',
      'Luces y accesorios': 'Éclairage et accessoires',
      'Herramientas': 'Outils',
      'Triciclos eléctricos': 'Tricycles électriques',
      'Talleres y reparación': 'Ateliers et réparation',
      'Comparación de ingresos': 'Comparaison des revenus',
      'Mes anterior = 100%': 'Mois précédent = 100 %',
      'Ingreso actual': 'Revenu actuel',
      'Ingreso': 'Revenu',
      'Ingreso de hoy': 'Revenu du jour',
      'Ingreso del día': 'Revenu quotidien',
      'Guardar ingreso': 'Enregistrer le revenu',
      'Ingresos históricos': 'Revenus historiques',
      'Ingresos totales': 'Revenus totaux',
      'Ingresos por mes': 'Revenus mensuels',
      'Ingresos y gastos por mes': 'Revenus et dépenses mensuels',
      'Ingreso promedio por día trabajado': 'Revenu moyen par jour travaillé',
      'Ganancia neta': 'Bénéfice net',
      'Ganancia neta del mes': 'Bénéfice net du mois',
      'Registros con ingreso': 'Enregistrements avec revenu',
      'Ingresos sin odometro': 'Revenus sans odomètre',
      'registros con ingreso no tienen odometro.':
          'enregistrements avec revenu n’ont pas d’odomètre.',
      'Todavía no hay ingresos para graficar.':
          'Il n’y a pas encore de revenus à représenter.',
      'Todavía no hay ingresos para mostrar.':
          'Il n’y a pas encore de revenus à afficher.',
      'Ingreso, gasto y odometro no pueden ser negativos':
          'Le revenu, la dépense et l’odomètre ne peuvent pas être négatifs',
      'Agrega ingreso, gasto, odometro, carga o una nota':
          'Ajoutez un revenu, une dépense, un odomètre, une charge ou une note',
      'Google no está configurado para la web':
          'Google n’est pas configuré pour le web',
      'Gasto': 'Dépense',
      'Importe del gasto': 'Montant de la dépense',
      'Categoría del gasto': 'Catégorie de dépense',
      'Guardar gasto': 'Enregistrer la dépense',
      'Gastos del mes': 'Dépenses du mois',
      'Gastos totales': 'Dépenses totales',
      'Balance neto': 'Solde net',
      'Hitos y mensajes del sistema': 'Étapes et messages du système',
      'Hitos y mensajes': 'Étapes et messages',
      'Comienza tu recorrido': 'Commencez votre trajet',
      'Agrega registros para recibir recomendaciones personalizadas.':
          'Ajoutez des données pour recevoir des recommandations personnalisées.',
      'El mantenimiento esta vencido por': 'La maintenance est en retard de',
      'Atiendelo cuanto antes.': 'Effectuez-la dès que possible.',
      'Proximo servicio en': 'Prochain entretien dans',
      'Meta mensual superada': 'Objectif mensuel dépassé',
      'Avance del mes': 'Progression du mois',
      'Has alcanzado': 'Vous avez atteint',
      'del resultado del mes anterior': 'du résultat du mois précédent',
      'Mejor jornada registrada': 'Meilleure journée enregistrée',
    },
  };
  return translations[activeLanguage]?[key] ?? key;
}
