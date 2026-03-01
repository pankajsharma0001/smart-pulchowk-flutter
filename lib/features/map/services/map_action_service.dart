import 'dart:async';
import 'package:smart_pulchowk/features/map/models/chatbot_response.dart';

/// A singleton service that allows the Assistant tab to trigger actions on the Map tab.
class MapActionService {
  MapActionService._();
  static final MapActionService instance = MapActionService._();

  final _actionController = StreamController<ChatBotData>.broadcast();

  /// Stream of chatbot data that requires map interaction.
  Stream<ChatBotData> get actionStream => _actionController.stream;

  /// Emits a new map action to be handled by the MapPage.
  void triggerAction(ChatBotData data) {
    if (data.isMapAction) {
      _actionController.add(data);
    }
  }

  void dispose() {
    _actionController.close();
  }
}
