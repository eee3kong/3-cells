import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:latlong2/latlong.dart';

class SiteArea {
  final int id;
  final double pm25;
  final double pm10;
  final double db;
  final bool mist;
  SiteArea({required this.id, required this.pm25, required this.pm10, required this.db, required this.mist});
}

class DetailedWork {
  final String id;
  final int start;
  final int end;
  final String type;
  final int area;
  final String noise;
  final String dust;
  DetailedWork({required this.id, required this.start, required this.end, required this.type, required this.area, required this.noise, required this.dust});
}

class RenovationSite {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lng;
  
  double noise; 
  double dust;
  double pm10;  
  bool pump;
  String stage;
  String endDate;
  List<dynamic> tasks;
  List<dynamic> history;
  List<SiteArea> areas;
  List<DetailedWork> detailedSchedule;
  List<Map<String, String>> weeklyPlan;

  RenovationSite({
    required this.id, required this.name, required this.type,
    required this.lat, required this.lng,
    required this.noise, required this.dust, required this.pm10,
    this.pump = false, this.stage = "Earthworks", this.endDate = "Unknown",
    this.tasks = const [], this.history = const [],
    this.areas = const [], this.detailedSchedule = const [], this.weeklyPlan = const [],
  });
}

class LogEvent {
  final String id;
  final String siteId;
  final String time;
  final String incident;
  final String action;
  String outcome;
  bool isActive;
  int timestamp;

  LogEvent({
    required this.id, required this.siteId, required this.time, required this.incident, 
    required this.action, required this.outcome, required this.isActive, 
    required this.timestamp
  });
}

class BuildWatchBackend extends ChangeNotifier {
  static final BuildWatchBackend _instance = BuildWatchBackend._internal();
  factory BuildWatchBackend() => _instance;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('buildwatch');

  static const double px = 0.645;
  static const double alpha = 0.2;
  static const double ln10 = 2.302585092994046;

  bool isNoiseMode = false;
  bool showForecast = false;
  
  double windFrom = 180.0; 
  double windSpeed = 5.0;  
  double baseAQI = 191.0;
  
  double currentNoise = 50.0;
  double currentAQI = 191.0;
  double pm25 = 120.0;
  double pm10 = 196.0;

  bool notificationsEnabled = true;
  double logRadius = 2000.0; 
  List<LogEvent> _allLogs = [];

  String selectedArea = "Elmina Green 4";
  String selectedStreet = "U17/106";
  String houseNumber = "38";
  late Map<String, dynamic> selectedAddress;
  late LatLng homeLocation;

  final List<String> availableStreets = [
    "U17/103", "U17/104", "U17/105", "U17/106", "U17/107",
    "U17/108", "U17/109", "U17/110", "U17/111", "U17/112"
  ];

  final Map<String, List<Map<String, dynamic>>> sdpAreas = {
    "Elmina Green 4": [
      {"address": "No. 16, Jln Samanea U17/106", "lat": 3.220, "lng": 101.492},
    ],
    "Bandar Bukit Raja": [
      {"address": "No. 8, Jln Singgahsana 2", "lat": 3.078, "lng": 101.445},
    ],
    "Serenia City": [
      {"address": "No. 12, Jln Serenia 1", "lat": 2.827, "lng": 101.637},
    ],
    "Nilai Impian": [
      {"address": "No. 5, Jln Laman Mawar", "lat": 2.839, "lng": 101.802},
    ],
    "Bandar Ainsdale": [
      {"address": "No. 20, Jln Ainsdale 4/1", "lat": 2.730, "lng": 101.889},
    ],
  };

  final Map<String, List<String>> areaStreets = {
    "Elmina Green 4": ["U17/103", "U17/104", "U17/105", "U17/106", "U17/107"],
    "Bandar Bukit Raja": ["Jln Singgahsana 1", "Jln Singgahsana 2", "Jln Makyong", "Jln Sumazau"],
    "Serenia City": ["Jln Serenia 1", "Jln Serenia 2", "Jln Aman Serenia"],
    "Nilai Impian": ["Jln Laman Mawar", "Jln Laman Delfina", "Jln Laman Orkid"],
    "Bandar Ainsdale": ["Jln Ainsdale 1/1", "Jln Ainsdale 2/1", "Jln Ainsdale 3/1"],
  };

