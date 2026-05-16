import 'package:flutter_gemma/flutter_gemma.dart' as gemma;

class GemmaChatSession {
  final gemma.InferenceModel model;
  final gemma.InferenceChat chat;

  const GemmaChatSession({required this.model, required this.chat});
}
