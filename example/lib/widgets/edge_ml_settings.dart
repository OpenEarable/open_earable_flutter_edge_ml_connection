import 'package:flutter/material.dart';

const String edgeMlUrl = String.fromEnvironment(
  'EDGE_ML_URL',
  defaultValue: 'https://app.edge-ml.org',
);
const String edgeMlApiKey = String.fromEnvironment(
  'EDGE_ML_API_KEY',
  defaultValue: '',
);

class EdgeMLSettings extends StatefulWidget {
  final VoidCallback onStop;
  final Future<void> Function(String url, String apiKey, String datasetName)
      onOnlineStart;
  final Future<void> Function(String datasetName) onCsvStart;

  const EdgeMLSettings({
    super.key,
    required this.onStop,
    required this.onOnlineStart,
    required this.onCsvStart,
  });

  @override
  State<EdgeMLSettings> createState() => _EdgeMLSettingsState();
}

class _EdgeMLSettingsState extends State<EdgeMLSettings> {
  final TextEditingController _urlController =
      TextEditingController(text: edgeMlUrl);
  final TextEditingController _apiKeyController =
      TextEditingController(text: edgeMlApiKey);
  final TextEditingController _datasetNameController =
      TextEditingController(text: "Wearable-Example");

  bool _tracking = false;
  bool _starting = false;

  void _handleOnlineButton() async {
    if (_tracking) {
      widget.onStop();
      setState(() {
        _tracking = false;
      });
    } else {
      setState(() {
        _starting = true;
      });
      await widget.onOnlineStart(
        _urlController.text,
        _apiKeyController.text,
        _datasetNameController.text,
      );
      setState(() {
        _starting = false;
        _tracking = true;
      });
    }
  }

  void _handleCsvButton() async {
    if (_tracking) {
      widget.onStop();
      setState(() {
        _tracking = false;
      });
    } else {
      setState(() {
        _starting = true;
      });
      await widget.onCsvStart(_datasetNameController.text);
      setState(() {
        _starting = false;
        _tracking = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 305,
      width: double.maxFinite,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Online'),
                Tab(text: 'CSV'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OnlineSettingsWidget(
                    urlController: _urlController,
                    apiKeyController: _apiKeyController,
                    datasetNameController: _datasetNameController,
                    tracking: _tracking,
                    starting: _starting,
                    onToggleTracking: _handleOnlineButton,
                  ),
                  _CsvSettingsWidget(
                    datasetNameController: _datasetNameController,
                    tracking: _tracking,
                    starting: _starting,
                    onToggleTracking: _handleCsvButton,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineSettingsWidget extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController apiKeyController;
  final TextEditingController datasetNameController;
  final bool tracking;
  final bool starting;
  final VoidCallback onToggleTracking;

  const _OnlineSettingsWidget({
    required this.urlController,
    required this.apiKeyController,
    required this.datasetNameController,
    required this.tracking,
    required this.starting,
    required this.onToggleTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
            ),
            enabled: !tracking && !starting,
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              border: OutlineInputBorder(),
            ),
            enabled: !tracking && !starting,
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: datasetNameController,
            decoration: const InputDecoration(
              labelText: 'Dataset Name',
              border: OutlineInputBorder(),
            ),
            enabled: !tracking && !starting,
          ),
          const SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: starting ? null : onToggleTracking,
            child: Text(
              tracking
                  ? 'Stop'
                  : starting
                      ? 'Starting...'
                      : 'Start',
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvSettingsWidget extends StatelessWidget {
  final TextEditingController datasetNameController;
  final bool tracking;
  final bool starting;
  final VoidCallback onToggleTracking;

  const _CsvSettingsWidget({
    required this.datasetNameController,
    required this.tracking,
    required this.starting,
    required this.onToggleTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: datasetNameController,
            decoration: const InputDecoration(
              labelText: 'Dataset Name',
              border: OutlineInputBorder(),
            ),
            enabled: !tracking && !starting,
          ),
          const SizedBox(height: 60.0),
          ElevatedButton(
            onPressed: starting ? null : onToggleTracking,
            child: Text(
              tracking
                  ? 'Stop'
                  : starting
                      ? 'Starting...'
                      : 'Start',
            ),
          ),
        ],
      ),
    );
  }
}
