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
    'project.deleted',
    'project.memberUpdated',
    'presence.update',
  ];

  io.Socket? _socket;
  final _projects = <String, int>{}; 
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  void connect(String token) {
    if (_socket != null) return;       // đã kết nối thì thôi
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
      for (final id in _projects.keys) {
        socket.emit('project.join', {'projectId': id});
      }
    });
    for (final name in _eventNames) {
      socket.on(name, (data) {
        if (!_controller.isClosed) _controller.add(RealtimeEvent(name, data));
      });
    }
    socket.connect();
  }

  void joinProject(String projectId) {
    _projects[projectId] = (_projects[projectId] ?? 0) + 1;
    if (_projects[projectId] == 1 && _socket?.connected == true) {
      _socket!.emit('project.join', {'projectId': projectId});
    }
  }

  void leaveProject(String id) {
    final n = (_projects[id] ?? 0) - 1;
    if (n > 0) { _projects[id] = n; return; }
    _projects.remove(id);
    if (_socket?.connected == true) _socket!.emit('project.leave', {'projectId': id});
  }

  void disconnect() {
    _projects.clear();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
