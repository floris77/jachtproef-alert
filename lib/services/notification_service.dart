import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    // Set location to Amsterdam (Dutch timezone)
    tz.setLocalLocation(tz.getLocation('Europe/Amsterdam'));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'enrollment_actions',
          actions: [
            DarwinNotificationAction.plain(
              'enrollment_yes',
              '✅ JA - Inschrijven',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'enrollment_no',
              '❌ NEE - Overslaan',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.destructive,
              },
            ),
          ],
        ),
      ],
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  static Future<void> requestPermissions() async {
    // Use permission_handler for consistent cross-platform permission handling
    final status = await Permission.notification.request();
    
    if (status.isGranted) {
      print('✅ Notification permissions granted');
    } else if (status.isDenied) {
      print('❌ Notification permissions denied');
    } else if (status.isPermanentlyDenied) {
      print('⚠️ Notification permissions permanently denied');
    }

    // Also initialize platform-specific settings
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'jachtproef_alerts',
      'Jachtproef Alerts',
      channelDescription: 'Notifications for hunting exam alerts',
      importance: Importance.high,
      priority: Priority.high,
      actions: actions,
    );

    // For iOS, we need to set up action buttons differently
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: actions != null ? 'enrollment_actions' : null,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'jachtproef_alerts',
      'Jachtproef Alerts',
      channelDescription: 'Scheduled notifications for hunting exam alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('🔔 Notification tapped: ${response.actionId}, payload: ${response.payload}');
    
    // Handle enrollment confirmation responses
    if (response.payload?.startsWith('enrollment_check|') == true) {
      final parts = response.payload!.split('|');
      if (parts.length >= 5) {
        final matchKey = parts[1];
        final huntTitle = parts[2];
        final huntLocation = parts[3];
        final huntType = parts[4];
        
        if (response.actionId == 'enrollment_yes') {
          _handleEnrollmentConfirmation(matchKey, huntTitle, huntLocation, huntType, true);
        } else if (response.actionId == 'enrollment_no') {
          _handleEnrollmentConfirmation(matchKey, huntTitle, huntLocation, huntType, false);
        }
      }
    }
  }

  // Callback for handling enrollment responses
  static Function(String, String, String, String, bool)? onEnrollmentResponse;

  static void _handleEnrollmentConfirmation(
    String matchKey,
    String huntTitle, 
    String huntLocation,
    String huntType,
    bool enrolled,
  ) {
    print('🎯 NOTIFICATION: User ${enrolled ? "confirmed enrollment" : "declined enrollment"} for $huntTitle');
    
    // Call the callback if it's set
    if (onEnrollmentResponse != null) {
      onEnrollmentResponse!(matchKey, huntTitle, huntLocation, huntType, enrolled);
    }
  }

  // Specific methods for hunting exam alerts
  static Future<void> scheduleExamReminder({
    required String examLocation,
    required DateTime examDate,
    required Duration reminderBefore,
  }) async {
    final notificationTime = examDate.subtract(reminderBefore);
    
    await scheduleNotification(
      id: examDate.hashCode,
      title: 'Jachtproef Herinnering',
      body: 'Je jachtproef in $examLocation is over ${_formatDuration(reminderBefore)}',
      scheduledTime: notificationTime,
      payload: 'exam_reminder_${examDate.millisecondsSinceEpoch}',
    );
  }

  static Future<void> showExamAlert({
    required String message,
    required String location,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch,
      title: 'Jachtproef Alert',
      body: '$message - $location',
      payload: 'exam_alert',
    );
  }

  static Future<void> showEnrollmentConfirmationNotification({
    required String huntTitle,
    required String huntLocation,
    required String huntType,
    required DateTime enrollmentDeadline,
    required String matchKey,
  }) async {
    await scheduleEnrollmentConfirmationNotification(
      id: matchKey.hashCode,
      huntTitle: huntTitle,
      huntLocation: huntLocation,
      huntType: huntType,
      enrollmentDeadline: enrollmentDeadline,
      matchKey: matchKey,
      scheduledTime: null, // Show immediately
    );
  }

  static Future<void> scheduleEnrollmentConfirmationNotification({
    required int id,
    required String huntTitle,
    required String huntLocation,
    required String huntType,
    required DateTime enrollmentDeadline,
    required String matchKey,
    DateTime? scheduledTime,
  }) async {
    // Create action buttons for Yes/No response
    const List<AndroidNotificationAction> actions = [
      AndroidNotificationAction(
        'enrollment_yes',
        '✅ JA - Inschrijven',
        icon: DrawableResourceAndroidBitmap('ic_check'),
        contextual: true,
      ),
      AndroidNotificationAction(
        'enrollment_no', 
        '❌ NEE - Overslaan',
        icon: DrawableResourceAndroidBitmap('ic_close'),
        contextual: true,
      ),
    ];

    // Get first 3 words of organizer + province from location + proef type
    final organizer = _getFirst3WordsOfOrganizer(huntTitle);
    final province = _extractProvinceFromLocation(huntLocation);
    final proefType = _getProefTypeAbbreviation(huntType);
    
    // Avoid duplicating province if it's already in the organizer name
    final shouldShowProvince = province.isNotEmpty && 
        !_organizerContainsProvince(organizer, province);
    
    // Debug logging
    print('🔔 NOTIFICATION DEBUG:');
    print('  Original title: $huntTitle');
    print('  Original location: $huntLocation');
    print('  Hunt type: $huntType');
    print('  Organizer (first 3 words): $organizer');
    print('  Province from location: $province');
    print('  Proef type: $proefType');
    print('  Should show province: $shouldShowProvince');
    
    // Create the notification body with proef type
    final String notificationBody;
    if (shouldShowProvince) {
      notificationBody = '$proefType | $organizer - $province\nGa je inschrijven?';
    } else {
      notificationBody = '$proefType | $organizer\nGa je inschrijven?';
    }

    if (scheduledTime != null) {
      // Schedule the notification for later (without action buttons for scheduled notifications)
      await scheduleNotification(
        id: id,
        title: '🎯 Inschrijving Open!',
        body: notificationBody,
        scheduledTime: scheduledTime,
        payload: 'enrollment_check|$matchKey|$huntTitle|$huntLocation|$huntType',
      );
    } else {
      // Show immediately (with action buttons)
      await showNotification(
        id: id,
        title: '🎯 Inschrijving Open!',
        body: notificationBody,
        payload: 'enrollment_check|$matchKey|$huntTitle|$huntLocation|$huntType',
        actions: actions,
      );
    }
  }

  static String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} dag${duration.inDays != 1 ? 'en' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} uur';
    } else {
      return '${duration.inMinutes} minuten';
    }
  }

  static String _getFirst3WordsOfOrganizer(String organizationName) {
    // Split into words and clean up
    List<String> words = organizationName
        .split(RegExp(r'[,\s]+'))
        .where((word) => word.isNotEmpty)
        .toList();
    
    // Apply abbreviations and skip province-related words and actual province names
    List<String> processedWords = [];
    
    for (String word in words) {
      // Skip province-related words entirely
      if (_isProvinceRelatedWord(word.toLowerCase())) {
        continue;
      }
      
      // Skip actual province names entirely
      if (_isProvinceName(word.toLowerCase())) {
        continue;
      }
      
      // Apply abbreviations
      String abbreviated = _abbreviateWord(word);
      processedWords.add(abbreviated);
      
      // Stop when we have 3 meaningful words
      if (processedWords.length >= 3) {
        break;
      }
    }
    
    return processedWords.join(' ');
  }
  
  static bool _isProvinceRelatedWord(String word) {
    // Words to skip when building organizer name
    const provinceWords = [
      'provincie', 'prov.', 'prov', 'locatie', 'afd.', 'afdeling',
      'regio', 'region', 'gebied', 'district'
    ];
    
    return provinceWords.contains(word.toLowerCase());
  }

  static bool _isProvinceName(String word) {
    // Actual Dutch province names to skip when building organizer name
    const provinceNames = [
      'noord-holland', 'zuid-holland', 'noord-brabant', 'overijssel',
      'gelderland', 'utrecht', 'limburg', 'groningen', 'friesland', 'fryslân',
      'drenthe', 'zeeland', 'flevoland'
    ];
    
    return provinceNames.contains(word.toLowerCase());
  }

  static String _abbreviateWord(String word) {
    // Apply common abbreviations to save space
    String abbreviatedWord = word
        .replaceAll('Stichting', 'St.')
        .replaceAll('Vereniging', 'Ver.')
        .replaceAll('Nederlandse', 'NL')
        .replaceAll('Jachthonden', 'JH')
        .replaceAll('Provincie', 'Prov.');
    
    return abbreviatedWord;
  }

  static String _extractProvinceFromLocation(String location) {
    // Extract province from location string using city/town mapping
    final loc = location.toLowerCase();
    
    // Remove common prefixes and clean up the location string
    String cleanLocation = loc
        .replaceAll(RegExp(r'^(locatie|adres|plaats):\s*'), '')
        .replaceAll(RegExp(r'\s+\d+.*$'), '') // Remove house numbers and everything after
        .replaceAll(RegExp(r'\s+(straat|weg|laan|plein|park).*$'), '') // Remove street types
        .trim();
    
    // Split by common separators and check each part
    final locationParts = cleanLocation.split(RegExp(r'[,\-\s]+'));
    
    for (String part in locationParts) {
      final trimmedPart = part.trim();
      if (trimmedPart.length < 2) continue; // Skip very short parts
      
      final province = _getCityProvince(trimmedPart);
      if (province.isNotEmpty) {
        return province;
      }
    }
    
    // Fallback: check the full location string
    return _getCityProvince(cleanLocation);
  }

  static String _getCityProvince(String cityName) {
    // Comprehensive Dutch city-to-province mapping
    final city = cityName.toLowerCase().trim();
    
    // Noord-Holland
    if (_isInNoordHolland(city)) return 'Noord-Holland';
    
    // Zuid-Holland  
    if (_isInZuidHolland(city)) return 'Zuid-Holland';
    
    // Noord-Brabant
    if (_isInNoordBrabant(city)) return 'Noord-Brabant';
    
    // Gelderland
    if (_isInGelderland(city)) return 'Gelderland';
    
    // Overijssel
    if (_isInOverijssel(city)) return 'Overijssel';
    
    // Utrecht
    if (_isInUtrecht(city)) return 'Utrecht';
    
    // Limburg
    if (_isInLimburg(city)) return 'Limburg';
    
    // Groningen
    if (_isInGroningen(city)) return 'Groningen';
    
    // Friesland
    if (_isInFriesland(city)) return 'Friesland';
    
    // Drenthe
    if (_isInDrenthe(city)) return 'Drenthe';
    
    // Flevoland
    if (_isInFlevoland(city)) return 'Flevoland';
    
    // Zeeland
    if (_isInZeeland(city)) return 'Zeeland';
    
    return ''; // No province found
  }

  static bool _isInNoordHolland(String city) {
    const cities = [
      'amsterdam', 'haarlem', 'alkmaar', 'hoorn', 'zaandam', 'hilversum',
      'amstelveen', 'hoofddorp', 'ijmuiden', 'heerhugowaard', 'purmerend',
      'castricum', 'beverwijk', 'uitgeest', 'krommenie', 'wormerveer',
      'volendam', 'edam', 'monnickendam', 'waterland', 'landsmeer',
      'oostzaan', 'wormerland', 'beemster', 'graft-de rijp', 'schermer',
      'heiloo', 'limmen', 'akersloot', 'uithoorn', 'aalsmeer', 'diemen',
      'ouder-amstel', 'de ronde venen', 'abcoude', 'weesp', 'muiden',
      'naarden', 'bussum', 'huizen', 'blaricum', 'laren', 'eemnes',
      'baarn', 'soest', 'bunschoten', 'spakenburg', 'nijkerk', 'harderwijk'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInZuidHolland(String city) {
    const cities = [
      'rotterdam', 'den haag', 'dordrecht', 'leiden', 'zoetermeer', 'delft',
      'alphen aan den rijn', 'westland', 'gouda', 'spijkenisse', 'capelle aan den ijssel',
      'hellevoetsluis', 'ridderkerk', 'vlaardingen', 'schiedam', 'maassluis',
      'papendrecht', 'sliedrecht', 'zwijndrecht', 'hendrik-ido-ambacht',
      'alblasserdam', 'nieuw-lekkerland', 'liesveld', 'graafstroom',
      'bodegraven-reeuwijk', 'waddinxveen', 'boskoop', 'rijnwoude',
      'katwijk', 'noordwijk', 'teylingen', 'hillegom', 'lisse', 'voorhout',
      'oegstgeest', 'wassenaar', 'voorschoten', 'leidschendam-voorburg',
      'rijswijk', 'pijnacker-nootdorp', 'lansingerland', 'zoeterwoude'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInNoordBrabant(String city) {
    const cities = [
      'eindhoven', 'tilburg', 'breda', 's-hertogenbosch', 'den bosch',
      'helmond', 'oss', 'roosendaal', 'bergen op zoom', 'veghel',
      'uden', 'best', 'oosterhout', 'waalwijk', 'valkenswaard', 'veldhoven',
      'geldrop-mierlo', 'nuenen', 'son en breugel', 'cranendonck',
      'heeze-leende', 'laarbeek', 'gemert-bakel', 'asten', 'someren',
      'deurne', 'peel en maas', 'horst aan de maas', 'venray', 'gennep',
      'boxmeer', 'cuijk', 'grave', 'mill en sint hubert', 'landerd',
      'bernheze', 'maasdonk', 'schijndel', 'sint-michielsgestel',
      'vught', 'boxtel', 'haaren', 'oisterwijk', 'hilvarenbeek',
      'goirle', 'reusel-de mierden', 'bladel', 'bergeijk', 'eersel'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInGelderland(String city) {
    const cities = [
      'nijmegen', 'arnhem', 'apeldoorn', 'ede', 'doetinchem', 'zutphen',
      'harderwijk', 'winterswijk', 'tiel', 'wijchen', 'zevenaar', 'duiven',
      'rheden', 'rozendaal', 'lingewaard', 'overbetuwe', 'heumen',
      'mook en middelaar', 'gennep', 'bergen', 'cuijk', 'grave',
      'druten', 'beuningen', 'west maas en waal', 'geldermalsen',
      'neder-betuwe', 'lingewaal', 'maasdriel', 'zaltbommel', 'werkendam',
      'gorinchem', 'hardinxveld-giessendam', 'molenwaard', 'liesveld',
      'montfoort', 'oudewater', 'woerden', 'de ronde venen', 'utrecht',
      'terborg', 'silvolde', 'gendringen', 'wisch', 'zelhem', 'hengelo',
      'vorden', 'ruurlo', 'groenlo', 'lichtenvoorde', 'eibergen'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInOverijssel(String city) {
    const cities = [
      'enschede', 'zwolle', 'deventer', 'almelo', 'hengelo', 'oldenzaal',
      'kampen', 'hardenberg', 'steenwijk', 'genemuiden', 'hasselt',
      'zwartsluis', 'staphorst', 'dalfsen', 'ommen', 'hardenberg',
      'gramsbergen', 'dedemsvaart', 'avereest', 'balkbrug', 'lutten',
      'mariënheem', 'nieuwleusen', 'vilsteren', 'wijhe', 'raalte',
      'heino', 'wijthmen', 'hellendoorn', 'nijverdal', 'wierden',
      'enter', 'rijssen', 'holten', 'markelo', 'goor', 'diepenheim',
      'neede', 'borculo', 'ruurlo', 'haaksbergen', 'usselo', 'denekamp',
      'tubbergen', 'weerselo', 'losser', 'overdinkel', 'de lutte'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInUtrecht(String city) {
    const cities = [
      'utrecht', 'amersfoort', 'veenendaal', 'nieuwegein', 'zeist',
      'woerden', 'houten', 'vianen', 'ijsselstein', 'bunnik', 'de bilt',
      'bilthoven', 'maarssen', 'breukelen', 'loenen', 'abcoude',
      'de ronde venen', 'oudewater', 'montfoort', 'lopik', 'polsbroek',
      'kamerik', 'harmelen', 'bodegraven', 'reeuwijk', 'driebruggen',
      'waarder', 'zegveld', 'ter aar', 'nieuwkoop', 'langeraar',
      'noorden', 'papekop', 'rietveld', 'zevenhoven', 'brakel',
      'heuvelrug', 'doorn', 'leersum', 'maarn', 'maarsbergen',
      'driebergen', 'rijsenburg', 'austerlitz', 'bosch en duin'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInLimburg(String city) {
    const cities = [
      'maastricht', 'heerlen', 'sittard', 'geleen', 'venlo', 'roermond',
      'kerkrade', 'brunssum', 'landgraaf', 'valkenburg', 'meerssen',
      'eijsden-margraten', 'gulpen-wittem', 'vaals', 'simpelveld',
      'nuth', 'onderbanken', 'schinnen', 'sittard-geleen', 'stein',
      'beek', 'berg en terblijt', 'voerendaal', 'heerlen', 'kerkrade',
      'weert', 'nederweert', 'cranendonck', 'leudal', 'maasgouw',
      'roerdalen', 'roermond', 'echt-susteren', 'mook en middelaar',
      'gennep', 'bergen', 'venray', 'horst aan de maas', 'peel en maas',
      'beesel', 'reuver', 'kessel', 'maasbree', 'sevenum', 'helden',
      'panningen', 'melderslo', 'koningslust', 'heel', 'thorn'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInGroningen(String city) {
    const cities = [
      'groningen', 'hoogezand-sappemeer', 'veendam', 'stadskanaal',
      'winschoten', 'delfzijl', 'appingedam', 'loppersum', 'bedum',
      'ten boer', 'zuidhorn', 'leek', 'marum', 'grootegast', 'winsum',
      'de marne', 'eemsmond', 'het hogeland', 'westerkwartier',
      'oldambt', 'pekela', 'menterwolde', 'slochteren', 'scheemda',
      'reiderland', 'bellingwedde', 'vlagtwedde', 'bourtange',
      'ter apel', 'musselkanaal', 'onstwedde', 'wedde', 'vriescheloo',
      'sellingen', 'jipsinghuizen', 'blijham', 'nieuweschans',
      'finsterwolde', 'bad nieuweschans', 'beerta', 'nieuw beerta'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInFriesland(String city) {
    const cities = [
      'leeuwarden', 'sneek', 'heerenveen', 'drachten', 'harlingen',
      'franeker', 'dokkum', 'bolsward', 'workum', 'stavoren', 'hindeloopen',
      'ijlst', 'sloten', 'lemmer', 'joure', 'balk', 'grouw', 'grou',
      'earnewâld', 'burgum', 'surhuisterveen', 'buitenpost', 'kollum',
      'kollumerland', 'achtkarspelen', 'tytsjerksteradiel', 'opsterland',
      'smallingerland', 'ooststellingwerf', 'weststellingwerf',
      'súdwest-fryslân', 'waadhoeke', 'noardeast-fryslân', 'ameland',
      'schiermonnikoog', 'vlieland', 'terschelling', 'de fryske marren',
      'weststellingwerf', 'ooststellingwerf', 'haulerwijk', 'gorredijk',
      'beetsterzwaag', 'ureterp', 'kootstertille', 'drogeham'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInDrenthe(String city) {
    const cities = [
      'assen', 'emmen', 'hoogeveen', 'meppel', 'coevorden', 'hardenberg',
      'westerbork', 'beilen', 'zuidlaren', 'roden', 'peize', 'norg',
      'vries', 'tynaarlo', 'eelde', 'paterswolde', 'midlaren', 'noordlaren',
      'annen', 'gieten', 'gasselte', 'gasselternijveen', 'drouwen',
      'borger', 'exloo', 'odoorn', 'valthe', 'tweede exloërmond',
      'eerste exloërmond', 'nieuw-amsterdam', 'veenoord', 'klazienaveen',
      'nieuw-weerdinge', 'weiteveen', 'zwartemeer', 'roswinkel',
      'uffelte', 'diever', 'dwingeloo', 'ruinen', 'koekange', 'doldersum',
      'lhee', 'lheebroek', 'wittelte', 'wilhelminaoord', 'frederiksoord'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInFlevoland(String city) {
    const cities = [
      'almere', 'lelystad', 'dronten', 'swifterbant', 'biddinghuizen',
      'zeewolde', 'harderwijk', 'hierden', 'elburg', 'oldebroek',
      'nunspeet', 'ermelo', 'putten', 'nijkerk', 'bunschoten',
      'spakenburg', 'eemdijk', 'baarn', 'soest', 'amersfoort',
      'hoogland', 'vathorst', 'nieuwland', 'muziekwijk', 'filmwijk',
      'literatuurwijk', 'stedenwijk', 'danswijk', 'theaterbuurt',
      'cascadepark', 'noorderplassen', 'overgooi', 'poort', 'stad',
      'haven', 'hout', 'buiten', 'centrum', 'pampus', 'oostvaarders'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static bool _isInZeeland(String city) {
    const cities = [
      'middelburg', 'vlissingen', 'terneuzen', 'goes', 'hulst', 'zierikzee',
      'veere', 'kapelle', 'reimerswaal', 'borsele', 'sluis', 'oostburg',
      'cadzand', 'breskens', 'groede', 'nieuwvliet', 'retranchement',
      'schoondijke', 'waterlandkerkje', 'zuidzande', 'eede', 'aardenburg',
      'sint jansteen', 'koewacht', 'sas van gent', 'zelzate', 'axel',
      'biervliet', 'hoek', 'perkpolder', 'kloosterzande', 'kruiningen',
      'yerseke', 'rilland', 'bath', 'hoedekenskerke', 'nisse', 'baarland',
      'kwadendamme', 'heinkenszand', 'kattendijke', 'wolphaartsdijk',
      'kortgene', 'wissenkerke', 'kamperland', 'gapinge', 'serooskerke'
    ];
    return cities.any((c) => city.contains(c) || c.contains(city));
  }

  static String _getProefTypeAbbreviation(String huntType) {
    // Convert hunt type to very short abbreviation
    switch (huntType.toUpperCase()) {
      case 'MAP': return 'MAP';
      case 'SWT': return 'SWT';
      case 'TAP': return 'TAP';
      case 'KAP': return 'KAP';
      case 'SJP': return 'SJP';
      case 'PROEF': return 'Proef';
      default: return huntType.isNotEmpty ? huntType.substring(0, huntType.length > 4 ? 4 : huntType.length) : 'Proef';
    }
  }

  static String _abbreviateOrganizationName(String organizationName) {
    if (organizationName.length <= 30) return organizationName;
    
    // Apply aggressive abbreviations for hunting organizations
    String abbreviated = organizationName
        .replaceAll('Stichting Jachthonden', 'St. JH')
        .replaceAll('Stichting Jachthondentraining', 'St. JHT')
        .replaceAll('Stichting Jachthondenopleiding', 'St. JHO')
        .replaceAll('Stichting', 'St.')
        .replaceAll('Vereniging', 'Ver.')
        .replaceAll('Jachthonden', 'JH')
        .replaceAll('Jachthondentraining', 'JHT')
        .replaceAll('Jachthondenopleiding', 'JHO')
        .replaceAll('i.s.m:', '&')
        .replaceAll('Provincie', 'Prov.')
        .replaceAll('Nederland', 'NL')
        .replaceAll('Nederlandse', 'NL')
        .replaceAll('Noord-Holland', 'N-H')
        .replaceAll('Noord-Brabant', 'N-B')
        .replaceAll('Zuid-Holland', 'Z-H')
        .replaceAll('Overijssel', 'OV')
        .replaceAll('Gelderland', 'GLD')
        .replaceAll('Flevoland', 'FL')
        .replaceAll('Limburg', 'LB')
        .replaceAll('Groningen', 'GR')
        .replaceAll('Drenthe', 'DR')
        .replaceAll('Friesland', 'FR')
        .replaceAll('Utrecht', 'UT')
        .replaceAll('Zeeland', 'ZL')
        .replaceAll('afdeling', 'afd.');
    
    // If still too long, find the first meaningful part and truncate
    if (abbreviated.length > 30) {
      // Try to keep the most important part (first organization name)
      final parts = abbreviated.split(' ');
      if (parts.isNotEmpty) {
        String result = parts[0];
        for (int i = 1; i < parts.length && result.length + parts[i].length + 1 <= 27; i++) {
          result += ' ${parts[i]}';
        }
        return '$result...';
      }
      return '${abbreviated.substring(0, 27)}...';
    }
    
    return abbreviated;
  }

  static String _abbreviateLocation(String location) {
    if (location.length <= 25) return location;
    
    String abbreviated = location
        .replaceAll('Aanvang:', '')
        .replaceAll('aanvang:', '')
        .replaceAll(' nabij ', ' bij ')
        .replaceAll('Landgoed', 'Ldg.')
        .replaceAll('Sportpark', 'Park')
        .replaceAll('Gemeentehuis', 'Gmhuis')
        .replaceAll('Recreatiegebied', 'Recreatie')
        .replaceAll('Natuurgebied', 'Natuur')
        .trim();
    
    if (abbreviated.length > 25) {
      // Try to keep the city/main location name
      final parts = abbreviated.split(' ');
      if (parts.length > 1) {
        // Keep the last part (usually the city) and first meaningful part
        String lastPart = parts.last;
        if (lastPart.length <= 20) {
          return '${parts.first}...${lastPart}';
        }
      }
      return '${abbreviated.substring(0, 22)}...';
    }
    
    return abbreviated;
  }

  static String _getProvinceAbbreviation(String province) {
    // Return common abbreviations used in organizer names
    switch (province.toLowerCase()) {
      case 'noord-holland': return 'noord-holland';
      case 'zuid-holland': return 'zuid-holland';
      case 'noord-brabant': return 'noord-brabant';
      case 'overijssel': return 'overijssel';
      case 'gelderland': return 'gelderland';
      case 'utrecht': return 'utrecht';
      case 'limburg': return 'limburg';
      case 'groningen': return 'groningen';
      case 'friesland': return 'friesland';
      case 'fryslân': return 'friesland';
      case 'drenthe': return 'drenthe';
      case 'flevoland': return 'flevoland';
      case 'zeeland': return 'zeeland';
      default: return province.toLowerCase();
    }
  }

  static bool _organizerContainsProvince(String organizer, String province) {
    // Split organizer into words and check if any word contains the province
    final words = organizer.split(' ');
    for (String word in words) {
      if (word.toLowerCase().contains(province.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
} 