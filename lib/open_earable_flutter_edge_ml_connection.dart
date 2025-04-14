import 'dart:async';
import 'package:open_earable_flutter/open_earable_flutter.dart';
import 'package:edge_ml_dart/edge_ml_dart.dart';

class WearableSensorGroup {
  final Wearable wearable;
  final List<Sensor>? sensors;

  WearableSensorGroup({
    required this.wearable,
    this.sensors,
  });
}

class OpenEarableEdgeMLConnection {
  final List<WearableSensorGroup> wearableSensorGroups;
  final Map<String, dynamic> metaData;

  final DatasetCollector collector;

  final List<StreamSubscription> _sensorSubscriptions = [];

  final double? readFrequencyLimitHz;

  // Map to accumulate sensor data until flush time.
  // Key is a unique name for the time series, value is a number.
  final Map<String, num> _accumulatedData = {};

  Timer? _writeTimer;

  OpenEarableEdgeMLConnection._({
    required this.wearableSensorGroups,
    required this.metaData,
    required this.collector,
    this.readFrequencyLimitHz,
  });

  static Future<OpenEarableEdgeMLConnection> createOnlineConnection({
    required String url,
    required String key,
    required String name,
    required List<WearableSensorGroup> wearableSensorGroups,
    required Map<String, dynamic> metaData,
    double? readFrequencyLimitHz,
  }) async {
    final DatasetCollector collector = await OnlineDatasetCollector.create(
      url: url,
      key: key,
      name: name,
      useDeviceTime: false,
      timeSeries: _getTimeSeriesNames(wearableSensorGroups),
      metaData: metaData,
    );

    final instance = OpenEarableEdgeMLConnection._(
      wearableSensorGroups: wearableSensorGroups,
      metaData: metaData,
      collector: collector,
      readFrequencyLimitHz: readFrequencyLimitHz,
    );
    await instance._initialize();
    return instance;
  }

  static Future<CsvOpenEarableEdgeMLConnection> createCsvConnection({
    required String name,
    required List<WearableSensorGroup> wearableSensorGroups,
    required Map<String, dynamic> metaData,
    double? readFrequencyLimitHz,
    bool allowUnsupportedString = false,
  }) async {
    final CsvDatasetCollector collector = await CsvDatasetCollector.create(
      name: name,
      useDeviceTime: false,
      timeSeries: _getTimeSeriesNames(wearableSensorGroups),
      metaData: metaData,
      allowUnsupportedString: allowUnsupportedString,
    );

    final instance = CsvOpenEarableEdgeMLConnection._(
      wearableSensorGroups: wearableSensorGroups,
      metaData: metaData,
      collector: collector,
      readFrequencyLimitHz: readFrequencyLimitHz,
    );
    await instance._initialize();
    return instance;
  }

  Future<void> _initialize() async {
    for (var group in wearableSensorGroups) {
      final wearable = group.wearable;
      final sensors = group.sensors ?? _getAllSensors(wearable);

      for (var sensor in sensors) {
        if (sensor is Sensor<SensorIntValue> ||
            sensor is Sensor<SensorDoubleValue>) {
          final subscription = sensor.sensorStream.listen(
            (readFrequencyLimitHz != null)
                ? (sensorValue) {
                    for (var i = 0; i < sensor.axisCount; i++) {
                      final timeSeriesName =
                          _getDatapointName(wearable, sensor, i);

                      _accumulatedData[timeSeriesName] =
                          double.parse(sensorValue.valueStrings[i]);
                    }
                  }
                : (sensorValue) {
                    int timestamp = DateTime.now().millisecondsSinceEpoch;

                    for (var i = 0; i < sensor.axisCount; i++) {
                      final timeSeriesName =
                          _getDatapointName(wearable, sensor, i);

                      collector.addDataPoint(
                        time: timestamp,
                        name: timeSeriesName,
                        value: double.parse(sensorValue.valueStrings[i]),
                      );
                    }
                  },
          );
          _sensorSubscriptions.add(subscription);
        }
      }

      wearable.addDisconnectListener(() async {
        await wearable.disconnect();
      });
    }

    if (readFrequencyLimitHz != null) {
      final intervalMs = (1000 / readFrequencyLimitHz!).round();
      _writeTimer =
          Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
        await _flushPendingData();
      });
    }
  }

  Future<void> _flushPendingData() async {
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    final dataToFlush = Map<String, num>.from(_accumulatedData);
    _accumulatedData.clear();

    for (final entry in dataToFlush.entries) {
      await collector.addDataPoint(
        time: timestamp,
        name: entry.key,
        value: entry.value,
      );
    }
  }

  Future<void> stop() async {
    for (var subscription in _sensorSubscriptions) {
      await subscription.cancel();
    }
    await _flushPendingData();
    _writeTimer?.cancel();
  }

  static String _getDatapointName(
    Wearable wearable,
    Sensor sensor,
    int axisIndex,
  ) {
    String result =
        '${wearable.name}--${wearable.deviceId}.${sensor.sensorName}.${sensor.axisNames[axisIndex]}';

    result = result.replaceAll(" ", "_");
    return result;
  }

  static List<String> _getTimeSeriesNames(
    List<WearableSensorGroup> wearableSensorGroups,
  ) {
    final List<String> timeSeriesNames = [];

    for (var group in wearableSensorGroups) {
      final wearable = group.wearable;
      final sensors = group.sensors ?? _getAllSensors(wearable);

      for (var sensor in sensors) {
        if (sensor is Sensor<SensorIntValue> ||
            sensor is Sensor<SensorDoubleValue>) {
          for (var i = 0; i < sensor.axisCount; i++) {
            timeSeriesNames.add(
              _getDatapointName(wearable, sensor, i),
            );
          }
        }
      }
    }

    return timeSeriesNames;
  }

  /// Reconnects a wearable after the connection was lost
  bool reconnectWearable(Wearable wearable) {
    // TODO Implement reconnection logic
    return false;
  }

  /// Stops collecting and cleans up stuff
  Future<void> dispose() async {
    await stop();
    await collector.dispose();
  }

  static List<Sensor> _getAllSensors(Wearable wearable) {
    if (wearable is SensorManager) {
      return (wearable as SensorManager).sensors;
    }
    return [];
  }
}

class CsvOpenEarableEdgeMLConnection extends OpenEarableEdgeMLConnection {
  CsvOpenEarableEdgeMLConnection._({
    required List<WearableSensorGroup> wearableSensorGroups,
    required Map<String, dynamic> metaData,
    required CsvDatasetCollector collector,
    double? readFrequencyLimitHz,
  }) : super._(
          wearableSensorGroups: wearableSensorGroups,
          metaData: metaData,
          collector: collector,
          readFrequencyLimitHz: readFrequencyLimitHz,
        );

  String get filePath {
    return (collector as CsvDatasetCollector).filePath;
  }

  static Future<List<String>> listCsvFiles() {
    return CsvDatasetCollector.listCsvFiles();
  }
}
