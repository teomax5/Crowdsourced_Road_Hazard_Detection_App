import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/hazard_report.dart';
import '../services/local_storage_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final LocalStorageService _storage = LocalStorageService();
  List<HazardReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final data = await _storage.loadReports();
    if (!mounted) return;
    setState(() {
      _reports = data;
      _isLoading = false;
    });
  }

  int get _total => _reports.length;
  int get _active =>
      _reports.where((r) => r.status.toLowerCase() == 'active').length;
  int get _underWork =>
      _reports.where((r) => r.status.toLowerCase() == 'under work').length;
  int get _resolved =>
      _reports.where((r) => r.status.toLowerCase() == 'resolved').length;

  int get _critical =>
      _reports.where((r) => r.severity.toLowerCase() == 'critical').length;
  int get _high =>
      _reports.where((r) => r.severity.toLowerCase() == 'high').length;
  int get _medium =>
      _reports.where((r) => r.severity.toLowerCase() == 'medium').length;
  int get _low =>
      _reports.where((r) => r.severity.toLowerCase() == 'low').length;

  int get _pothole => _reports
      .where((r) => r.description.toLowerCase().contains('pothole'))
      .length;

  int get _waterlogging => _reports
      .where((r) =>
  r.description.toLowerCase().contains('water') ||
      r.description.toLowerCase().contains('flood'))
      .length;

  int get _manhole => _reports
      .where((r) => r.description.toLowerCase().contains('manhole'))
      .length;

  // ✅ Fixed: count non-matching reports to avoid negative _other
  int get _other => _reports.where((r) {
    final d = r.description.toLowerCase();
    return !d.contains('pothole') &&
        !d.contains('water') &&
        !d.contains('flood') &&
        !d.contains('manhole');
  }).length;

  double get _resolutionRate =>
      _total == 0 ? 0 : (_resolved / _total * 100);

  double get _avgConfidence {
    final withConf = _reports.where((r) => r.confidence != null).toList();
    if (withConf.isEmpty) return 0;
    return withConf.map((r) => r.confidence!).reduce((a, b) => a + b) /
        withConf.length *
        100;
  }

  // ✅ Fixed: uses DateTime directly (no more DateTime.parse on string)
  Map<String, int> get _reportsPerDay {
    final Map<String, int> map = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = DateFormat('dd/MM').format(day);
      map[key] = 0;
    }
    for (final r in _reports) {
      final key = DateFormat('dd/MM').format(r.timestamp);
      if (map.containsKey(key)) {
        map[key] = map[key]! + 1;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No data yet.\nSubmit some hazard reports first.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('📊 Summary'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _summaryCard('Total Reports', _total,
                      Colors.blue, Icons.report),
                  _summaryCard('Active', _active, Colors.red,
                      Icons.error),
                  _summaryCard('Under Work', _underWork,
                      Colors.orange, Icons.timelapse),
                  _summaryCard('Resolved', _resolved,
                      Colors.green, Icons.check_circle),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      'Resolution Rate',
                      '${_resolutionRate.toStringAsFixed(1)}%',
                      Colors.teal,
                      Icons.pie_chart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _metricCard(
                      'Avg AI Confidence',
                      '${_avgConfidence.toStringAsFixed(1)}%',
                      Colors.purple,
                      Icons.psychology,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _sectionTitle('📋 Status Distribution'),
              const SizedBox(height: 8),
              _chartCard(
                child: _total == 0
                    ? _noDataText()
                    : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: [
                              if (_active > 0)
                                _pieSection(_active,
                                    Colors.red, 'Active'),
                              if (_underWork > 0)
                                _pieSection(
                                    _underWork,
                                    Colors.orange,
                                    'Under Work'),
                              if (_resolved > 0)
                                _pieSection(
                                    _resolved,
                                    Colors.green,
                                    'Resolved'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _legendDot(Colors.red,
                            'Active $_active'),
                        const SizedBox(height: 8),
                        _legendDot(Colors.orange,
                            'Under Work $_underWork'),
                        const SizedBox(height: 8),
                        _legendDot(Colors.green,
                            'Resolved $_resolved'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('⚠️ Severity Breakdown'),
              const SizedBox(height: 8),
              _chartCard(
                child: SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      // ✅ Fixed: maxY based on actual max bar value
                      maxY: ([
                        _critical,
                        _high,
                        _medium,
                        _low
                      ].reduce(max) +
                          1)
                          .toDouble(),
                      barTouchData:
                      BarTouchData(enabled: true),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, _) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              const labels = [
                                'Critical',
                                'High',
                                'Medium',
                                'Low'
                              ];
                              final idx = val.toInt();
                              return idx < labels.length
                                  ? Padding(
                                padding:
                                const EdgeInsets.only(
                                    top: 4),
                                child: Text(
                                    labels[idx],
                                    style: const TextStyle(
                                        fontSize: 10)),
                              )
                                  : const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: false)),
                      ),
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _barGroup(0, _critical,
                            Colors.red.shade900),
                        _barGroup(1, _high, Colors.red),
                        _barGroup(2, _medium, Colors.orange),
                        _barGroup(3, _low, Colors.green),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('🕳️ Hazard Type Breakdown'),
              const SizedBox(height: 8),
              _chartCard(
                child: _total == 0
                    ? _noDataText()
                    : Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 180,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: [
                              if (_pothole > 0)
                                _pieSection(
                                    _pothole,
                                    Colors.brown,
                                    'Pothole'),
                              if (_waterlogging > 0)
                                _pieSection(
                                    _waterlogging,
                                    Colors.blue,
                                    'Water'),
                              if (_manhole > 0)
                                _pieSection(
                                    _manhole,
                                    Colors.grey,
                                    'Manhole'),
                              if (_other > 0)
                                _pieSection(_other,
                                    Colors.purple, 'Other'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        _legendDot(Colors.brown,
                            'Pothole $_pothole'),
                        const SizedBox(height: 8),
                        _legendDot(Colors.blue,
                            'Water $_waterlogging'),
                        const SizedBox(height: 8),
                        _legendDot(Colors.grey,
                            'Manhole $_manhole'),
                        const SizedBox(height: 8),
                        _legendDot(Colors.purple,
                            'Other $_other'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('📅 Reports — Last 7 Days'),
              const SizedBox(height: 8),
              _chartCard(
                child: SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (val, _) {
                              final keys =
                              _reportsPerDay.keys.toList();
                              final idx = val.toInt();
                              if (idx >= 0 &&
                                  idx < keys.length) {
                                return Padding(
                                  padding:
                                  const EdgeInsets.only(
                                      top: 4),
                                  child: Text(keys[idx],
                                      style: const TextStyle(
                                          fontSize: 9)),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (val, _) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 10),
                            ),
                          ),
                        ),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: false)),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _reportsPerDay.values
                              .toList()
                              .asMap()
                              .entries
                              .map((e) => FlSpot(
                              e.key.toDouble(),
                              e.value.toDouble()))
                              .toList(),
                          isCurved: true,
                          color: Colors.blue,
                          barWidth: 3,
                          dotData:
                          const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue
                                .withValues(alpha: 0.15), // ✅ Fixed
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  Widget _summaryCard(
      String label, int value, Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), // ✅ Fixed
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toString(),
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), // ✅ Fixed
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chartCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), // ✅ Fixed
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  PieChartSectionData _pieSection(
      int value, Color color, String label) {
    return PieChartSectionData(
      value: value.toDouble(),
      color: color,
      radius: 50,
      title: '$value',
      titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12),
    );
  }

  BarChartGroupData _barGroup(int x, int y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y.toDouble(),
          color: color,
          width: 28,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
          BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _noDataText() => const Center(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text('No data available',
          style: TextStyle(color: Colors.grey)),
    ),
  );
}