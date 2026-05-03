import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../widgets/ai_translated_text.dart';

class HRFaceScanner extends StatefulWidget {
  final Function(XFile photo) onFaceVerified;

  const HRFaceScanner({super.key, required this.onFaceVerified});

  @override
  State<HRFaceScanner> createState() => _HRFaceScannerState();
}

class _HRFaceScannerState extends State<HRFaceScanner> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isBusy = false;
  String _status = 'Posicione o seu rosto no círculo';
  bool _faceDetected = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    
    _controller = CameraController(front, ResolutionPreset.medium, enableAudio: false);
    await _controller!.initialize();
    
    _faceDetector = FaceDetector(options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ));

    if (mounted) setState(() {});
    
    _startDetection();
  }

  void _startDetection() {
    _controller?.startImageStream((image) async {
       if (_isBusy) return;
       _isBusy = true;
       
       try {
         final faces = await _faceDetector?.processImage(InputImage.fromBytes(
            bytes: image.planes[0].bytes,
            metadata: InputImageMetadata(
              size: Size(image.width.toDouble(), image.height.toDouble()),
              rotation: InputImageRotation.rotation270deg, // Adjust based on platform
              format: InputImageFormat.nv21,
              bytesPerRow: image.planes[0].bytesPerRow,
            ),
         ));

         if (faces != null && faces.isNotEmpty) {
           final face = faces.first;
           // Check if face is centered
           if (mounted) {
             setState(() {
               _faceDetected = true;
               _status = 'Rosto detetado! Mantenha a posição...';
             });
           }
           
           // In a real app, we'd wait 2 seconds or verify landmarks
           await Future.delayed(const Duration(seconds: 1));
           if (mounted && _faceDetected) {
             _controller?.stopImageStream();
             final photo = await _controller?.takePicture();
             if (photo != null) widget.onFaceVerified(photo);
           }
         } else {
            if (mounted) {
             setState(() {
               _faceDetected = false;
               _status = 'Aguardando deteção facial...';
             });
           }
         }
       } catch (e) {
         debugPrint('Face detection error: $e');
       } finally {
         _isBusy = false;
       }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const AiTranslatedText('Verificação Facial'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _faceDetected ? Colors.greenAccent : const Color(0xFF00D1FF),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_faceDetected ? Colors.greenAccent : const Color(0xFF00D1FF)).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: AiTranslatedText(
                  _status,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
