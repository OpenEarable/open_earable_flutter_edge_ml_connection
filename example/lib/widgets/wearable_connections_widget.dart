import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:open_earable_flutter/open_earable_flutter.dart';

class WearableConnectionsWidget extends StatelessWidget {
  final List<DiscoveredDevice> discoveredDevices;
  final List<DiscoveredDevice> connectingDevices;
  final List<Wearable> connectedWearables;
  final void Function(DiscoveredDevice) connectWearable;
  final bool disabled;

  const WearableConnectionsWidget({
    super.key,
    required this.discoveredDevices,
    required this.connectingDevices,
    required this.connectedWearables,
    required this.connectWearable,
    this.disabled = false,
  });

  Widget _buildTrailingWidget(String id) {
    if (connectedWearables.any((wearable) => wearable.deviceId == id)) {
      return const Icon(Icons.check, color: Colors.green, size: 24);
    } else if (connectingDevices.any((device) => device.id == id)) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: discoveredDevices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No devices found',
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: discoveredDevices.length,
              itemBuilder: (BuildContext context, int index) {
                final device = discoveredDevices[index];
                return Column(
                  children: [
                    ListTile(
                      textColor: disabled ? Colors.grey : Colors.black,
                      selectedTileColor: Colors.grey,
                      title: Text(device.name),
                      titleTextStyle: TextStyle(
                        fontSize: 16,
                        color: disabled ? Colors.grey : Colors.black,
                      ),
                      visualDensity:
                          const VisualDensity(horizontal: -4, vertical: -4),
                      trailing: _buildTrailingWidget(device.id),
                      onTap: disabled
                          ? null
                          : () {
                              Wearable? wearable =
                                  connectedWearables.firstWhereOrNull(
                                (w) => w.deviceId == device.id,
                              );
                              if (wearable != null) {
                                wearable.disconnect();
                              } else {
                                connectWearable(device);
                              }
                            },
                    ),
                    if (index != discoveredDevices.length - 1)
                      const Divider(
                        height: 1.0,
                        thickness: 1.0,
                        color: Colors.grey,
                        indent: 16.0,
                        endIndent: 0.0,
                      ),
                  ],
                );
              },
            ),
    );
  }
}
