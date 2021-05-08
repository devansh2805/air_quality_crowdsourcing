import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ignore: must_be_immutable
class MapPage extends StatefulWidget {
  GeoPoint userLocation;
  double airQualityIndex;
  MapPage(GeoPoint location, double aqi) {
    userLocation = location;
    airQualityIndex = aqi;
  }
  @override
  State<StatefulWidget> createState() =>
      MapPageState(userLocation, airQualityIndex);
}

class MapPageState extends State<MapPage> {
  GeoPoint userLocation;
  double airQualityIndex;
  Completer<GoogleMapController> _controller = Completer();
  List<Marker> markers = <Marker>[];

  MapPageState(GeoPoint location, double aqi) {
    userLocation = location;
    airQualityIndex = aqi;
    initialiseMarker();
  }

  void initialiseMarker() {
    print(userLocation.latitude);
    markers.add(
      Marker(
        position: LatLng(
          userLocation.latitude,
          userLocation.longitude,
        ),
        infoWindow: InfoWindow(
          title: airQualityIndex.toString(),
        ),
        markerId: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        mapType: MapType.satellite,
        initialCameraPosition: CameraPosition(
          target: LatLng(
            userLocation.latitude,
            userLocation.longitude,
          ),
        ),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        // markers: Set<Marker>.of(markers),
      ),
    );
  }
}
