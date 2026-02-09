import 'package:driver_license_verifier_app/core/services/supabase_service.dart';
import 'package:driver_license_verifier_app/theme/app_colors.dart';
import 'package:driver_license_verifier_app/utils/responsive_sizes.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  bool _isLoading = true;
  Map<String, int> _ageStats = {};
  Map<String, int> _licenseStats = {};
  List<Map<String, dynamic>> _registrationTrends = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final age = await SupabaseService.getDriverAgeStats();
    final license = await SupabaseService.getLicenseClassStats();
    final trends = await SupabaseService.getRegistrationTrends();

    if (mounted) {
      setState(() {
        _ageStats = age;
        _licenseStats = license;
        _registrationTrends = trends;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = ResponsiveSize(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: TextStyle(fontSize: res.appBarTitleFont),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(
                res.pick(mobile: 16.0, tablet: 24.0, desktop: 32.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('License Class Distribution', res),
                  const SizedBox(height: 16),
                  _buildLicensePieChart(res),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Driver Age Demographics', res),
                  const SizedBox(height: 16),
                  _buildAgeBarChart(res),
                  const SizedBox(height: 32),
                  _buildSectionTitle('New Registrations (Last 7 Days)', res),
                  const SizedBox(height: 16),
                  _buildTrendLineChart(res),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, ResponsiveSize res) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: res.pick(mobile: 18.0, tablet: 20.0, desktop: 22.0),
        fontWeight: FontWeight.bold,
        color: AppColors.textMain,
      ),
    );
  }

  Widget _buildCard(Widget child, {double height = 300}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLicensePieChart(ResponsiveSize res) {
    if (_licenseStats.isEmpty)
      return _buildCard(const Center(child: Text('No data available')));

    // Colors for slices
    final colors = [
      AppColors.zimGreen,
      AppColors.zimYellow,
      AppColors.zimRed,
      AppColors.textMain,
      Colors.blue,
      Colors.orange,
    ];

    List<PieChartSectionData> sections = [];
    int i = 0;
    _licenseStats.forEach((key, value) {
      final color = colors[i % colors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: '$value',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      i++;
    });

    return _buildCard(
      Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _licenseStats.entries.map((e) {
              final index = _licenseStats.keys.toList().indexOf(e.key);
              final color = colors[index % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, color: color),
                    const SizedBox(width: 8),
                    Text('Class ${e.key}: ${e.value}'),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      height: res.pick(mobile: 250.0, tablet: 300.0, desktop: 350.0),
    );
  }

  Widget _buildAgeBarChart(ResponsiveSize res) {
    if (_ageStats.values.every((v) => v == 0))
      return _buildCard(const Center(child: Text('No data available')));

    final titles = _ageStats.keys.toList();
    final values = _ageStats.values.toList();
    double maxY = 0;
    for (var v in values) if (v > maxY) maxY = v.toDouble();
    maxY = (maxY == 0) ? 10 : maxY + 2;

    return _buildCard(
      BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, meta) {
                  if (val.toInt() >= 0 && val.toInt() < titles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        titles[val.toInt()],
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(titles.length, (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: values[index].toDouble(),
                  color: AppColors.zimGreen,
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTrendLineChart(ResponsiveSize res) {
    if (_registrationTrends.isEmpty)
      return _buildCard(const Center(child: Text('No data available')));

    final counts = _registrationTrends
        .map((e) => (e['count'] as int).toDouble())
        .toList();
    final dates = _registrationTrends.map((e) => e['date'] as String).toList();
    double maxY = 0;
    for (var v in counts) if (v > maxY) maxY = v;
    maxY = (maxY == 0) ? 5 : maxY + 2;

    return _buildCard(
      LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  if (val.toInt() >= 0 && val.toInt() < dates.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        dates[val.toInt()],
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  if (val % 1 == 0)
                    return Text(
                      val.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    );
                  return const Text('');
                },
                reservedSize: 28,
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (counts.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                counts.length,
                (index) => FlSpot(index.toDouble(), counts[index]),
              ),
              isCurved: true,
              color: AppColors.textMain,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.textMain.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
