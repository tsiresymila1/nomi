class ModelProviderType {
  static const local = 'local';
  static const remote = 'remote';

  static bool isValid(String value) {
    return value == local || value == remote;
  }
}
