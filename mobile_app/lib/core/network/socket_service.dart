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
    'comment.deleted',
    'project.updated',
    'project.memberAdded',
    'project.memberRemoved',
    'notification.created',
    'project.deleted',
    'project.memberUpdated',
    'presence.update',
  ];

  io.Socket? _socket;
  String? _currentToken;
  final _projects = <String, int>{};
  final _controller = StreamController<RealtimeEvent>.broadcast();

  Stream<RealtimeEvent> get events => _controller.stream;

  void connect(String token) {
    if (token.isEmpty) return;
    if (_socket != null && _currentToken == token) {
      if (_socket!.disconnected) {
        _socket!.connect();
      } else {
        syncPresence();
      }
      return;
    }

    _socket?.disconnect();
    _socket?.dispose();
    _currentToken = token;

    final socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setQuery({'token': token})
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      for (final id in _projects.keys) {
        socket.emit('project.join', {'projectId': id});
      }
      socket.emit('presence.sync', {});
    });

    for (final name in _eventNames) {
      socket.on(name, (data) {
        if (!_controller.isClosed) {
          _controller.add(RealtimeEvent(name, data));
        }
      });
    }
    socket.connect();
  }

  void syncPresence([String? projectId]) {
    if (_socket?.connected == true) {
      _socket!.emit('presence.sync', {
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      });
    }
  }

  void joinProject(String projectId) {
    if (projectId.isEmpty) return;
    _projects[projectId] = (_projects[projectId] ?? 0) + 1;
    if (_socket?.connected == true) {
      _socket!.emit('project.join', {'projectId': projectId});
    }
  }

  void leaveProject(String id) {
    if (id.isEmpty) return;
    final n = (_projects[id] ?? 0) - 1;
    if (n > 0) {
      _projects[id] = n;
    } else {
      _projects.remove(id);
    }
  }

  void disconnect() {
    _projects.clear();
    _currentToken = null;
    if (_socket != null) {
      if (_socket!.connected) {
        _socket!.emit('auth.logout');
      }
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}