String formatCompactBigInt(BigInt value) {
  // Show raw for small values
  final threshold = BigInt.from(1000000); // below 1M show exact
  if (value < threshold) return value.toString();

  final s = value.toString();
  final digits = s.length;
  final exponent = digits - 1;

  // take first two digits to make a single-decimal mantissa
  final first = int.parse(s.substring(0, 1));
  final second = int.parse(s.substring(1, 2));

  // Build mantissa string: if second==0 show like '1.' to match "1.e10" style
  final mantissa = second == 0 ? '${first}.' : '${first}.${second}';
  return '$mantissa' + 'e$exponent';
}
