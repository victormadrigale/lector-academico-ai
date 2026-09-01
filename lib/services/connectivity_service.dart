import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = false;
  bool get online => _online;
  Stream<bool> get changes => _controller.stream;

  Future<void> start() async {
    _subscription = Connectivity().onConnectivityChanged.listen((_) => _probe());
    await _probe();
  }

  Future<void> _probe() async {
    var ok = false;
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse('https://www.google.com/generate_204'));
      final response = await request.close().timeout(const Duration(seconds: 3));
      ok = response.statusCode >= 200 && response.statusCode < 400;
      await response.drain();
      client.close(force: true);
    } catch (_) {
      ok = false;
    }
    if (ok != _online) {
      _online = ok;
      _controller.add(ok);
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
