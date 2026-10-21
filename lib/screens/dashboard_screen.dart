import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../backend.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backend = BuildWatchBackend();

    return AnimatedBuilder(
      animation: backend,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F1),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Top Status Indicator
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 10),
                        SizedBox(width: 8),
                        Text("Active Monitoring Mesh Connected", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Mode Toggle Switch
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFF6B00), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => backend.toggleMode(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: backend.isNoiseMode ? const Color(0xFFFF6B00) : Colors.white,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                            ),
                            child: Center(
                              child: Text(
                                "Noise Overview", 
                                style: TextStyle(color: backend.isNoiseMode ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => backend.toggleMode(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !backend.isNoiseMode ? const Color(0xFFFF6B00) : Colors.white,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                            ),
                            child: Center(
                              child: Text(
                                "Air Quality Overview", 
                                style: TextStyle(color: !backend.isNoiseMode ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Main Data Card
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          backend.isNoiseMode ? "Live Noise at Your Location" : "Live Air Quality at Your Location",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          backend.isNoiseMode 
                              ? "Worst of your front porch and backyard, counting the houses in between that block noise. Open-air value without them: ${backend.currentNoise.toStringAsFixed(0)} dB. Change your house from the Home tab (top-right button)."
                              : "Worst of your front porch and backyard, counting the houses in between that hold back dust. Open-air value without them: AQI ${backend.currentAQI.toStringAsFixed(0)}. Change your house from the Home tab (top-right button).",
                          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
                        ),
                        const SizedBox(height: 16),

                        // Radial Gauge (Cleaned up alignment and scaling)
                        SizedBox(
                          height: 170,
                          child: SfRadialGauge(
                            axes: <RadialAxis>[
                              RadialAxis(
                                minimum: 0,
                                maximum: backend.isNoiseMode ? 100 : 300,
                                showLabels: false,
                                showTicks: false,
                                startAngle: 180,
                                endAngle: 0,
                                radiusFactor: 1.0,
                                canScaleToFit: true,
                                axisLineStyle: const AxisLineStyle(
                                  thickness: 20,
                                  cornerStyle: CornerStyle.bothCurve,
                                  color: Color(0xFFFFF4EA),
                                ),
                                pointers: <GaugePointer>[
                                  RangePointer(
                                    value: backend.isNoiseMode ? backend.currentNoise : backend.currentAQI,
                                    cornerStyle: CornerStyle.bothCurve,
                                    width: 20,
                                    color: backend.isNoiseMode 
                                        ? backend.getStatusColor(0, backend.currentNoise, true)
                                        : backend.getStatusColor(backend.currentAQI, 0, false),
                                  )
                                ],
                                annotations: <GaugeAnnotation>[
                                  GaugeAnnotation(
                                    positionFactor: 0.0, // Places the numbers cleanly in the center of the arc
                                    angle: 90,
                                    widget: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          backend.isNoiseMode ? backend.currentNoise.toStringAsFixed(0) : backend.currentAQI.toStringAsFixed(0),
                                          style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                                        ),
                                        Text(
                                          backend.isNoiseMode ? "dB at neighbor boundary" : "AQI",
                                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            backend.isNoiseMode 
                                ? (backend.currentNoise > 85 ? "Breach Level" : backend.currentNoise > 70 ? "High Impact" : backend.currentNoise > 55 ? "Moderate Impact" : "Minimal Impact")
                                : "AQI ${backend.currentAQI.toStringAsFixed(0)} — ${(backend.currentAQI > 150) ? 'Unhealthy' : 'Moderate'}",
                            style: TextStyle(
                              color: backend.isNoiseMode 
                                  ? backend.getStatusColor(0, backend.currentNoise, true)
                                  : backend.getStatusColor(backend.currentAQI, 0, false),
                              fontWeight: FontWeight.bold, 
                              fontSize: 16
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Mode-specific Breakdown
                        if (backend.isNoiseMode) 
                          _buildNoiseLegend(backend)
                        else 
                          _buildAQILegend(backend),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // --- Noise Legend ---
  Widget _buildNoiseLegend(BuildWatchBackend backend) {
    double noise = backend.currentNoise;
    return Column(
      children: [
        _buildNoiseRow(const Color(0xFF12B76A), "< 55 dB", "Minimal Impact (conversation level)", isHighlighted: noise < 55),
        const SizedBox(height: 8),
        _buildNoiseRow(const Color(0xFFF7C500), "55 – 70 dB", "Moderate Impact (lawnmower / light drilling)", isHighlighted: noise >= 55 && noise <= 70),
        const SizedBox(height: 8),
        _buildNoiseRow(const Color(0xFFFF7A1A), "71 – 85 dB", "High Impact (intense power tools)", isHighlighted: noise >= 71 && noise <= 85),
        const SizedBox(height: 8),
        _buildNoiseRow(const Color(0xFFE5213A), "> 85 dB", "Breach Level (exceeds township limit)", isHighlighted: noise > 85),
      ],
    );
  }

  Widget _buildNoiseRow(Color color, String limit, String desc, {bool isHighlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFFFF4EA) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          SizedBox(width: 75, child: Text(limit, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1F2937)))),
          Expanded(child: Text(desc, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
        ],
      ),
    );
  }

  // --- Air Quality Legend ---
  Widget _buildAQILegend(BuildWatchBackend backend) {
    int netDust = (backend.currentAQI - backend.baseAQI).round();
    
    return Column(
      children: [
        Container(
          height: 32,
          width: double.infinity,
          decoration: BoxDecoration(color: const Color(0xFFFF6B00), borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text("Regional baseline ${backend.baseAQI.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(height: 16),
        _buildLegendItem(Icons.square, "Regional baseline (IQAir Kuala Lumpur)", "${backend.baseAQI.toStringAsFixed(0)} AQI · Unhealthy", const Color(0xFFFF6B00)),
        const SizedBox(height: 12),
        _buildLegendItem(Icons.texture, "Net renovation dust (striped part)", "+$netDust AQI", const Color(0xFFFF6B00)),
        const SizedBox(height: 12),
        _buildLegendItem(null, "Total combined boundary", "${backend.currentAQI.toStringAsFixed(0)} AQI", Colors.transparent, isBold: true),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildMetricBox("${backend.pm25.toStringAsFixed(0)} µg/m³", "PM2.5 — Close windows; limit outdoor exertion")),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricBox("${backend.pm10.toStringAsFixed(0)} µg/m³", "PM10 — High coarse dust; misting active")),
          ],
        )
      ],
    );
  }

  // FIXED OVERFLOW: Uses Expanded to allow label wrapping and keep value on screen
  Widget _buildLegendItem(IconData? icon, String label, String value, Color iconColor, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label, 
            style: TextStyle(
              color: const Color(0xFF1F2937), 
              fontSize: 12, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value, 
          style: TextStyle(
            fontSize: 12, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, 
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String value, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4EA), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.3)),
        ],
      ),
    );
  }
}