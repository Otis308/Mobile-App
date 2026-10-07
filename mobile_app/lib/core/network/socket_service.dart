import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

class RealtimeEvent {
  final String name;
  final dynamic data;
  const RealtimeEvent(this.name, this.data);
}

class SocketService {
  static const _eventNames = [
    'task.created',
    'task.updated',
    'task.moved',
    'task.deleted',
    'comment.created',
    'project.updated',
    'project.memberAdded',
    'project.memberRemoved',
    'notification.created',
  ];

  io.Socket? _socket;
  String? _projectId;
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  void connect(String token) {
    _socket?.dispose();
    final socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      final id = _projectId;
      if (id != null) socket.emit('project.join', {'projectId': id});
    });
    for (final name in _eventNames) {
      socket.on(name, (data) {
        if (!_controller.isClosed) _controller.add(RealtimeEvent(name, data));
      });
    }
    socket.connect();
  }

  void joinProject(String projectId) {
    _projectId = projectId;
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emit('project.join', {'projectId': projectId});
    }
  }

  void disconnect() {
    _projectId = null;
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
