class AppClock {
  const AppClock();

  DateTime now() => DateTime.now().toUtc();
}
