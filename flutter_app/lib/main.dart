import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(
    const MaterialApp(
      home: FaceRecognitionHome(),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class FaceRecognitionHome extends StatefulWidget {
  const FaceRecognitionHome({super.key});

  @override
  State<FaceRecognitionHome> createState() => _FaceRecognitionHomeState();
}

class _FaceRecognitionHomeState extends State<FaceRecognitionHome> {
  static const String apiUrl =
      "https://asia-guests-arms-violin.trycloudflare.com/predict";

  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  List<dynamic> _detections = [];
  String _status = "Tap Scan Face to take a photo";
  bool _isLoading = false;

  Future<void> _scanFace() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _imageFile = File(picked.path);
        _detections = [];
        _isLoading = true;
        _status = "Sending photo to model...";
      });

      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', _imageFile!.path),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> list = (decoded['detections'] as List<dynamic>?) ?? [];

        setState(() {
          _detections = list;
         if (list.isEmpty) {
  _status = "Wrong person detected";
} else {
            _status = list
                .map((item) {
                  final label = item['label'] ?? 'Unknown';
                  final conf = (((item['confidence'] ?? 0) as num) * 100)
                      .toStringAsFixed(0);
                  return "$label ($conf%)";
                })
                .join(" • ");
          }
        });
      } else {
        setState(() {
          _status = "Server error (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _status =
            "Failed to reach server. Check internet & keep Colab tunnel running.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Facial Recognition App"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black26),
              ),
              clipBehavior: Clip.antiAlias,
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.face, size: 84, color: Colors.grey),
                    ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            if (_detections.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "Detections: ${_detections.length}",
                style: const TextStyle(color: Colors.black54),
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _scanFace,
                icon: const Icon(Icons.camera_alt),
                label: const Text(
                  "Scan Face",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}