/// Intervalles de synchronisation mobile (réduit la charge réseau et les ralentissements).
class PayflexPollConfig {
  PayflexPollConfig._();

  static const inboxSummary = Duration(seconds: 45);
  static const notifications = Duration(seconds: 60);
  static const agentDashboard = Duration(seconds: 30);
  static const catalogue = Duration(seconds: 30);
  static const agentClientDetail = Duration(seconds: 20);
  static const chatOpen = Duration(seconds: 5);
}
