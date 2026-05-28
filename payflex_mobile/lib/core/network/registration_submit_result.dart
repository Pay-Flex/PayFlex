class RegistrationSubmitResult {
  final bool success;
  final int? statusCode;
  final String? message;
  final int? registrationId;

  const RegistrationSubmitResult.success({this.registrationId})
      : success = true,
        statusCode = 200,
        message = null;

  const RegistrationSubmitResult.failure(this.statusCode, [this.message])
      : success = false,
        registrationId = null;
}
