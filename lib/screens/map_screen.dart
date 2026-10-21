import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../backend.dart';

// 8-Band stepped colors as requested
const List<Color> _layerColors = [
  Color(0xFFB9F3CF), // Pale green
  Color(0xFF5FD88C),
  Color(0xFF22B35C), // Green
  Color(0xFFF2E94E), // Yellow
  Color(0xFFFFC233), // Amber
  Color(0xFFFF8A1F), // Orange
  Color(0xFFE5213A), // Red
  Color(0xFF8E0F2B), // Dark Red
];

const List<double> _noiseThresholds = [45, 50, 55, 60, 66, 72, 78, 85];
const List<double> _dustThresholds = [1.5, 4, 8, 15, 30, 60, 120, 200];

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final backend = BuildWatchBackend();
  final MapController _mapController = MapController();
  late TextEditingController _houseNoController;
  
  RenovationSite? selectedSite;

  @override
  void initState() {
    super.initState();
    _houseNoController = TextEditingController(text: backend.houseNumber);
  }

  @override
  void dispose() {
    _houseNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: backend,
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: backend.homeLocation,
                  initialZoom: 16.5,
                  onTap: (_, __) => setState(() => selectedSite = null), 
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.buildwatch.app',
                  ),
                  // Custom Canvas Heatmap implementation
                  CustomPaint(
                    size: Size.infinite,
                    painter: _HeatmapPainter(backend, _mapController),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: backend.homeLocation,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFF1F2937), width: 5),
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                        ),
                      ),
                      ...backend.sites.map((s) {
                        Color pinColor = backend.getStatusColor(s.dust, s.noise, backend.isNoiseMode);
                        IconData siteIcon = s.type.toLowerCase().contains('construction') 
                            ? Icons.construction 
                            : Icons.home_repair_service;

                        return Marker(
                          point: LatLng(s.lat, s.lng),
                          width: 32,
                          height: 32,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => selectedSite = s);
                              _mapController.move(LatLng(s.lat - 0.001, s.lng), 17.0); 
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: pinColor,
                                border: Border.all(color: Colors.white, width: 2.5),
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                              ),
                              child: Icon(siteIcon, color: Colors.white, size: 16),
                            ),
                          ),
                        );
                      })
                    ],
                  ),
                ],
              ),

              Positioned(
                top: 50,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))]
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Neighbourhood", style: TextStyle(color: Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: backend.selectedArea,
                                isDense: true,
                                isExpanded: true, 
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                items: backend.areaStreets.keys.map((area) {
                                  return DropdownMenuItem(value: area, child: Text(area, overflow: TextOverflow.ellipsis));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    backend.updateHomeArea(val);
                                    _houseNoController.text = backend.houseNumber;
                                    _mapController.move(backend.homeLocation, 15.5);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("My home", style: TextStyle(color: Color(0xFFFF6B00), fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4EA),
                                      border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: backend.selectedStreet,
                                        isDense: true,
                                        isExpanded: true, 
                                        icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937), fontSize: 13),
                                        items: backend.areaStreets[backend.selectedArea]!.map((street) {
                                          return DropdownMenuItem(value: street, child: Text(street, overflow: TextOverflow.ellipsis));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            backend.updateHomeAddress(val, _houseNoController.text);
                                            _mapController.move(backend.homeLocation, 16.5);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 45,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF4EA),
                                    border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextField(
                                    controller: _houseNoController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.only(bottom: 14),
                                    ),
                                    onSubmitted: (val) {
                                      backend.updateHomeAddress(backend.selectedStreet, val);
                                      _mapController.move(backend.homeLocation, 16.5);
                                    },
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),

              Positioned(
                right: 16,
                top: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: "layerToggle",
                      mini: true,
                      backgroundColor: const Color(0xFFFF6B00),
                      foregroundColor: Colors.white,
                      onPressed: () => backend.toggleMode(),
                      child: Icon(backend.isNoiseMode ? Icons.volume_up : Icons.waves),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: "forecastToggle",
                      mini: true,
                      backgroundColor: backend.showForecast ? const Color(0xFF1F2937) : Colors.white,
                      foregroundColor: backend.showForecast ? Colors.white : const Color(0xFF1F2937),
                      onPressed: () => backend.toggleForecast(),
                      child: const Icon(Icons.access_time),
                    ),
                  ],
                ),
              ),

              DraggableScrollableSheet(
                initialChildSize: selectedSite != null ? 0.65 : 0.35,
                minChildSize: 0.15,
                maxChildSize: 1.0, 
                builder: (BuildContext context, ScrollController scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -4))],
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      clipBehavior: Clip.none,
                      children: [
                        if (backend.showForecast)
                          Container(
                            height: 85,
                            margin: const EdgeInsets.only(bottom: 10, top: 16),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: 24,
                              itemBuilder: (context, index) {
                                var fc = backend.generateForecast()[index];
                                return Container(
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: fc['isActive'] ? const Color(0xFFFF6B00) : Colors.grey.shade300, width: fc['isActive'] ? 2 : 1),
                                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(fc['time'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937))),
                                      const SizedBox(height: 4),
                                      Text("AQI ${fc['aqi']}", style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 12)),
                                      Text(fc['isWorking'] ? "${fc['noise']} dB" : "No works", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                              const SizedBox(height: 16),
                              
                              if (selectedSite != null) 
                                _buildSiteDetail(selectedSite!, backend)
                              else ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("My home", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                          Text("No. ${backend.houseNumber}, ${backend.selectedStreet}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        _buildBadge("${backend.currentNoise.toStringAsFixed(0)} dB", const Color(0xFF12B76A), textColor: Colors.white),
                                        const SizedBox(width: 8),
                                        _buildBadge("AQI ${backend.currentAQI.toStringAsFixed(0)}", const Color(0xFFFF6B00), textColor: Colors.white),
                                      ],
                                    )
                                  ],
                                ),
                                const SizedBox(height: 20),
                                ...backend.sites.map((site) {
                                  double distance = backend.calculateDistance(backend.homeLocation, LatLng(site.lat, site.lng));
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() => selectedSite = site);
                                      _mapController.move(LatLng(site.lat - 0.001, site.lng), 17.0);
                                    },
                                    child: _buildRenovationCard(site, distance, backend),
                                  );
                                }),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildBadge(String text, Color color, {Color textColor = Colors.black}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRenovationCard(RenovationSite site, double distance, BuildWatchBackend backend) {
    Color statColor = backend.getStatusColor(site.dust, site.noise, backend.isNoiseMode);
    String impactLabel = statColor == const Color(0xFFE5213A) ? "High impact" : statColor == const Color(0xFFCB7E00) ? "Medium impact" : "Low impact";
    IconData siteIcon = site.type.toLowerCase().contains('construction') ? Icons.construction : Icons.home_repair_service;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: site.pump ? Colors.blue.shade200 : statColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(16),
        color: site.pump ? const Color(0xFFF0F8FF) : const Color(0xFFFFF8F1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(siteIcon, color: site.pump ? Colors.blue : statColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(site.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text("${distance.toStringAsFixed(0)} m from you", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(site.pump ? "Misting Active" : impactLabel, style: TextStyle(color: site.pump ? Colors.blue : statColor, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 16),
          const Text("Project Schedule", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildScheduleChip(Icons.timeline, site.stage, Colors.grey.shade200, Colors.black87),
              _buildScheduleChip(Icons.calendar_month, "Ends: ${site.endDate}", Colors.grey.shade200, Colors.black87),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSiteDetail(RenovationSite site, BuildWatchBackend backend) {
    bool isCompliant = site.noise < 80 && site.dust < 100;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(site.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)))),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () => setState(() => selectedSite = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCompliant ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(isCompliant ? "Compliant" : "Warning", style: TextStyle(color: isCompliant ? Colors.green.shade800 : Colors.red.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text("Est. Completion: ${site.endDate}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(child: _buildMetricBox("${site.noise.toStringAsFixed(0)} dB", "Noise", backend.getStatusColor(0, site.noise, true))),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricBox(site.dust.toStringAsFixed(0), "PM2.5", backend.getStatusColor(site.dust, 0, false))),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricBox(site.pm10.toStringAsFixed(0), "PM10", const Color(0xFF1F2937))),
          ],
        ),
        const SizedBox(height: 24),
        
        const Text("Areas & Zone Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: site.areas.isEmpty
                ? [const Padding(padding: EdgeInsets.all(16), child: Text("No area data available."))]
                : site.areas.map((area) {
                    bool isWarning = area.mist || area.pm25 > 45 || area.db > 75;
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFFFF4EA), borderRadius: BorderRadius.circular(18)),
                            child: Center(child: Text("${area.id}", style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Area ${area.id}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(
                                  area.mist ? "Dust breach · misting active" : (area.db > 75 ? "Noise breach" : "Within limits"),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          if (isWarning) const Icon(Icons.water_drop_outlined, color: Color(0xFFCB7E00), size: 18),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isWarning ? const Color(0xFFFFF4EA) : const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline, 
                                    size: 14, color: isWarning ? const Color(0xFFCB7E00) : Colors.green.shade700),
                                const SizedBox(width: 4),
                                Text(isWarning ? "Warning" : "Normal", 
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isWarning ? const Color(0xFFCB7E00) : Colors.green.shade700)),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  }).toList(),
          ),
        ),
        
        const SizedBox(height: 24),
        const Text("Full Daily Work Schedule", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: site.detailedSchedule.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text("No schedule details loaded."))
              : Column(
                  children: site.detailedSchedule.map((work) {
                    DateTime dtStart = DateTime.fromMillisecondsSinceEpoch(work.start);
                    DateTime dtEnd = DateTime.fromMillisecondsSinceEpoch(work.end);
                    String timeStr = "${dtStart.hour % 12 == 0 ? 12 : dtStart.hour % 12}:${dtStart.minute.toString().padLeft(2, '0')} ${dtStart.hour >= 12 ? 'pm' : 'am'} - "
                                     "${dtEnd.hour % 12 == 0 ? 12 : dtEnd.hour % 12}:${dtEnd.minute.toString().padLeft(2, '0')} ${dtEnd.hour >= 12 ? 'pm' : 'am'}";
                    
                    Color lvlColor = work.noise == 'heavy' || work.dust == 'heavy' ? const Color(0xFFE5213A) : 
                                     work.noise == 'moderate' || work.dust == 'moderate' ? const Color(0xFFCB7E00) : const Color(0xFF12B76A);

                    return Container(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFFFFF4EA), borderRadius: BorderRadius.circular(4)),
                                child: Text("Area ${work.area}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
                              )
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(work.type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildLevelBadge(work.noise, "Noise", lvlColor),
                              const SizedBox(width: 8),
                              _buildLevelBadge(work.dust, "Dust", lvlColor),
                            ],
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 24),
        const Text("Monthly Project Plan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: site.weeklyPlan.isEmpty
              ? const Padding(padding: EdgeInsets.all(16), child: Text("No monthly plan assigned yet."))
              : Table(
                  columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
                  border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.shade200)),
                  children: site.weeklyPlan.map((plan) {
                    return TableRow(
                      children: [
                        Padding(padding: const EdgeInsets.all(12), child: Text(plan['week']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Padding(padding: const EdgeInsets.all(12), child: Text(plan['task']!, style: const TextStyle(fontSize: 13))),
                      ]
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),

        const Text("24-Hour Historical Envelope (Noise)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 8),
        Row(
          children: List.generate(24, (index) {
            Color boxColor = Colors.grey.shade300;
            if (site.history.length > index) {
              double n = (site.history[index]['n'] ?? 0).toDouble();
              double nLimit = (index >= 7 && index < 19) ? 75 : (index >= 19 && index < 22) ? 65 : 55;
              double maxRatio = n / nLimit;
              boxColor = maxRatio >= 1.0 ? const Color(0xFFE5213A) : maxRatio >= 0.8 ? const Color(0xFFCB7E00) : const Color(0xFF12B76A);
            }
            return Expanded(
              child: Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(3)),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("00:00", style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text("12:00", style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text("23:00", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 16),

        const Text("24-Hour Historical Envelope (Dust)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
        const SizedBox(height: 8),
        Row(
          children: List.generate(24, (index) {
            Color boxColor = Colors.grey.shade300;
            if (site.history.length > index) {
              double d = (site.history[index]['d'] ?? 0).toDouble();
              double maxRatio = d / 100.0;
              boxColor = maxRatio >= 1.0 ? const Color(0xFFE5213A) : maxRatio >= 0.8 ? const Color(0xFFCB7E00) : const Color(0xFF12B76A);
            }
            return Expanded(
              child: Container(
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(3)),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("00:00", style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text("12:00", style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text("23:00", style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelBadge(String level, String type, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text("${level[0].toUpperCase()}${level.substring(1)} $type", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMetricBox(String value, String label, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4EA), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: valColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildScheduleChip(IconData icon, String text, Color bg, Color tx) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180), 
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tx),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, style: TextStyle(color: tx, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEATMAP PAINTER (Handles Web Mercator stepped rings and wind plumes)
// -----------------------------------------------------------------------------
class _HeatmapPainter extends CustomPainter {
  final BuildWatchBackend backend;
  final MapController mapController;
  
  _HeatmapPainter(this.backend, this.mapController) : super(repaint: backend);

  @override
  void paint(Canvas canvas, Size size) {
    if (backend.sites.isEmpty) return;

    final camera = mapController.camera;
    final zoom = camera.zoom;
    
    // Scale: metresPerPixel = 156543.03 * cos(lat) / 2^zoom
    final centerLatRad = camera.center.latitude * pi / 180;
    final double mpp = 156543.03 * cos(centerLatRad) / pow(2, zoom);

    final double windX = sin((backend.windFrom + 180) * pi / 180);
    final double windY = -cos((backend.windFrom + 180) * pi / 180);

    // Dynamic grid size: ~5 meters per cell, clamped to reasonable screen pixels to maintain performance
    final double stepPx = (5.0 / mpp).clamp(3.0, 15.0).roundToDouble();

    // Cache site configurations to minimize math in the inner loop
    List<Offset> siteOffsets = [];
    List<double> maxRadiiMeters = [];

    for (var site in backend.sites) {
      final point = camera.latLngToScreenPoint(LatLng(site.lat, site.lng));
      siteOffsets.add(Offset(point.x.toDouble(), point.y.toDouble()));

      if (backend.isNoiseMode) {
        // nb = site.noise - 20 * log10(d) - 6  => max distance where nb >= 45
        double maxD = pow(10, (site.noise - 51) / 20).toDouble();
        maxRadiiMeters.add(maxD);
      } else {
        // dust = site.dust * exp(-alpha * d) * w  => max distance where dust >= 1.5
        // w maxes out at 1.0 directly upwind
        double maxD = site.dust > 1.5 ? -log(1.5 / site.dust) / BuildWatchBackend.alpha : 0.0;
        maxRadiiMeters.add(maxD);
      }
    }

    // Determine the minimal bounding box on screen covering all site ranges to prevent drawing over empty space
    double minX = size.width;
    double minY = size.height;
    double maxX = 0;
    double maxY = 0;

    for (int i = 0; i < siteOffsets.length; i++) {
      double maxRadiusPx = maxRadiiMeters[i] / mpp;
      if (maxRadiusPx <= 0) continue;
      minX = min(minX, siteOffsets[i].dx - maxRadiusPx);
      minY = min(minY, siteOffsets[i].dy - maxRadiusPx);
      maxX = max(maxX, siteOffsets[i].dx + maxRadiusPx);
      maxY = max(maxY, siteOffsets[i].dy + maxRadiusPx);
    }

    // Intersect evaluation bounds with the actual screen bounds
    minX = max(0, minX);
    minY = max(0, minY);
    maxX = min(size.width, maxX);
    maxY = min(size.height, maxY);

    // Containers for the 8 specific color bands
    List<List<Offset>> bandPoints = List.generate(8, (_) => []);

    // Evaluate the area
    for (double x = minX; x < maxX; x += stepPx) {
      for (double y = minY; y < maxY; y += stepPx) {
        double nE = 0;
        double totalDust = 0;

        for (int i = 0; i < backend.sites.length; i++) {
          double dx = x - siteOffsets[i].dx;
          double dy = y - siteOffsets[i].dy;
          double dLenPx = sqrt(dx * dx + dy * dy);
          double dMeters = dLenPx * mpp;

          // Quick spatial cull if out of maximum possible reach for this site
          if (dMeters > maxRadiiMeters[i] + (stepPx * mpp)) continue;
          if (dMeters < 1.0) dMeters = 1.0;

          if (backend.isNoiseMode) {
            double nb = backend.sites[i].noise - 20 * (log(dMeters) / ln10) - 6;
            if (nb > 0) nE += pow(10, nb / 10);
          } else {
            double c = dLenPx == 0 ? 1.0 : (dx * windX + dy * windY) / dLenPx;
            double w = max(0.1, 0.55 + 0.45 * c);
            double f = exp(-BuildWatchBackend.alpha * dMeters) * w;
            totalDust += backend.sites[i].dust * f;
          }
        }

        double val = 0;
        if (backend.isNoiseMode) {
          if (nE > 0) val = 10 * (log(nE) / ln10);
        } else {
          val = totalDust;
        }

        final thresholds = backend.isNoiseMode ? _noiseThresholds : _dustThresholds;

        // Classify heat cell into one of the 8 discrete bands
        if (val >= thresholds[0]) {
          int band = 0;
          for (int b = 7; b >= 0; b--) {
            if (val >= thresholds[b]) {
              band = b;
              break;
            }
          }
          // Shift half a step to perfectly align point strokes
          bandPoints[band].add(Offset(x + stepPx / 2, y + stepPx / 2));
        }
      }
    }

    // High performance bulk drawing
    for (int b = 0; b < 8; b++) {
      if (bandPoints[b].isNotEmpty) {
        final paint = Paint()
          ..color = _layerColors[b].withAlpha(205)
          ..strokeWidth = stepPx
          ..strokeCap = StrokeCap.square; 
        canvas.drawPoints(PointMode.points, bandPoints[b], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => true;
}