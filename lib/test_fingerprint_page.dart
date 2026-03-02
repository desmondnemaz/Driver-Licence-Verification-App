import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'core/services/fingerprint_service.dart';

class FingerprintTestPage extends StatefulWidget {
  const FingerprintTestPage({super.key});

  @override
  State<FingerprintTestPage> createState() => _FingerprintTestPageState();
}

class _FingerprintTestPageState extends State<FingerprintTestPage> {
  final FingerprintService _service = FingerprintService();
  
  String _status = "Disconnected";
  Uint8List? _lastImage;
  List<String> _testDatabase = [];
  bool _isBusy = false;

  void _updateStatus(String msg) => setState(() => _status = msg);

  // Test 1: Initialization
  Future<void> testInit() async {
    _updateStatus("Initializing...");
    bool ok = await _service.initializeScanner();
    _updateStatus(ok ? "Scanner Ready" : "Init Failed - Check USB/Power");
  }

  // Test 2: Enrollment (Capture)
  Future<void> testCapture() async {
    setState(() => _isBusy = true);
    _updateStatus("Place finger on sensor...");
    
    var result = await _service.enrollFinger();
    
    if (result != null) {
      setState(() {
        _lastImage = result['image'];
        _testDatabase.add(result['template']);
        _status = "Captured! Saved to Test DB.";
      });
    } else {
      _updateStatus("Capture Failed - No Finger Detected");
    }
    setState(() => _isBusy = false);
  }

  // Test 3: Matching
  Future<void> testMatch() async {
    if (_testDatabase.isEmpty) {
      _updateStatus("Enroll a finger first!");
      return;
    }
    
    setState(() => _isBusy = true);
    _updateStatus("Matching... Place finger.");
    
    int index = await _service.searchFinger(_testDatabase);
    
    _updateStatus(index != -1 ? "MATCH FOUND (Index $index)" : "NO MATCH FOUND");
    setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hardware Test Mode")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Fingerprint Preview Box
          Center(
            child: Container(
              width: 160, height: 200,
              decoration: BoxDecoration(border: Border.all(color: Colors.blue, width: 2), color: Colors.black),
              child: _lastImage != null 
                  ? Image.memory(_lastImage!, fit: BoxFit.contain) 
                  : const Icon(Icons.fingerprint, size: 80, color: Colors.white10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          if (_isBusy) const LinearProgressIndicator(),
          const Spacer(),
          // Test Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(onPressed: testInit, child: const Text("1. Init")),
              ElevatedButton(onPressed: testCapture, child: const Text("2. Capture")),
              ElevatedButton(onPressed: testMatch, child: const Text("3. Match")),
            ],
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}