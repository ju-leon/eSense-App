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

class Event extends StatefulWidget {
  final String title;
  final int id;
  final String description;

  Event({this.title, this.id, this.description});

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      description: json['description'],
    );
  }

  @override
  _EventViewState createState() => _EventViewState(this);
}

class _EventViewState extends State<Event> {
  Event event;

  _EventViewState(this.event);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.album),
              title: Text(event.title),
              subtitle: Text(event.description),
            ),
            ButtonBar(
              children: <Widget>[
                FlatButton(
                  child: const Text('CHECK TICKETS'),
                  onPressed: () {
                    Navigator.push(
                        context,
                        new MaterialPageRoute(
                            builder: (context) => new Scanning(event.id)));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
