import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../logic/loan_calculator.dart';
import '../widgets/glass_card.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  double _amount = 50000;
  double _rate = 5.0;
  int _months = 24;

  final currencyFormatter = NumberFormat.currency(locale: 'pt_PT', symbol: '€');

  @override
  Widget build(BuildContext context) {
    double monthlyInstallment = LoanCalculator.calculateMonthlyInstallment(
      principal: _amount,
      annualInterestRate: _rate,
      months: _months,
    );

    double totalPayment =
        LoanCalculator.calculateTotalPayment(monthlyInstallment, _months);
    double totalInterest =
        LoanCalculator.calculateTotalInterest(totalPayment, _amount);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildResultCard(monthlyInstallment),
                const SizedBox(height: 40),
                _buildInputSection(),
                const SizedBox(height: 32),
                _buildSummaryDetails(totalPayment, totalInterest),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loan Calculator',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
        const SizedBox(height: 4),
        Text(
          'Premium MVP Experience',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),
      ],
    );
  }

  Widget _buildResultCard(double monthlyInstallment) {
    return GlassCard(
      opacity: 0.15,
      blur: 15,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Text(
              'PRESTAÇÃO MENSAL',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                letterSpacing: 2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              currencyFormatter.format(monthlyInstallment),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
                .animate(key: ValueKey(monthlyInstallment))
                .scale(duration: 400.ms, curve: Curves.easeOutBack),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2);
  }

  Widget _buildInputSection() {
    return Column(
      children: [
        _buildSliderInput(
          label: 'Montante do Empréstimo',
          value: _amount,
          min: 1000,
          max: 500000,
          divisions: 499,
          suffix: '€',
          onChanged: (val) => setState(() => _amount = val),
        ),
        const SizedBox(height: 24),
        _buildSliderInput(
          label: 'Taxa de Juro Anual',
          value: _rate,
          min: 0.5,
          max: 25.0,
          divisions: 245,
          suffix: '%',
          onChanged: (val) => setState(() => _rate = val),
        ),
        const SizedBox(height: 24),
        _buildSliderInput(
          label: 'Prazo (Meses)',
          value: _months.toDouble(),
          min: 6,
          max: 360,
          divisions: 354,
          suffix: ' m',
          onChanged: (val) => setState(() => _months = val.toInt()),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildSliderInput({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    String displayValue = (suffix == '€')
        ? currencyFormatter.format(value).replaceAll(',00', '')
        : '${value.toStringAsFixed(value == value.toInt() ? 0 : 1)}$suffix';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            Text(displayValue,
                style: const TextStyle(
                    color: Color(0xFF00D1FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSummaryDetails(double totalPayment, double totalInterest) {
    return Row(
      children: [
        Expanded(
          child: _buildMiniDetail(
              'Total a Pagar', currencyFormatter.format(totalPayment)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniDetail(
              'Total Juros', currencyFormatter.format(totalInterest)),
        ),
      ],
    ).animate().fadeIn(delay: 700.ms);
  }

  Widget _buildMiniDetail(String label, String value) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 4),
          FittedBox(
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
