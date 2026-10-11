class DisclosureSection {
  const DisclosureSection(this.title, this.body);

  final String title;
  final String body;
}

class MonitoringDisclosure {
  const MonitoringDisclosure._();

  static const localRetentionDays = 90;

  static const sections = [
    DisclosureSection(
      'What is collected',
      'Spark Mauritius Sales Monitoring System reads the normal cellular call log on this company phone. '
          'Each record includes the phone number, call type, date and time, and '
          'duration. Call types are incoming, outgoing, missed, rejected, and blocked. '
          'Unknown or private numbers are stored as unknown or private. '
          'WhatsApp calls, WhatsApp messages, text messages, contact names, '
          'microphone audio, and call recordings are not collected.',
    ),
    DisclosureSection(
      'Why the employer needs it',
      'Your employer uses this call metadata to review sales activity on '
          'company-owned phones. It is limited to the assistant and device '
          'registered to your company.',
    ),
    DisclosureSection(
      'When synchronization happens',
      'After you allow access, the app syncs when you open it, when you tap '
          'Sync Now, when you return to the app, and when the network comes back. '
          'Android WorkManager also schedules a background sync about every 15 minutes. '
          'Android controls the exact time and may delay it for battery saving.',
    ),
    DisclosureSection(
      'Who can access it',
      'Company administrators can view the synchronized call records in the '
          'company back office. You can view the same records for your own '
          'registered phone in this app.',
    ),
    DisclosureSection(
      'How monitoring can be disabled',
      'Call monitoring stays on while you are signed in. Sign out to stop '
          'collection and background sync on this phone. An administrator can also '
          'deactivate your account or this device, which stops synchronization.',
    ),
    DisclosureSection(
      'Retention',
      'This phone keeps synchronized call records for $localRetentionDays days, '
          'then deletes the local copies. Pending records stay until they upload '
          'or you sign out. Sign-out and deactivation clear the local queue. '
          'Records already stored for the company remain until your organization\'s '
          'retention period ends. Ask your administrator for that period.',
    ),
  ];
}
