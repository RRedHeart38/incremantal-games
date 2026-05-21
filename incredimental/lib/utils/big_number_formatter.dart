extension BigIntFormatter on BigInt {
  String formatBigNumber() => formatBigNumberValue(this);
}

String formatBigNumber(BigInt value) => formatBigNumberValue(value);

String formatBigNumberValue(BigInt value) {
  if (value == BigInt.zero) return '0';

  final isNegative = value.isNegative;
  final digits = value.abs().toString();
  final prefix = isNegative ? '-' : '';

  if (digits.length < 7) {
    return '$prefix$digits';
  }

  final exponent = digits.length - 1;
  var mantissaInt = int.parse(digits.substring(0, 3));
  final roundDigit = digits.length > 3 ? digits.codeUnitAt(3) - 48 : 0;

  if (roundDigit >= 5) {
    mantissaInt += 1;
  }

  if (mantissaInt == 1000) {
    final nextExponent = exponent + 1;
    return '${prefix}1.00e$nextExponent';
  }

  final integerPart = mantissaInt ~/ 100;
  final decimalPart = (mantissaInt % 100).toString().padLeft(2, '0');
  final mantissa = '$integerPart.$decimalPart';

  return '$prefix${mantissa}e$exponent';
}