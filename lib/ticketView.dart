import 'dart:io';

import 'package:esense/main.dart';
import 'package:esense_flutter/esense.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:esense/scanningView.dart';
import 'package:esense/ticketView.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:intl/intl.dart';
import 'package:semaphore/semaphore.dart';

const db_url = 'http://192.168.0.107:8080';

Future<Ticket> queryTicket(username, eventid) async {
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
    return Ticket.fromJson(json.decode(response.body));
  } else {
    // If that response was not OK, throw an error.
    throw Exception('Failed to load post');
  }
}

class Ticket extends StatefulWidget {
  final int eventid;
  final String username;

  final Map<String, dynamic> user;
  final Map<String, dynamic> event;

  final bool checkIn;

  final DateTime age;

  Ticket(
      {this.eventid,
      this.username,
      this.user,
      this.event,
      this.checkIn,
      this.age});

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      eventid: json['event']['id'],
      username: json['participant']['username'],
      user: json['participant'],
      event: json['event'],
      checkIn: json['checkedIn'],
      age: DateTime.parse(json['participant']['birthday'] + " 00:00:00"),
    );
  }

  @override
  _TicketViewState createState() => _TicketViewState(username, eventid);
}

class _TicketViewState extends State<Ticket> {
  Future<Ticket> ticket;

  var _username;
  var _eventId;
  var _event;
  var _measures = [];

  var _prediction = "EMPTY";

  final _sm = LocalSemaphore(1);
  bool sampling = false;

  _TicketViewState(this._username, this._eventId);

  StreamSubscription subscription;

  Future<bool> checkin(username, eventid) async {
    final response = await http.put(
        db_url +
            "/event/public/checkIn?event_id=" +
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
      return true;
    } else {
      // If that response was not OK, throw an error.
      return false;
    }
  }

  void _startListenToSensorEvents() async {
    // subscribe to sensor event from the eSense device
    print("Sart listening");

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

  Future<void> predict() async {
    if (_measures.length < 300) {
      await Future.delayed(Duration(seconds: 1));
      predict();
      return;
    }

    var url = 'http://192.168.0.107:5000/predict';

    await _sm.acquire();
    String json = _measures.toString();
    _sm.release();

    var response = await http.post(url,
        headers: {"Content-Type": "application/json"}, body: json);

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    var jsonRespone = jsonDecode(response.body);

    switch (jsonRespone['winner']) {
      case 'no':
        {
          _prediction = "NO";
          _pauseListenToSensorEvents();
          Navigator.push(
            context,
            new MaterialPageRoute(builder: (context) => new Scanning()),
          );
        }
        break;
      case 'yes':
        {
          _prediction = "YES";
          _pauseListenToSensorEvents();
          await checkin(_username, _eventId);
          Navigator.push(
            context,
            new MaterialPageRoute(builder: (context) => new Scanning()),
          );
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

  void _pauseListenToSensorEvents() async {
    subscription.cancel();
    setState(() {
      sampling = false;
    });
  }

  void dispose() {
    _pauseListenToSensorEvents();
    //ESenseManager.disconnect();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ticket = queryTicket(_username, _eventId);
    _startListenToSensorEvents();
    ESenseManager.setSamplingRate(100);
    predict();
  }

  Icon getIcon() {
    if (_prediction == "NO") {
      return Icon(
        Icons.clear,
        color: Colors.red,
        size: 200,
      );
    }

    if (_prediction == "EMPTY") {
      return Icon(
        Icons.hearing,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Ticket'),
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
                    "Alter: " +
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
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    "Text",
                    style: TextStyle(
                      fontSize: 32,
                      color: Colors.black87,
                    ),
                  ),
                  Spacer(),
                  Center(
                    child: getIcon(),
                  ),
                  Spacer(),
                ],
              );
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            }

            // By default, show a loading spinner.
            return Center(child: CircularProgressIndicator());
          },
        ));

    /*
        
        Column(
          children: <Widget>[
            Center(
              child: Image.network(db_url +
                  "/user/profile?user=" +
                  _jsonResponse['participant']['username']),
            ),
            Text(
              "Max Mustermann",
              style: TextStyle(
                fontSize: 45,
                color: Colors.black87,
              ),
            ),
            Text(
              "Alter: 22 (06.10.1997)",
              style: TextStyle(
                fontSize: 32,
                color: Colors.red,
              ),
            ),
            Text(
              "Verified",
              style: TextStyle(
                fontSize: 32,
                color: Colors.black87,
              ),
            ),
            Spacer(),
            Center(
              child: new CircularProgressIndicator(),
            ),
            Spacer(),
          ],
        ));*/
  }
}