  final Map<String, LatLng> areaBaseCoordinates = {
    "Elmina Green 4": const LatLng(3.2065, 101.4945),
    "Bandar Bukit Raja": const LatLng(3.0780, 101.4450),
    "Serenia City": const LatLng(2.8270, 101.6370),
    "Nilai Impian": const LatLng(2.8390, 101.8020),
    "Bandar Ainsdale": const LatLng(2.7300, 101.8890),
  };

  List<RenovationSite> sites = [];

  BuildWatchBackend._internal() {
    selectedAddress = sdpAreas[selectedArea]!.first;
    homeLocation = _generateCoordinateFromAddress(selectedArea, selectedStreet, houseNumber);
    _listenToFirebase();
  }

  List<LogEvent> get filteredLogs {
    return _allLogs.where((log) {
      try {
        var site = sites.firstWhere((s) => s.id == log.siteId);
        double dist = calculateDistance(homeLocation, LatLng(site.lat, site.lng));
        return dist <= logRadius;
      } catch (e) {
        return true; 
      }
    }).toList();
  }

  int get filteredMistingCycles {
    return filteredLogs.where((l) => l.incident.toUpperCase().contains('DUST')).length;
  }

  int get filteredContractorAlerts {
    return filteredLogs.where((l) => l.incident.toUpperCase().contains('NOISE')).length;
  }

  void updateLogRadius(double radius) {
    logRadius = radius;
    notifyListeners();
  }

  void toggleNotifications(bool value) {
    notificationsEnabled = value;
    notifyListeners();
  }

  void toggleMode([bool? forceNoiseMode]) {
    if (forceNoiseMode != null) {
      isNoiseMode = forceNoiseMode;
    } else {
      isNoiseMode = !isNoiseMode;
    }
    notifyListeners();
  }

  void toggleForecast() {
    showForecast = !showForecast;
    notifyListeners();
  }

  void updateHomeArea(String area) {
    selectedArea = area;
    selectedStreet = areaStreets[area]!.first; 
    houseNumber = "1"; 
    homeLocation = _generateCoordinateFromAddress(selectedArea, selectedStreet, houseNumber);
    _recalculateHomeImpact();
    notifyListeners();
  }

  void updateHomeAddress(String street, String no) {
    selectedStreet = street;
    houseNumber = no;
    homeLocation = _generateCoordinateFromAddress(selectedArea, street, no);
    _recalculateHomeImpact();
    notifyListeners();
  }

  LatLng _generateCoordinateFromAddress(String area, String street, String no) {
    LatLng base = areaBaseCoordinates[area] ?? const LatLng(3.2065, 101.4945);
    int streetIdx = areaStreets[area]?.indexOf(street) ?? 0;
    if (streetIdx == -1) streetIdx = 0;
    int hNo = int.tryParse(no) ?? 1;

    double latOffset = streetIdx * 0.0003; 
    double lngOffset = hNo * 0.00004;     

    return LatLng(base.latitude + latOffset, base.longitude + lngOffset);
  }

