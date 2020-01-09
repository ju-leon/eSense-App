import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

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

class Scanning extends StatefulWidget {
  @override
  _ScanningState createState() => _ScanningState();
}

class _ScanningState extends State<Scanning> {
  String result = "Hey there !";

  Future _scanQR() async {
    print("Was here");

    try {
      String qrResult = await BarcodeScanner.scan();
      setState(() {
        result = qrResult;
        Navigator.push(
          context,
          new MaterialPageRoute(builder: (context) => new Ticket(username: result.split(';')[1], eventid: int.parse(result.split(';')[0]))),
        );
        print("Result: " + result);
      });
    } on PlatformException catch (ex) {
      if (ex.code == BarcodeScanner.CameraAccessDenied) {
        setState(() {
          result = "Camera permission was denied";
        });
      } else {
        setState(() {
          result = "Unknown Error $ex";
        });
      }
    } on FormatException {
      setState(() {
        result = "You pressed the back button before scanning anything";
      });
    } catch (ex) {
      setState(() {
        result = "Unknown Error $ex";
      });
    }
  }

  _ScanningState() {
    _scanQR();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: AppBar(
        title: const Text('eSense Demo App'),
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: ListView(
          children: [
            Text(result),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        // a floating button that starts/stops listening to sensor events.
        // is disabled until we're connected to the device.
        onPressed: () {
          _scanQR();
        },
      ),
    );
  }
}

/*
Navigator.push(
            context,
            new MaterialPageRoute(builder: (context) => new Ticket()),
          );
 */
