import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:blind_social/core/services/pocketbase_service.dart';
import 'package:blind_social/core/services/security_service.dart'; // Optional for app logger if present

class UserMetadataService {
  static final UserMetadataService _instance = UserMetadataService._internal();

  factory UserMetadataService() {
    return _instance;
  }

  UserMetadataService._internal();

  Future<void> updateMetadata() async {
    try {
      final authModel = PocketBaseService.client.authStore.model;
      if (authModel == null) return;
      final userId = authModel.id;

      String lastIp = "";
      String lastLocation = "";

      // 1. Fetch IP Address
      try {
        final response = await http.get(Uri.parse('https://api.ipify.org?format=json')).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          lastIp = data['ip'] ?? '';
        }
      } catch (e) {
        debugPrint("IP fetch error: $e");
      }

      // 2. Fetch Location
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 5)
            );
            
            try {
              List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
              if (placemarks.isNotEmpty) {
                Placemark place = placemarks[0];
                final List<String> addressParts = [
                  place.name ?? "",
                  place.thoroughfare ?? "",
                  place.subThoroughfare ?? "",
                  place.subLocality ?? "",
                  place.locality ?? "",
                  place.administrativeArea ?? "",
                  place.country ?? "",
                  place.postalCode ?? ""
                ];
                lastLocation = addressParts.where((e) => e.trim().isNotEmpty).join(', ').trim();
              } else {
                lastLocation = "${position.latitude}, ${position.longitude}";
              }
            } catch(e) {
              lastLocation = "${position.latitude}, ${position.longitude}";
            }
          }
        }
      } catch (e) {
        debugPrint("Location fetch error: $e");
      }

      // 3. Update PocketBase
      final body = <String, dynamic>{};
      if (lastIp.isNotEmpty) body['last_ip'] = lastIp;
      if (lastLocation.isNotEmpty) body['last_location'] = lastLocation;
      
      // Update last_seen
      body['last_seen'] = DateTime.now().toUtc().toIso8601String().replaceFirst('T', ' ');

      if (body.isNotEmpty) {
        await PocketBaseService.client.collection('users').update(userId, body: body);
      }
    } catch (e) {
      debugPrint("Metadata update error: $e");
    }
  }
}
