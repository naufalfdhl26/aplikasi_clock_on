import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

class WifiService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<String?> getWifiName() async {
    try {
      final ssid = await _networkInfo.getWifiName();
      return ssid;
    } catch (e) {
      debugPrint('getWifiName error: $e');
      return null;
    }
  }

  Future<String?> getWifiBssid() async {
    try {
      final bssid = await _networkInfo.getWifiBSSID();
      return bssid;
    } catch (e) {
      debugPrint('getWifiBssid error: $e');
      return null;
    }
  }

  Future<Map<String, String>> getCurrentWifi() async {
    final ssid = (await getWifiName()) ?? 'Tidak terhubung';
    final bssid = (await getWifiBssid()) ?? '-';
    return {'ssid': ssid, 'bssid': bssid};
  }
}
