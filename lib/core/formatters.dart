import 'package:intl/intl.dart';

String formatNumber(double value, {int fractionDigits = 2}) {
  final formatted = value.toStringAsFixed(fractionDigits);
  if (formatted.endsWith('.00')) {
    return formatted.substring(0, formatted.length - 3);
  }
  if (RegExp(r'\.\d0$').hasMatch(formatted)) {
    return formatted.substring(0, formatted.length - 1);
  }
  return formatted;
}

String formatDateTime(DateTime value) {
  return DateFormat('yyyy-MM-dd HH:mm').format(value);
}
