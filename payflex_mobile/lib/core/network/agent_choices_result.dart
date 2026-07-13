class AgentChoicesResult {
  const AgentChoicesResult.success(this.agents)
      : errorMessage = null,
        isNetworkError = false;

  const AgentChoicesResult.failure(this.errorMessage, {this.isNetworkError = false})
      : agents = const [];

  final List<Map<String, dynamic>> agents;
  final String? errorMessage;
  final bool isNetworkError;

  bool get ok => errorMessage == null;
}
