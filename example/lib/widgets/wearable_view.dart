import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

import 'grouped_box.dart';
import 'sensor_view.dart';

class WearableView extends StatelessWidget {
  final Wearable wearable;

  const WearableView({
    super.key,
    required this.wearable,
  });

  @override
  Widget build(BuildContext context) {
    // Get the sensor views for the wearable. If null, use an empty list.
    final sensorViews = SensorView.createSensorViews(wearable);
    return GroupedBox(
      title: wearable.name,
      child: Column(
        children: sensorViews ?? [],
      ),
    );
  }

  static List<Widget> createWearableViews(List<Wearable> wearables) {
    return wearables.map((w) => WearableView(wearable: w)).toList();
  }
}
