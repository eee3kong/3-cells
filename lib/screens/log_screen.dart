import 'package:flutter/material.dart';
import '../backend.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final backend = BuildWatchBackend();
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: backend,
      builder: (context, child) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Compliance Audit Log", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  IconButton(
                    icon: Icon(_showSettings ? Icons.settings : Icons.settings_outlined, color: const Color(0xFFFF6B00)),
                    onPressed: () => setState(() => _showSettings = !_showSettings),
                  )
                ],
              ),
              
              if (_showSettings) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Alert Preferences", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Receive Incident Alerts", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                          Switch(
                            value: backend.notificationsEnabled,
                            activeColor: const Color(0xFFFF6B00),
                            onChanged: (val) => backend.toggleNotifications(val),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Detection Radius", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<double>(
                              value: backend.logRadius,
                              isDense: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFF6B00)),
                              style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 14),
                              items: const [
                                DropdownMenuItem(value: 500.0, child: Text("500 m")),
                                DropdownMenuItem(value: 1000.0, child: Text("1 km")),
                                DropdownMenuItem(value: 2000.0, child: Text("2 km")),
                                DropdownMenuItem(value: 5000.0, child: Text("5 km")),
                                DropdownMenuItem(value: 100000.0, child: Text("All Active Sites")),
                              ],
                              onChanged: (val) {
                                if (val != null) backend.updateLogRadius(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Interventions within ${backend.logRadius >= 100000 ? 'all sites' : '${(backend.logRadius / 1000).toStringAsFixed(1)} km'} today", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildSummaryBox(backend.filteredMistingCycles.toString(), "Misting cycles")),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSummaryBox(backend.filteredContractorAlerts.toString(), "Contractor alerts")),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Township Governance & Action Timeline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                    const SizedBox(height: 20),
                    if (backend.filteredLogs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text("No incidents logged in this radius.", style: TextStyle(color: Colors.grey))),
                      )
                    else
                      ...backend.filteredLogs.map((log) => _buildLogCard(
                            time: log.time,
                            incident: log.incident,
                            action: log.action,
                            status: log.outcome,
                            isActive: log.isActive,
                          )),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildSummaryBox(String count, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFFFFF8F1), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLogCard({required String time, required String incident, required String action, required String status, required bool isActive}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(color: isActive ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14, height: 1.4), children: [const TextSpan(text: "Incident: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: incident)])),
                const SizedBox(height: 8),
                RichText(text: TextSpan(style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14, height: 1.4), children: [const TextSpan(text: "Action: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: action)])),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isActive ? const Color(0xFFFDE8E8) : const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.red[800] : Colors.green[800])),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}