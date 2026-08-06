import 'dart:io';

import 'package:shelf/shelf.dart';

class RateLimiter {
  final Duration minInterval;
  final int maxPerWindow;
  final Duration window;

  final Map<String, DateTime> _lastAttempt = {};
  final Map<String, List<DateTime>> _attempts = {};
  DateTime _lastSweep = DateTime.now();

  final String? Function(Request req) _getIpFromRequest;

  RateLimiter({
    required this.minInterval,
    required this.maxPerWindow,
    required this.window,
    String? Function(Request req)? getIpFromRequest,
  }) : _getIpFromRequest = getIpFromRequest ?? _defaultGetIpFromRequest;

  static String? _defaultGetIpFromRequest(Request req) {
    final cloudflareIp = req.headers['cf-connecting-ip'];
    if (cloudflareIp != null && cloudflareIp.isNotEmpty) {
      return cloudflareIp;
    }

    final forwardedIp = req.headers['x-forwarded-for'];
    if (forwardedIp != null && forwardedIp.isNotEmpty) {
      return forwardedIp.split(',').first.trim();
    }

    final connectionInfo =
        req.context['shelf.io.connection_info'] as HttpConnectionInfo?;

    return connectionInfo?.remoteAddress.address;
  }

  bool allow(Request req) {
    final key = _getIpFromRequest(req);

    if (key == null) {
      return false;
    }

    final now = DateTime.now();

    _sweepStaleEntries(now);

    final last = _lastAttempt[key];

    if (last != null && now.difference(last) < minInterval) {
      _lastAttempt[key] = now;
      return false;
    }
    _lastAttempt[key] = now;

    final attempts = _attempts.putIfAbsent(key, () => []);
    attempts.removeWhere((t) => now.difference(t) > window);

    if (attempts.length >= maxPerWindow) {
      return false;
    }

    attempts.add(now);
    return true;
  }

  void _sweepStaleEntries(DateTime now) {
    if (now.difference(_lastSweep) < window) {
      return;
    }
    _lastSweep = now;

    _lastAttempt.removeWhere((_, last) => now.difference(last) > window);
    _attempts.removeWhere((key, attempts) {
      attempts.removeWhere((t) => now.difference(t) > window);
      return attempts.isEmpty && !_lastAttempt.containsKey(key);
    });
  }
}
