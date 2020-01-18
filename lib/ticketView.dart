import 'dart:io';

import 'package:esense/main.dart';
import 'package:esense_flutter/esense.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:esense/scanningView.dart';
import 'package:esense/ticketView.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:semaphore/semaphore.dart';

const db_url = 'https://api.jungemeyer.com';
const predict_url = 'http://compute.jungemeyer.com';

Future<Ticket> queryTicket(username, eventid, wrongEvent) async {
  final response = await http.get(
      db_url +
          "/event/public/getTicket?event_id=" +
          eventid.toString() +
          "&username=" +
          username,
      headers: {
        "Content-Type": "application/json",
        HttpHeaders.authorizationHeader:
            "Basic " + base64Encode(utf8.encode('max:123456'))
      });

  if (response.statusCode == 200) {
    // If server returns an OK response, parse the JSON.
    return Ticket.fromJson(json.decode(response.body), wrongEvent);
  } else {
    // If that response was not OK, throw an error.
    throw Exception('Failed to load post');
  }
}

class Ticket extends StatefulWidget {
  final int eventid;
  final String username;
  final String status;

  final Map<String, dynamic> user;
  final Map<String, dynamic> event;

  final bool checkIn;

  final DateTime age;

  final bool wrongEvent;

  Ticket(
      {this.eventid,
      this.username,
      this.user,
      this.event,
      this.checkIn,
      this.age,
      this.status,
      this.wrongEvent});

  factory Ticket.fromJson(Map<String, dynamic> json, wrongEvent) {
    return Ticket(
      eventid: json['event']['id'],
      username: json['participant']['username'],
      user: json['participant'],
      event: json['event'],
      checkIn: json['checkedIn'],
      status: json['status'],
      age: DateTime.parse(json['participant']['birthday'] + " 00:00:00"),
      wrongEvent: wrongEvent,
    );
  }

  @override
  _TicketViewState createState() =>
      _TicketViewState(username, eventid, wrongEvent);
}

class _TicketViewState extends State<Ticket> {
  Future<Ticket> ticket;

  var _username;
  var _eventId;
  var _wrongEvent;
  var _event;
  var _measures = [];
  var _status;

  var _prediction = "EMPTY";

  final _sm = LocalSemaphore(1);
  bool sampling = false;

  _TicketViewState(this._username, this._eventId, this._wrongEvent);

  StreamSubscription subscription;

  Future<bool> checkin(username, eventid, status) async {
    if (_wrongEvent) {
      return null;
    }

    final response = await http.put(
        db_url +
            "/event/public/checkIn?event_id=" +
            eventid.toString() +
            "&username=" +
            username +
            "&state=" +
            status,
        headers: {
          "Content-Type": "application/json",
          HttpHeaders.authorizationHeader:
              "Basic " + base64Encode(utf8.encode('max:123456'))
        });

    if (response.statusCode == 200) {
      // If server returns an OK response, parse the JSON.
      return true;
    } else {
      // If that response was not OK, throw an error.
      return false;
    }
  }

  void _startListenToSensorEvents() async {
    // subscribe to sensor event from the eSense device
    print("Sart listening");

    if (MyAppState.status == ConnectionType.connected) {
      subscription = ESenseManager.sensorEvents.listen((event) async {
        print('SENSOR event: $event');
        setState(() {
          _event = event.toString();
        });

        await _sm.acquire();
        for (int i = 0; i < 3; i++) {
          if (_measures.length == 300) {
            _measures.removeAt(0);
          }
          _measures.add(event.accel[i]);
        }
        for (int i = 0; i < 3; i++) {
          if (_measures.length == 300) {
            _measures.removeAt(0);
          }
          _measures.add(event.gyro[i]);
        }

        _sm.release();
      });

      setState(() {
        sampling = true;
      });
    }
  }

