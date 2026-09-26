import 'package:intl/intl.dart';

String formatNumber(double value, {int fractionDigits = 2}) {
  final formatted = value.toStringAsFixed(fractionDigits);
  return formatted
      .replaceFirst(RegExp(r'\.00$'), '')
      .replaceFirst(RegExp(r'(\.\d)0$'), r'$1');
}

String formatDateTime(DateTime value) {
  return DateFormat('yyyy-MM-dd HH:mm').format(value);
}
