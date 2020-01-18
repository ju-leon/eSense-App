import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:esense/eventCard.dart';
import 'package:esense/scanningView.dart';
import 'package:esense/ticketView.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:esense_flutter/esense.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:downloads_path_provider/downloads_path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite/tflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:semaphore/semaphore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

Future<List<Event>> queryEvents() async {
  final response = await http.get(db_url + "/event/private/list", headers: {
    "Content-Type": "application/json",
    HttpHeaders.authorizationHeader:
        "Basic " + base64Encode(utf8.encode('max:123456'))
  });

  if (response.statusCode == 200) {
    // If server returns an OK response, parse the JSON.
    Iterable l = json.decode(response.body);
    List<Event> events = l.map((i) => Event.fromJson(i)).toList();
    return events;
  } else {
    // If that response was not OK, throw an error.
    throw Exception('Failed to load post');
  }
}

class _MyAppState extends State<MyApp> {
  String _deviceName = 'Unknown';
  double _voltage = -1;
  ConnectionType _status = ConnectionType.unknown;
  bool sampling = false;
  String _event = '';
  String _button = 'not pressed';
  int _accel = 0;

  List<int> _measures;
  int _count = 0;
  int _fileNumber = 0;

  String _prediction = "NONE";

  // the name of the eSense device to connect to -- change this to your own device.
  String eSenseName = 'eSense-0176';

  bool isConnected = false;

  final _sm = LocalSemaphore(1);

  @override
  void initState() {
    super.initState();
    _connectToESense();
  }

  Future<void> _connectToESense() async {
    bool con = false;

    // if you want to get the connection events when connecting, set up the listener BEFORE connecting...
    ESenseManager.connectionEvents.listen((event) {
      print('CONNECTION event: $event');

      // when we're connected to the eSense device, we can start listening to events from it
      if (event.type == ConnectionType.connected) _listenToESenseEvents();

      setState(() {
        _status = event.type;
      });
    });

    isConnected = await ESenseManager.connect(eSenseName);
  }

  void _listenToESenseEvents() async {
    ESenseManager.eSenseEvents.listen((event) {
      print('ESENSE event: $event');

      setState(() {
        switch (event.runtimeType) {
          case DeviceNameRead:
            _deviceName = (event as DeviceNameRead).deviceName;
            break;
          case BatteryRead:
            _voltage = (event as BatteryRead).voltage;
            break;
          case ButtonEventChanged:
            _button = (event as ButtonEventChanged).pressed
                ? 'pressed'
                : 'not pressed';
            if (_button == 'pressed') {
              print("Was 2 here");
            }
            break;
          case AccelerometerOffsetRead:
            _accel = (event as AccelerometerOffsetRead).offsetX;
            break;
          case AdvertisementAndConnectionIntervalRead:
            // TODO
            break;
          case SensorConfigRead:
            // TODO
            break;
        }
      });
    });

    _getESenseProperties();
  }

  void _getESenseProperties() async {
    // get the battery level every 10 secs
    Timer.periodic(Duration(seconds: 10),
        (timer) async => await ESenseManager.getBatteryVoltage());

    Timer.periodic(Duration(seconds: 10),
        (timer) async => await ESenseManager.getSensorConfig());

    // wait 2, 3, 4, 5, ... secs before getting the name, offset, etc.
    // it seems like the eSense BTLE interface does NOT like to get called
    // several times in a row -- hence, delays are added in the following calls
    Timer(
        Duration(seconds: 2), () async => await ESenseManager.getDeviceName());
    Timer(Duration(seconds: 3),
        () async => await ESenseManager.getAccelerometerOffset());
    Timer(
        Duration(seconds: 4),
        () async =>
            await ESenseManager.getAdvertisementAndConnectionInterval());
    Timer(Duration(seconds: 5),
        () async => await ESenseManager.getSensorConfig());
  }

  StreamSubscription subscription;

  reconnect() {
    setState(() {
      _status = ConnectionType.unknown;
    });
    ESenseManager.disconnect();
    _connectToESense();
  }

  FloatingActionButton fab() {
    switch (_status) {
      case ConnectionType.connected:
        return new FloatingActionButton(
            child: Icon(Icons.bluetooth_connected),
            onPressed: ESenseManager.disconnect);
      case ConnectionType.unknown:
        return new FloatingActionButton(
          onPressed: null,
          child: SpinKitRotatingCircle(
            color: Colors.white,
            size: 50.0,
          ),
        );
      case ConnectionType.disconnected:
        return new FloatingActionButton(
            child: Icon(Icons.bluetooth_disabled), onPressed: reconnect);
      case ConnectionType.device_found:
        return new FloatingActionButton(
            child: SpinKitDoubleBounce(
              color: Colors.white,
              size: 50.0,
            ),
            onPressed: null);
      case ConnectionType.device_not_found:
        return new FloatingActionButton(
            child: Icon(Icons.device_unknown), onPressed: reconnect);
    }
  }

  Widget build(BuildContext context) {
    return MaterialApp(
        home: new Scaffold(
            appBar: AppBar(
              title: const Text('Connect Scanner'),
            ),
            body: Align(
              alignment: Alignment.topLeft,
              child: HomeScreen(),
            ),
            floatingActionButton: fab()));
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Event>> events;

  @override
  void initState() {
    super.initState();
    events = queryEvents();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Event>>(
      future: events,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return new ListView.builder(
            itemCount: snapshot.data.length == null ? 0 : snapshot.data.length,
            itemBuilder: (BuildContext context, i) {
              return snapshot.data[i];
            },
          );
        } else if (snapshot.hasError) {
          return Text("${snapshot.error}");
        }

        // By default, show a loading spinner.
        return Center(child: CircularProgressIndicator());
      },
    );

    return Align(alignment: Alignment.topLeft, child: Center(child: Event()));
  }
}
