class LinearRegression {
  final double slope;
  final double intercept;

  LinearRegression(this.slope, this.intercept);

  static LinearRegression calculate(List<double> values) {
    final n = values.length;
    if (n == 0) return LinearRegression(0, 0);

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumXX = 0;

    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      final y = values[i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }

    final num = n * sumXY - sumX * sumY;
    final den = n * sumXX - sumX * sumX;
    if (den == 0) return LinearRegression(0, sumY / n);

    final slope = num / den;
    final intercept = (sumY - slope * sumX) / n;
    return LinearRegression(slope, intercept);
  }

  double predict(double x) => slope * x + intercept;
}
