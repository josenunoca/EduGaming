import 'dart:math';

class LoanCalculator {
  /// Calculates the monthly installment (PMT)
  /// Formula: PMT = P * (r * (1 + r)^n) / ((1 + r)^n - 1)
  /// P = Principal (Loan Amount)
  /// r = Monthly Interest Rate (Annual Rate / 12 / 100)
  /// n = Number of Months
  static double calculateMonthlyInstallment({
    required double principal,
    required double annualInterestRate,
    required int months,
  }) {
    if (principal <= 0 || months <= 0) return 0.0;
    if (annualInterestRate <= 0) return principal / months;

    double monthlyRate = annualInterestRate / 12 / 100;
    double factor = pow(1 + monthlyRate, months).toDouble();
    
    return principal * (monthlyRate * factor) / (factor - 1);
  }

  static double calculateTotalPayment(double monthlyInstallment, int months) {
    return monthlyInstallment * months;
  }

  static double calculateTotalInterest(double totalPayment, double principal) {
    return totalPayment - principal;
  }
}
