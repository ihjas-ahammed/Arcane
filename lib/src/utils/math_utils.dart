import 'dart:math';

class MathUtils {
  /// Performs simple linear regression on a set of points (x, y).
  /// Returns a map with 'slope' (m) and 'intercept' (c) for y = mx + c.
  /// Also returns 'rSquared' for fit quality.
  static Map<String, double> linearRegression(List<Point<double>> points) {
    if (points.isEmpty) {
      return {'slope': 0, 'intercept': 0, 'rSquared': 0};
    }

    final n = points.length;
    final sumX = points.fold(0.0, (sum, p) => sum + p.x);
    final sumY = points.fold(0.0, (sum, p) => sum + p.y);
    final sumXY = points.fold(0.0, (sum, p) => sum + (p.x * p.y));
    final sumX2 = points.fold(0.0, (sum, p) => sum + (p.x * p.x));

    final denominator = (n * sumX2) - (sumX * sumX);
    
    if (denominator == 0) {
      return {'slope': 0, 'intercept': points.first.y, 'rSquared': 0};
    }

    final slope = ((n * sumXY) - (sumX * sumY)) / denominator;
    final intercept = (sumY - (slope * sumX)) / n;

    return {
      'slope': slope,
      'intercept': intercept,
    };
  }

  /// Calculates the expected X value when Y reaches targetY using provided slope/intercept.
  static double predictX(double targetY, double slope, double intercept) {
    if (slope == 0) return 0;
    return (targetY - intercept) / slope;
  }
}