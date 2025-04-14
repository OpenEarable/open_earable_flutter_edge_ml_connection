import 'dart:async';

import 'package:example/widgets/edge_ml_settings.dart';
import 'package:example/widgets/grouped_box.dart';
import 'package:example/widgets/wearable_connections_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:open_earable_flutter_edge_ml_connection/open_earable_flutter_edge_ml_connection.dart';

import 'widgets/wearable_view.dart';

void main() {
  runApp(WearableTrackerApp());
}

class WearableTrackerApp extends StatefulWidget {
  const WearableTrackerApp({super.key});

  @override
  State<WearableTrackerApp> createState() => _WearableTrackerAppState();
}

class _WearableTrackerAppState extends State<WearableTrackerApp> {
  final List<DiscoveredDevice> _discoveredDevices = [];
  final List<DiscoveredDevice> _connectingDevices = [];
  final List<Wearable> _connectedWearables = [];

  final WearableManager _wearableManager = WearableManager();
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectSubscription;
  StreamSubscription? _connectingSubscription;

  bool _recording = false;

  OpenEarableEdgeMLConnection? _edgeMLConnection;

  @override
  void initState() {
    super.initState();

    // Listen for new discovered devices
    _scanSubscription = _wearableManager.scanStream.listen((incomingDevice) {
      if (incomingDevice.name.isNotEmpty &&
          !_discoveredDevices.any((device) => device.id == incomingDevice.id)) {
        setState(() {
          _discoveredDevices.add(incomingDevice);
        });
      }
    });

    // Listen for new connected devices
    _connectSubscription =
        _wearableManager.connectStream.listen(_onWearableConnect);

    // Listen for new connecting devices
    _connectingSubscription =
        _wearableManager.connectingStream.listen((device) {
      setState(() {
        if (!_connectingDevices.any((d) => d.id == device.id)) {
          _connectingDevices.add(device);
        }
      });
    });

    _startScanning();
  }

  Future<void> _onOnlineStart(
    String url,
    String apiKey,
    String datasetName,
  ) async {
    setState(() {
      _recording = true;
    });

    _edgeMLConnection =
        await OpenEarableEdgeMLConnection.createOnlineConnection(
      url: url,
      key: apiKey,
      name: datasetName,
      readFrequencyLimitHz: 10,
      wearableSensorGroups: _connectedWearables
          .map(
            (w) => WearableSensorGroup(
              wearable: w,
            ),
          )
          .toList(),
      metaData: {
        'app': 'Connection Example',
      },
    );
  }

  Future<void> _onCsvStart(String datasetName) async {
    setState(() {
      _recording = true;
    });

    CsvOpenEarableEdgeMLConnection newConnection =
        await OpenEarableEdgeMLConnection.createCsvConnection(
      name: datasetName,
      readFrequencyLimitHz: 10,
      wearableSensorGroups: _connectedWearables
          .map(
            (w) => WearableSensorGroup(
              wearable: w,
            ),
          )
          .toList(),
      metaData: {
        'app': 'Connection Example',
      },
    );

    if (kDebugMode) {
      print("");
      print("CSV Path: \"${newConnection.filePath}\"");
      print("");
    }

    _edgeMLConnection = newConnection;
  }

  void _onStop() {
    setState(() {
      _recording = false;
    });
    _edgeMLConnection?.stop();
    _edgeMLConnection = null;
  }

  void _onWearableConnect(Wearable wearable) {
    setState(() {
      _connectedWearables.add(wearable);
      _connectingDevices
          .removeWhere((device) => device.id == wearable.deviceId);
    });
    wearable.addDisconnectListener(() {
      setState(() {
        _connectedWearables.removeWhere((w) => w.deviceId == wearable.deviceId);
      });
    });

    // Enable every sensor
    if (wearable is SensorManager) {
      for (Sensor sensor in (wearable as SensorManager).sensors) {
        for (SensorConfiguration config in sensor.relatedConfigurations) {
          if (config is SensorFrequencyConfiguration) {
            config.setMaximumFrequency();
          }
        }
      }
    }

    _edgeMLConnection?.reconnectWearable(wearable);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mouse & Drag Tracker',
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  EdgeMLSettings(
                    onStop: _onStop,
                    onOnlineStart: _onOnlineStart,
                    onCsvStart: _onCsvStart,
                  ),
                  const Divider(),
                  GroupedBox(
                    title: 'Scanned Wearables',
                    child: Column(
                      children: [
                        WearableConnectionsWidget(
                          disabled: _recording,
                          discoveredDevices: _discoveredDevices,
                          connectingDevices: _connectingDevices,
                          connectedWearables: _connectedWearables,
                          connectWearable: _wearableManager.connectToDevice,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: ElevatedButton(
                            onPressed: _startScanning,
                            child: const Text('Restart Scan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  ...WearableView.createWearableViews(_connectedWearables).map(
                    (view) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: view,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectSubscription?.cancel();
    _connectingSubscription?.cancel();
    super.dispose();
  }

  void _startScanning() {
    _discoveredDevices.clear();
    _wearableManager.startScan(excludeUnsupported: true);
  }
}
