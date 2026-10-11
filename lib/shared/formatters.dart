const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatCallDate(DateTime utc) {
  final local = utc.toLocal();
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}

String formatCallTime(DateTime utc) {
  final local = utc.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String formatTimestamp(DateTime? utc) {
  if (utc == null) {
    return 'Not synced yet';
  }
  return '${formatCallDate(utc)} · ${formatCallTime(utc)}';
}

String formatDuration(int seconds) {
  if (seconds <= 0) {
    return '0s';
  }
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remaining = seconds % 60;
  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  if (minutes > 0) {
    return '${minutes}m ${remaining.toString().padLeft(2, '0')}s';
  }
  return '${remaining}s';
}

String displayPhone(String value) {
  switch (value) {
    case 'unknown':
      return 'Unknown number';
    case 'private':
      return 'Private number';
    default:
      return value;
  }
}
