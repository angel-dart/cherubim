import 'dart:async';
import 'package:pool/pool.dart';
import 'adapter.dart';
import 'request.dart';
import 'user.dart';

/// A lightweight caching system for Dart.
class Server {
  final List<Adapter> _adapters = [];
  Pool _pool;
  bool _running = false;

  /// Initializes a Cherubim server.
  ///
  /// You can provide any number of [adapters].
  /// Requests will be mutually excluded at the given [concurrency] (default: `1`).
  Server({Iterable<Adapter> adapters: const [], int concurrency}) {
    _adapters.addAll(adapters ?? []);
    _pool = new Pool(concurrency ?? 1);
  }

  /// Shuts down the server, along with any of its adapters.
  Future close() async {
    await Future.wait(_adapters.map((a) => a.close()));
  }

  /// Starts the server listening.
  void start() {
    _running = true;
    _adapters.forEach(_listenToAdapter);
  }

  /// Adds an adapter, after the server has already started.
  void addAdapter(Adapter adapter) {
    if (!_running)
      throw new StateError(
          'You cannot use `addAdapter()` until the server has started listening.');
    _adapters.add(adapter);
    _listenToAdapter(adapter);
  }

  _listenToAdapter(Adapter adapter) {
    adapter.start();
    adapter.onRequest.listen((t) => handleRequest(t.item2, t.item1));
  }

  /// Handles an incoming [request] from a specific [user].
  Future handleRequest(Request request, User user) async {
    var resx = await _pool.request();
    // TODO: Handle requests
    resx.release();
  }

  /// Sends a real-time message to all connected clients.
  void broadcast(String key, value) {
    // TODO: Broadcast
  }
}
