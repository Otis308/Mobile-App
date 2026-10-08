import 'package:flutter_riverpod/flutter_riverpod.dart';

/// projectId -> tập userId đang online
class PresenceNotifier extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() => const {};

  void setOnline(String projectId, Set<String> ids) {
    state = {...state, projectId: ids};
  }
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, Map<String, Set<String>>>(PresenceNotifier.new);