  double calculateDistance(LatLng p1, LatLng p2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2);
  }

  Color getStatusColor(double dust, double noise, bool checkNoise) {
    if (checkNoise) {
      if (noise >= 80) return const Color(0xFFE5213A); 
      if (noise >= 70) return const Color(0xFFCB7E00); 
      return const Color(0xFF12B76A);                
    } else {
      if (dust >= 100) return const Color(0xFFE5213A);
      if (dust >= 80) return const Color(0xFFCB7E00);
      return const Color(0xFF12B76A);
    }
  }

  List<Map<String, dynamic>> generateForecast() {
    List<Map<String, dynamic>> forecast = [];
    DateTime now = DateTime.now();
    for (int i = 0; i < 24; i++) {
      DateTime t = now.add(Duration(hours: i));
      bool isWorkingHour = t.hour >= 9 && t.hour < 17;
      
      double fAqi = baseAQI + (isWorkingHour ? (sin(i) * 15 + 8) : (sin(i) * 5 - 15));
      double fNoise = 45 + (isWorkingHour ? (cos(i) * 10 + 12) : -5);
      
      forecast.add({
        "time": "${t.hour.toString().padLeft(2, '0')}:00",
        "aqi": fAqi.round(),
        "noise": fNoise.round(),
        "isWorking": isWorkingHour,
        "isActive": i == 0 
      });
    }
    return forecast;
  }

  static const double basePM25 = 112.0;
  static const double basePM10 = 179.0;

  void _recalculateHomeImpact() {
    double windX = sin((windFrom + 180) * pi / 180);
    double windY = -cos((windFrom + 180) * pi / 180);

    double nLog = 0;
    double totalDust = 0;

    for (var s in sites) {
      double distMeters = calculateDistance(homeLocation, LatLng(s.lat, s.lng));
      double dx = homeLocation.longitude - s.lng;
      double dy = homeLocation.latitude - s.lat;
      double dLen = sqrt(dx * dx + dy * dy);
      double c = dLen == 0 ? 0 : (dx * windX + dy * windY) / dLen;
      
      double d = max(1.5, distMeters * 0.05);

      double l = s.noise - 20 * (log(d) / ln10) - 6 - 0.06 * d;
      if (l > 38 && distMeters > 40) l -= 10.0; 
      nLog += pow(10, l / 10);

      double v = s.dust * exp(-alpha * d * (1 - 0.6 * min(1.0, windSpeed / 8) * c)) * max(0.1, 0.55 + 0.45 * c);
      if (v > 0.3 && distMeters > 40) v *= 0.5; 
      totalDust += v;
    }

    currentNoise = nLog > 0 ? 10 * (log(nLog) / ln10) : 52.0;
    pm25 = basePM25 + totalDust;
    pm10 = basePM10 + (totalDust * 1.6);
    currentAQI = baseAQI + (totalDust * 0.5);
  }

  void _listenToFirebase() {
    _dbRef.child('sites').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<RenovationSite> updatedSites = [];
        data.forEach((key, value) {
          final live = value['live'] as Map<dynamic, dynamic>? ?? {};
          final config = value['config'] as Map<dynamic, dynamic>? ?? {};
          
          String siteType = live['type']?.toString() ?? 'Renovation';
          String siteName = live['name']?.toString() ?? key.toString();

          // LOAD ACTUAL FIREBASE COORDINATES INSTEAD OF HARDCODING
          double sx = (live['lat'] as num?)?.toDouble() ?? 3.2065;
          double sy = (live['lng'] as num?)?.toDouble() ?? 101.4945;

          List<SiteArea> parsedAreas = [];
          if (value['areas'] != null) {
            for (var a in value['areas']) {
              if (a != null) {
                parsedAreas.add(SiteArea(
                  id: (a['id'] as num?)?.toInt() ?? 1,
                  pm25: (a['pm25'] as num?)?.toDouble() ?? 0.0,
                  pm10: (a['pm10'] as num?)?.toDouble() ?? 0.0,
                  db: (a['db'] as num?)?.toDouble() ?? 0.0,
                  mist: a['mist'] == true,
                ));
              }
            }
          }

          List<DetailedWork> parsedWorks = [];
          if (config['schDetailed'] != null) {
            for (var w in config['schDetailed']) {
              if (w != null) {
                String taskType = w['type']?.toString() ?? 'Work';
                if (taskType == 'Others' && w['customType'] != null && w['customType'].toString().isNotEmpty) {
                  taskType = w['customType'].toString();
                }

                parsedWorks.add(DetailedWork(
                  id: w['id']?.toString() ?? '',
                  start: (w['start'] as num?)?.toInt() ?? 0,
                  end: (w['end'] as num?)?.toInt() ?? 0,
                  type: taskType,
                  area: (w['area'] as num?)?.toInt() ?? 1,
                  noise: w['noise']?.toString() ?? 'light',
                  dust: w['dust']?.toString() ?? 'light',
                ));
              }
            }
          }

          List<Map<String, String>> parsedWeekly = [];
          if (config['weeklyPlan'] != null) {
            for (var w in config['weeklyPlan']) {
              if (w != null) {
                String weekTask = w['task']?.toString() ?? '';
                if (weekTask == 'Others' && w['customTask'] != null && w['customTask'].toString().isNotEmpty) {
                  weekTask = w['customTask'].toString();
                }

                parsedWeekly.add({
                  "week": w['week']?.toString() ?? '',
                  "task": weekTask,
                });
              }
            }
          }

          double fallbackDust = ((live['dust'] as num?) ?? 30.0).toDouble();
          double fallbackNoise = ((live['noise'] as num?) ?? 50.0).toDouble();
          double finalDust = parsedAreas.isNotEmpty ? parsedAreas.map((a) => a.pm25).reduce(max) : fallbackDust;
          double finalPm10 = parsedAreas.isNotEmpty ? parsedAreas.map((a) => a.pm10).reduce(max) : fallbackDust * 1.6;
          double finalNoise = parsedAreas.isNotEmpty ? parsedAreas.map((a) => a.db).reduce(max) : fallbackNoise;

          updatedSites.add(RenovationSite(
            id: key.toString(),
            name: siteName,
            type: siteType,
            lat: sx,
            lng: sy,
            noise: finalNoise,
            dust: finalDust,
            pm10: finalPm10,
            pump: live['pump'] == true,
            stage: config['stage']?.toString() ?? 'Earthworks',
            endDate: config['end']?.toString() ?? 'Nov 15, 2026',
            tasks: (config['tasks'] as List<dynamic>?) ?? [],
            history: (live['hist'] as List<dynamic>?) ?? [], 
            areas: parsedAreas,
            detailedSchedule: parsedWorks,
            weeklyPlan: parsedWeekly,
          ));
        });
        sites = updatedSites;
        _recalculateHomeImpact();
        notifyListeners();
      }
    });

    _dbRef.child('events').orderByChild('start').limitToLast(100).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        List<LogEvent> updatedLogs = [];
        data.forEach((key, value) {
          final ev = value as Map<dynamic, dynamic>;
          
          String actionStr = ev['action']?.toString() ?? '';
          int ts = (ev['start'] as num?)?.toInt() ?? 0;
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(ts);
          
          String eventSiteId = ev['siteId']?.toString() ?? '';
          String kind = ev['kind']?.toString() ?? 'Alert'; 
          String area = ev['area']?.toString() ?? '1';
          String peak = ev['peak']?.toString() ?? '?';
          String limit = ev['limit']?.toString() ?? '?';
          
          String realSiteName = eventSiteId.toUpperCase();
          try {
            realSiteName = sites.firstWhere((s) => s.id == eventSiteId).name;
          } catch (_) {}
          
          bool isActive = ev['end'] == null;
          String outcomeStr = isActive ? 'Ongoing' : (kind == 'dust' ? 'Controlled by misting' : (actionStr.isNotEmpty ? 'Compliance restored' : 'Resolved'));
          
          updatedLogs.add(LogEvent(
            id: ev['id']?.toString() ?? key.toString(),
            siteId: eventSiteId,
            time: "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
            incident: "${kind.toUpperCase()} Breach at $realSiteName (Area $area): $peak vs limit $limit",
            action: actionStr.isEmpty ? 'Pending Response' : actionStr,
            outcome: outcomeStr,
            isActive: isActive,
            timestamp: ts,
          ));
        });
        updatedLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _allLogs = updatedLogs;
        notifyListeners();
      }
    });
  }
}