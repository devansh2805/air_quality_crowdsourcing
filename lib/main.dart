import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:air_quality_app/login.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geocoding/geocoding.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:http/http.dart' as http;
import 'package:air_quality_app/keys.dart' as keys;
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(AirQualityApp());
}

class AirQualityApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Quality App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? LoginPage()
          : MyHomePage(title: 'My Air'),
    );
  }
}

class AQI {
  var pm25;
  var pm10;
  var aqi;
  var dt;
  AQI(
      {@required this.pm25,
      @required this.pm10,
      @required this.aqi,
      @required this.dt});

  factory AQI.fromJSON(Map<String, dynamic> json) {
    return AQI(
      pm25: json['list'][0]['components']['pm2_5'],
      pm10: json['list'][0]['components']['pm10'],
      aqi: json['list'][0]['main']['aqi'],
      dt: json['list'][0]['dt'],
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double aqiValue = 0.0;
  Timer timer;
  String currentAddress = " ";
  String pidata = " ";
  String pm2 = " ";
  String pm10 = " ";
  String lat = " ";
  String long = " ";
  String timestamp = " ";
  bool flag = false;
  Future<AQI> futureAQI;
  String aqi;
  String pm25G;
  String pm10G;
  String dt;
  final databaseReference = FirebaseDatabase.instance.reference();

  void initState() {
    super.initState();
    getPosition();
    timer = Timer.periodic(Duration(seconds: 10), (Timer t) => getData());
  }

  Future<AQI> fetchAQI() async {
    var apiKey = keys.ak;
    Uri url = Uri.parse(
        'http://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$long&appid=$apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return AQI.fromJSON(
        jsonDecode(
          response.body,
        ),
      );
    } else {
      throw Exception(
        "Failed to load AQI Data, Response from Server = ${response.statusCode}",
      );
    }
  }

  void getPosition() async {
    Position pos = await _determinePosition();
    List<Placemark> placemarks =
        await placemarkFromCoordinates(pos.latitude, pos.longitude);
    Placemark place = placemarks[0];
    setState(
      () {
        currentAddress =
            "${place.locality}, ${place.postalCode}, ${place.country}";
      },
    );
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission locationPermission;
    locationPermission = await Geolocator.checkPermission();
    if (locationPermission == LocationPermission.denied) {
      locationPermission = await Geolocator.requestPermission();
      if (locationPermission == LocationPermission.deniedForever) {
        return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.',
        );
      }
      if (locationPermission == LocationPermission.denied) {
        return Future.error(
          'Location permissions are denied',
        );
      }
    }
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!await Geolocator.openLocationSettings()) {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text(
                "Cannot open Location Settings, Please turn then on manually",
              ),
            );
          },
        );
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  String getText() {
    String measurementLabel;
    if (aqiValue >= 0 && aqiValue < 50) {
      measurementLabel = "Very Good";
    } else if (aqiValue >= 50 && aqiValue < 100) {
      measurementLabel = "Good";
    } else if (aqiValue >= 100 && aqiValue < 200) {
      measurementLabel = "Satisfactory";
    } else if (aqiValue >= 200 && aqiValue < 300) {
      measurementLabel = "Poor";
    } else if (aqiValue >= 300 && aqiValue < 400) {
      measurementLabel = "Very Poor";
    } else if (aqiValue >= 400 && aqiValue < 500) {
      measurementLabel = "Severe";
    }
    return measurementLabel;
  }

  void getData() async {
    Position pos = await _determinePosition();
    lat = pos.latitude.toString();
    long = pos.longitude.toString();
    futureAQI = fetchAQI();
    setState(() {
      futureAQI.then((value) {
        pm25G = value.pm25.toString();
        pm10G = value.pm10.toString();
        dt = DateTime.fromMicrosecondsSinceEpoch(value.dt).toString();
      });
    });
    var data = "192.168.43.1".split('.');
    String ipPrefix = data[0] + '.' + data[1] + '.' + data[2];
    for (var i = 0; i <= 255; i++) {
      Socket.connect(ipPrefix + '.' + (i.toString()), 5020).then(
        (Socket socket) {
          socket.listen(
            (event) {
              Map<String, dynamic> obj = jsonDecode(utf8.decode(event));
              pm2 = obj["PM2_5"];
              pm10 = obj["PM10"];
              timestamp = obj["timestamp"];
              aqiValue = double.parse(obj["AQI"]);
              obj.addAll({"lat": lat, "long": long});
              print(obj);
              databaseReference.push().set(obj);
              setState(
                () {
                  pidata = utf8.decode(event) + " " + lat + " " + long;
                  flag = true;
                },
              );
              print(pidata);
            },
          );
        },
      ).catchError((onError) {});
    }
  }

  Widget topCardWidget() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        40,
        0,
        40,
        0,
      ),
      padding: EdgeInsets.fromLTRB(
        30,
        20,
        30,
        20,
      ),
      decoration: BoxDecoration(
        color: Color(
          0xfff2f4fb,
        ),
        borderRadius: BorderRadius.all(
          Radius.circular(
            20,
          ),
        ),
      ),
      child: Column(
        children: [
          SfRadialGauge(
            enableLoadingAnimation: true,
            animationDuration: 4500,
            title: GaugeTitle(
              text: 'Location Specific AQI',
              textStyle: const TextStyle(
                fontWeight: FontWeight.w300,
                fontSize: 20.0,
              ),
            ),
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum: 500,
                showLabels: false,
                showAxisLine: false,
                showTicks: false,
                ranges: <GaugeRange>[
                  GaugeRange(
                    // label: 'Good',
                    startValue: 0,
                    endValue: 50,
                    color: Color(0xff83a95c),
                    startWidth: 25,
                    endWidth: 25,
                    labelStyle: GaugeTextStyle(
                      fontSize: 8,
                    ),
                  ),
                  GaugeRange(
                    // label: 'Satisfactory',
                    startValue: 50,
                    endValue: 100,
                    color: Color(0xff70af85),
                    startWidth: 25,
                    endWidth: 25,
                    labelStyle: GaugeTextStyle(
                      fontSize: 8,
                    ),
                  ),
                  GaugeRange(
                    // label: 'Moderate',
                    startValue: 100,
                    endValue: 200,
                    color: Color(0xffc6ebc9),
                    startWidth: 25,
                    endWidth: 25,
                    labelStyle: GaugeTextStyle(
                      fontSize: 8,
                    ),
                  ),
                  GaugeRange(
                    // label: 'Poor',
                    startValue: 200,
                    endValue: 300,
                    color: Color(0xfff8d49d),
                    startWidth: 25,
                    endWidth: 25,
                    labelStyle: GaugeTextStyle(
                      fontSize: 8,
                    ),
                  ),
                  GaugeRange(
                    // label: 'Very poor',
                    startValue: 300,
                    endValue: 400,
                    color: Color(0xffefb08c),
                    startWidth: 25,
                    endWidth: 25,
                    labelStyle: GaugeTextStyle(
                      fontSize: 8,
                    ),
                  ),
                  GaugeRange(
                    // label: 'Severe',
                    startValue: 400,
                    endValue: 500,
                    color: Color(0xffd35d6e),
                    startWidth: 25,
                    endWidth: 25,
                    labelStyle: GaugeTextStyle(
                      fontSize: 8,
                    ),
                  ),
                ],
                pointers: <GaugePointer>[
                  NeedlePointer(
                    value: aqiValue,
                    enableAnimation: true,
                    needleLength: 0.8,
                    needleStartWidth: 0.5,
                    needleEndWidth: 5,
                    knobStyle: KnobStyle(
                      knobRadius: 0.04,
                    ),
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    widget: Container(
                      child: Column(
                        children: [
                          SizedBox(
                            height: 10,
                          ),
                          Text(
                            '$aqiValue',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            getText(),
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w100,
                            ),
                          ),
                        ],
                      ),
                    ),
                    angle: 90,
                    positionFactor: 0.5,
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 35,
              ),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 5,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'PM 2.5',
                      style:
                          TextStyle(fontWeight: FontWeight.w100, fontSize: 20),
                    ),
                    Text(
                      '$pm2',
                      style:
                          TextStyle(fontWeight: FontWeight.w300, fontSize: 20),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
              ),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      10,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 5,
                      offset: Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'PM 10',
                      style: TextStyle(
                        fontWeight: FontWeight.w100,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '$pm10',
                      style: TextStyle(
                        fontWeight: FontWeight.w300,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget bottomCardWidget() {
    return Container(
      margin: EdgeInsets.fromLTRB(
        40,
        20,
        40,
        0,
      ),
      padding: EdgeInsets.fromLTRB(
        30,
        20,
        30,
        20,
      ),
      decoration: BoxDecoration(
          color: Color(0xfff2f4fb),
          borderRadius: BorderRadius.all(Radius.circular(20))),
      child: Column(
        children: [
          Text("PM Values from OpenWeatherMap API"),
          SizedBox(
            height: 5,
          ),
          if (pm25G != null)
            Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 35,
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(
                          Radius.circular(
                            10,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 5,
                            blurRadius: 5,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'PM 2.5',
                            style: TextStyle(
                              fontWeight: FontWeight.w100,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '$pm25G',
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 40,
                    ),
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(
                          Radius.circular(
                            10,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 5,
                            blurRadius: 5,
                            offset: Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'PM 10',
                            style: TextStyle(
                              fontWeight: FontWeight.w100,
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            '$pm10G',
                            style: TextStyle(
                              fontWeight: FontWeight.w300,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 20,
                    ),
                  ],
                ),
                // Text("$dt")
              ],
            )
          else
            CircularProgressIndicator()
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.title,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Color(0xff00C6BD),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 20,
          ),
          Container(
            child: Text(
              '$currentAddress',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w100,
                  color: Color(0xff848484)),
            ),
          ),
          SizedBox(
            height: 30,
          ),
          topCardWidget(),
          bottomCardWidget()
          // SlimyCard(
          //   width: 350,
          //   topCardHeight: 350,
          //   color: Color(0xfff2f4fb),
          //   topCardWidget: topCardWidget(),
          //   bottomCardWidget: bottomCardWidget(),
          // ),
        ],
      ),
    );
  }
}
