import 'package:flutter_bloc/flutter_bloc.dart';

enum ChatComposerMode { text, image }

class ChatComposerModeCubit extends Cubit<ChatComposerMode> {
  ChatComposerModeCubit() : super(ChatComposerMode.text);

  void select(ChatComposerMode mode) {
    if (mode != state) emit(mode);
  }
}
