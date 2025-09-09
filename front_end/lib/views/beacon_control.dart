import 'package:flutter/services.dart';

class BeaconControl {
  static const MethodChannel _channel = MethodChannel('com.attendo/beacon');

  Future<void> startBeacon(String uuid, int major, int minor) async {
    await _channel.invokeMethod('startBeacon', {
      'uuid': uuid,
      'major': major,
      'minor': minor,
    });
  }

  Future<void> stopBeacon() async {
    await _channel.invokeMethod('stopBeacon');
  }
}
