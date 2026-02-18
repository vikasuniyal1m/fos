import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LiveStreamViewerScreen extends StatelessWidget {
  final Map<String, dynamic> streamDetails;

  const LiveStreamViewerScreen({Key? key, required this.streamDetails}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(streamDetails['title'] ?? 'Live Stream'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Now viewing: ${streamDetails['title']}'),
            Text('Description: ${streamDetails['description'] ?? 'No description'}'),
            Text('Stream ID: ${streamDetails['stream_id']}'),
            // TODO: Implement actual video player here
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Get.back();
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