  Future<void> predict() async {
    if (_measures.length < 300) {
      await Future.delayed(Duration(seconds: 1));
      predict();
      return;
    }

    await _sm.acquire();
    String json = _measures.toString();
    _sm.release();

    var response = await http.post(predict_url + "/predict",
        headers: {"Content-Type": "application/json"}, body: json);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    var jsonRespone = jsonDecode(response.body);

    switch (jsonRespone['winner']) {
      case 'no':
        {
          _prediction = "NO";
          _pauseListenToSensorEvents();
          handleRefusedPress();
        }
        break;
      case 'yes':
        {
          _prediction = "YES";
          _pauseListenToSensorEvents();
          handleOkPress();
        }
        break;
      default:
        {
          _prediction = "EMPTY";
          predict();
        }
        break;
    }
  }

  void handleOkPress() async {
    await checkin(_username, _eventId, "entered");
    Navigator.pop(context, false);
  }

  void handleRefusedPress() async {
    await checkin(_username, _eventId, "refused");
    Navigator.pop(context, false);
  }

  void _pauseListenToSensorEvents() async {
    if (MyAppState.status == ConnectionType.connected) {
      subscription.cancel();
      setState(() {
        sampling = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    ticket = queryTicket(_username, _eventId, _wrongEvent);
    _startListenToSensorEvents();
    ESenseManager.setSamplingRate(100);
    predict();
  }

  Widget getIcon() {
    if (MyAppState.status != ConnectionType.connected) {
      return Icon(
        Icons.bluetooth_disabled,
        color: Colors.blue,
        size: 50,
      );
    }

    if (_prediction == "NO") {
      return Icon(
        Icons.clear,
        color: Colors.red,
        size: 200,
      );
    }

    if (_prediction == "EMPTY") {
      return SpinKitRipple(
        color: Colors.black87,
        size: 200,
      );
    }

    return Icon(
      Icons.done,
      color: Colors.green,
      size: 200,
    );
  }

  Text getStatus(status) {
    if (_wrongEvent) {
      return Text(
        "TICKET NOT VALID FOR EVENT",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 40,
          color: Colors.red,
        ),
      );
    }

    if (status == "refused") {
      return Text(
        "Ticket refused",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 40,
          color: Colors.red,
        ),
      );
    }
    if (status == "entered") {
      return Text(
        "Already entered",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 40,
          color: Colors.yellow,
        ),
      );
    }

    return Text(
      "Ticket valid",
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 40,
        color: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Ticket'),
          backgroundColor: Colors.purple,
        ),
        body: FutureBuilder<Ticket>(
          future: ticket,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Column(
                children: <Widget>[
                  Center(
                    child: Image.network(db_url +
                        "/user/profile?user=" +
                        snapshot.data.username),
                  ),
                  Text(
                    snapshot.data.user['firstName'] +
                        " " +
                        snapshot.data.user['lastName'],
                    style: TextStyle(
                      fontSize: 45,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    "age: " +
                        (DateTime.now().difference(snapshot.data.age).inDays /
                                365)
                            .floor()
                            .toString() +
                        " (" +
                        snapshot.data.age.day.toString() +
                        "." +
                        snapshot.data.age.month.toString() +
                        "." +
                        snapshot.data.age.year.toString() +
                        ")",
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.black87,
                    ),
                  ),
                  getStatus(snapshot.data.status),
                  Spacer(),
                  Center(
                    child: getIcon(),
                  ),
                  Spacer(),
                  ButtonBar(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      new FloatingActionButton(
                          heroTag: "okBtn",
                          backgroundColor: Colors.green[400],
                          child: Icon(Icons.check),
                          onPressed: handleOkPress),
                      SizedBox(height: 50),
                      new FloatingActionButton(
                          heroTag: "refBtn",
                          backgroundColor: Colors.red[400],
                          child: Icon(Icons.clear),
                          onPressed: handleRefusedPress),
                    ],
                  )
                ],
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }

            // By default, show a loading spinner.
            return Center(child: CircularProgressIndicator());
          },
        ));
  }
}
