import '../entities/chat_entities.dart';
import '../repositories/agent_chat_repository.dart';

class SendCodingPromptUseCase {
  const SendCodingPromptUseCase(this._repository);

  final AgentChatRepository _repository;

  Stream<PromptStreamChunk> call({
    required String prompt,
    required AgentMode mode,
    required String modelName,
  }) {
    return _repository.streamPromptResponse(
      prompt: prompt,
      mode: mode,
      modelName: modelName,
    );
  }
}
