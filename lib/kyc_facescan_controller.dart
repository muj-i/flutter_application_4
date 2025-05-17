import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';




class KycFaceScanVerificationController extends GetxController {
  BuildContext? context;

  ///Token & Balance
  var bearerToken = "";
  var basicToken = "";

  /// Face Scan Verification
  // final bool _isCameraBusy = false;
  late List<CameraDescription> cameras;
  late CameraController cameraController;
  RxBool isCameraReady = false.obs;

  // RxString selfieImagePath = "/data/user/0/xyz.sheba.managerapp/cache/image_cropper_1701025731200.jpg".obs;
  RxString selfieImagePath = "".obs;
  int _cameraIndex = -1;
  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  final options = FaceDetectorOptions(
    enableClassification: true,
    enableTracking: true,
    enableLandmarks: true,
    minFaceSize: 0.1,
    performanceMode: FaceDetectorMode.accurate, // Increase performance for faster detection
  );
  FaceDetector? faceDetector;

  RxString message = "সেলফি তোলার সময় আপনার মোবাইল দূরত্বে রাখুন এবং পরিষ্কার আলোতে ছবি তুলুন".obs;
  var isSmiling = false;
  var isLeftEyeOpen = false;
  var isRightEyeOpen = false;
  var isLeftMove = false;
  var isRightMove = false;
  var isUpMove = false;
  var isDownMove = false;
  var isFaceDetected = false;
  var isCameraShow = true;
  var isTakePhoto = false;
  Uint8List imageData = Uint8List(0);


  var selfieImage = "".obs;
  var progressBarValue = 0.0.obs;
  var countEyeBlink = 0;
  var isEyeOpenClose = true;

  var takePhotoInSeconds = 3.obs;
  var startPhotoCaptureTimer = false.obs;



  @override
  void onReady() {
    faceDetector = FaceDetector(options: options);
    startCamera();
    super.onReady();
  }

  void startCamera() async {
    cleanData();
    CameraLensDirection initialCameraLensDirection = CameraLensDirection.front;
    try {
      cameras = await availableCameras();
      for (var i = 0; i < cameras.length; i++) {
        if (cameras[i].lensDirection == initialCameraLensDirection) {
          _cameraIndex = i;
          break;
        }
      }
      cameraController = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await cameraController.initialize().then((value) async {
        isCameraReady.value = true;
        if (isCameraReady.value) {
          await cameraController.startImageStream((image) async {
            await _liveNessFace(image);
          });
        }
      });
    } catch (e) {
      print(e);
      // await CrushEvents.kycCrashLogTrigger(e);
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = cameras[_cameraIndex];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[cameraController.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      // print('rotationCompensation: $rotationCompensation');
    }
    if (rotation == null) return null;
    // print('final rotation: $rotation');

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  _liveNessFace(CameraImage image) async {
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      return;
    }
    await faceDetector?.processImage(inputImage).then((List<Face> faces) async {
      if (faces.length == 1) {
        var face = faces[0];
        double leftEyeOpenProbability = face.leftEyeOpenProbability ?? 0;
        double rightEyeOpenProbability = face.rightEyeOpenProbability ?? 0;
        double smilingProbability = face.smilingProbability ?? 0;
        final leftEar = face.landmarks[FaceLandmarkType.leftEar];
        final rightEar = face.landmarks[FaceLandmarkType.rightEar];
        if (countEyeBlink < 2) {
          message.value = "কয়েকবার চোখের পলক ফেলুন";

          if ((leftEyeOpenProbability < 0.1 && rightEyeOpenProbability < 0.1) &&
              isEyeOpenClose) {
            isEyeOpenClose = false;
          }

          if ((leftEyeOpenProbability > 0.5 && rightEyeOpenProbability > 0.5) &&
              !isEyeOpenClose) {
            isEyeOpenClose = true;
            countEyeBlink++;
            progressBarValue.value = 50;
            message.value = "হাসুন";
            // vibrate();
          }
        } else if (smilingProbability > 0.5 && !isSmiling) {
          isSmiling = true;
          progressBarValue.value = 100;
          message.value = "প্রস্তুত";
          isTakePhoto = true;
          // vibrate();
        } else if (isSmiling && countEyeBlink >= 2) {
          if (isTakePhoto) {
            message.value =
                "আপনার চেহারা ছবির ফ্রেমের মধ্যে এনে স্থির রাখুন ছবি তোলা হচ্ছে";
            isTakePhoto = false;
            startTimer();
          }
        }
      } else if (faces.isEmpty && (countEyeBlink < 2)) {
        countEyeBlink = 0;
        isSmiling = false;
        isLeftEyeOpen = false;
        isRightEyeOpen = false;
        isLeftMove = false;
        isRightMove = false;
        isUpMove = false;
        isDownMove = false;
        isFaceDetected = false;
        isTakePhoto = false;
        message.value = "আপনার মুখমণ্ডল ছবির ফ্রেমের মধ্যে আনুন";
        progressBarValue.value = 0.0;
      } else {
        if (countEyeBlink < 2) {
          countEyeBlink = 0;
          isSmiling = false;
          isLeftEyeOpen = false;
          isRightEyeOpen = false;
          isLeftMove = false;
          isRightMove = false;
          isUpMove = false;
          isDownMove = false;
          isFaceDetected = false;
          isTakePhoto = false;
          message.value = "ফ্রেমের মধ্যে একাধিক মুখমন্ডল অনুমোদিত নয়";
          progressBarValue.value = 0.0;
        }
      }
    }).catchError((e) async {
      print("Error during face detection: $e");
      // await CrushEvents.kycCrashLogTrigger(e);
    });
  }

  void startTimer() async {
    startPhotoCaptureTimer.value = true;
    await takePhoto();
  }

  takePhoto({bool isFromEyeBlink = false, bool isFromSmile = false}) async {
    Future.delayed(Duration(seconds: takePhotoInSeconds.value), () async {
    try {
      if (cameraController.value.isStreamingImages) {
        await cameraController.stopImageStream();
      }
      if (!cameraController.value.isTakingPicture) {
        final XFile photo = await cameraController.takePicture();
        if (kDebugMode) {
          print('Photo taken at: ${photo.path}');
        }
        isCameraReady.value = false;
        selfieImagePath.value = photo.path;

        // message.value = "ফেসভেরিফিকেশন সফলভাবে সম্পন্ন হয়েছে";
        message.value = "নিশ্চিত করুন";
        // if (cameraController.value.isInitialized) {
        //   try{
        //     await cameraController.dispose();
        //   }catch(e){
        //     CommonToast.showErrorToast('Error taking photo: $e');
        //   }
        //   // cameraController.dispose();
        // }
      } else {
        print('Camera is currently taking a picture, please wait...');
      }
    } catch (e) {
      print('Error taking photo: $e');
      // await CrushEvents.kycCrashLogTrigger(e);
    }
    });
  }

//   void startCamera() async {
//   cleanData();
//   CameraLensDirection initialCameraLensDirection = CameraLensDirection.front;

//   try {
//     cameras = await availableCameras();
//     for (var i = 0; i < cameras.length; i++) {
//       if (cameras[i].lensDirection == initialCameraLensDirection) {
//         _cameraIndex = i;
//         break;
//       }
//     }

//     cameraController = CameraController(
//       cameras[_cameraIndex],
//       ResolutionPreset.high,
//       enableAudio: false,
//       imageFormatGroup: Platform.isAndroid
//           ? ImageFormatGroup.nv21
//           : ImageFormatGroup.bgra8888,
//     );

//     await cameraController.initialize();
//     isCameraReady.value = true;
//     cameraController.startImageStream((image) async {
//       await _liveNessFace(image);
//     });
//   } catch (e) {
//     print("Error starting camera: $e");
//   }
// }

// InputImage? _inputImageFromCameraImage(CameraImage image) {
//   final camera = cameras[_cameraIndex];
//   final sensorOrientation = camera.sensorOrientation;
//   InputImageRotation? rotation;

//   if (Platform.isIOS) {
//     rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
//   } else if (Platform.isAndroid) {
//     var rotationCompensation = _orientations[cameraController.value.deviceOrientation];
//     if (rotationCompensation == null) return null;

//     if (camera.lensDirection == CameraLensDirection.front) {
//       rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
//     } else {
//       rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
//     }
//     rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
//   }

//   if (rotation == null) return null;

//   final format = InputImageFormatValue.fromRawValue(image.format.raw);

//   if (format == null ||
//       (Platform.isAndroid && format != InputImageFormat.nv21) ||
//       (Platform.isIOS && format != InputImageFormat.bgra8888)) {
//     return null;
//   }

//   if (image.planes.length != 1) return null;

//   final plane = image.planes.first;

//   return InputImage.fromBytes(
//     bytes: plane.bytes,
//     metadata: InputImageMetadata(
//       size: Size(image.width.toDouble(), image.height.toDouble()),
//       rotation: rotation,
//       format: format,
//       bytesPerRow: plane.bytesPerRow,
//     ),
//   );
// }

// _liveNessFace(CameraImage image) async {
//   final inputImage = _inputImageFromCameraImage(image);
//   if (inputImage == null) {
//     return;
//   }

//   try {
//     await faceDetector?.processImage(inputImage).then((List<Face> faces) async {
//       if (faces.length == 1) {
//         var face = faces[0];

//         double leftEyeOpenProbability = face.leftEyeOpenProbability ?? 0;
//         double rightEyeOpenProbability = face.rightEyeOpenProbability ?? 0;
//         double smilingProbability = face.smilingProbability ?? 0;

//         if (countEyeBlink < 2) {
//           progressBarValue.value = 33.33;
//           message.value = "কয়েকবার চোখের পলক ফেলুন";

//           if ((leftEyeOpenProbability < 0.1 && rightEyeOpenProbability < 0.1) && isEyeOpenClose) {
//             isEyeOpenClose = false;
//           }

//           if ((leftEyeOpenProbability > 0.5 && rightEyeOpenProbability > 0.5) && !isEyeOpenClose) {
//             isEyeOpenClose = true;
//             countEyeBlink++;
//             progressBarValue.value = 66.66;
//             message.value = "হাসুন";
//             vibrate();
//           }
//         } else if (smilingProbability > 0.5 && !isSmiling) {
//           isSmiling = true;
//           progressBarValue.value = 100;
//           message.value = "প্রস্তুত";
//           isTakePhoto = true;
//           vibrate();
//         } else if (isSmiling && countEyeBlink >= 2) {
//           if (isTakePhoto) {
//             message.value =
//                 "আপনার চেহারা ছবির ফ্রেমের মধ্যে এনে স্থির রাখুন ছবি তোলা হচ্ছে";
//             isTakePhoto = false;
//             startTimer();
//           }
//         }
//       } else {
//         resetDetectionState();
//         message.value = "একটি মুখ চিনতে পায়নি";
//         progressBarValue.value = 0.0;
//       }
//     }).catchError((e) {
//       errorLog("Error during face detection: $e");
//     });
//   } catch (e) {
//     errorLog("Error processing face detection: $e");
//   }
// }

// resetDetectionState() {
//   countEyeBlink = 0;
//   isSmiling = false;
//   isEyeOpenClose = true;
//   isTakePhoto = false;
//   progressBarValue.value = 0.0;
// }

// void startTimer() async {
//   startPhotoCaptureTimer.value = true;
//   await takePhoto();
// }

// takePhoto({bool isFromEyeBlink = false, bool isFromSmile = false}) async {
//   try {
//     Future.delayed(Duration(seconds: takePhotoInSeconds.value), () async {
//       if (cameraController.value.isStreamingImages) {
//         await cameraController.stopImageStream();
//       }

//       if (!cameraController.value.isTakingPicture) {
//         final XFile photo = await cameraController.takePicture();
//         isCameraReady.value = false;
//         selfieImagePath.value = photo.path;

//         message.value = "নিশ্চিত করুন";
//       }
//     });
//   } catch (e) {
//     CommonToast.showErrorToast('Error taking photo: $e');
//   }
// }


  /// TODO: To Match Nid Face and Camera Face

  // Future<num> matchFaces() async {
  //   // Load an image file ('tolu.jpg') from the 'images' directory
  //   ByteData byteData = await rootBundle.load('images/tolu.jpg');
  //   Uint8List bytes = byteData.buffer.asUint8List();
  //   var image2 = base64.encode(bytes);
  //
  //   // Use the ImagePicker to capture an image from the camera
  //   final image = await ImagePicker().pickImage(
  //     source: ImageSource.camera,
  //     preferredCameraDevice: CameraDevice.rear,
  //   );
  //
  //   // If no image is selected, return 0
  //   if (image == null) return 0;
  //
  //   // Read the selected image file into bytes and convert it to base64
  //   final imageBytes = await image.readAsBytes();
  //   String base64String = base64Encode(imageBytes);
  //
  //   // Create two instances of MatchFacesImage for comparison
  //   var firstImage = Regula.MatchFacesImage();
  //   firstImage.imageType = Regula.ImageType.PRINTED;
  //   firstImage.bitmap = base64String;
  //
  //   var secondImage = Regula.MatchFacesImage();
  //   secondImage.imageType = Regula.ImageType.PRINTED;
  //   secondImage.bitmap = image2;
  //
  //   // Create a MatchFacesRequest with the two images for comparison
  //   var request = Regula.MatchFacesRequest();
  //   request.images = [firstImage, secondImage];
  //   num similarity = 0;
  //
  //   // Use Regula.FaceSDK to match faces and calculate similarity
  //   await Regula.FaceSDK.matchFaces(jsonEncode(request)).then((value) async {
  //     var response = Regula.MatchFacesResponse.fromJson(json.decode(value));
  //
  //     // Use Regula.FaceSDK to split the results based on a similarity threshold
  //     await Regula.FaceSDK.matchFacesSimilarityThresholdSplit(
  //         jsonEncode(response!.results), 0.5).then((str) async {
  //       var split = Regula.MatchFacesSimilarityThresholdSplit.fromJson(
  //           json.decode(str));
  //
  //       // Calculate the similarity percentage and assign it to the 'similarity' variable
  //       similarity = split!.matchedFaces.length > 0
  //           ? ((split.matchedFaces[0]!.similarity! * 100))
  //           : 0;
  //       return similarity;
  //     });
  //   });
  //
  //   // Return the calculated similarity value
  //   return similarity;
  // }

  cleanData() {
    countEyeBlink = 0;
    isSmiling = false;
    isLeftEyeOpen = false;
    isRightEyeOpen = false;
    isLeftMove = false;
    isRightMove = false;
    isUpMove = false;
    isDownMove = false;
    isFaceDetected = false;
    isTakePhoto = false;
    message.value =
        "সেলফি তোলার সময় আপনার মোবাইল/ক্যামেরা ২ ফুট দূরত্বে রাখুন এবং পরিষ্কার আলোতে ছবি তুলুন";
    progressBarValue.value = 0.0;
    selfieImagePath.value = "";
    selfieImage.value = "";
  }


  void disposeCamera() async {
    // ignore: unnecessary_null_comparison
    if (cameraController.value != null) {
      await cameraController.dispose();
    }

    @override
    void onClose() {
      if (cameraController.value.isInitialized) {
        cameraController.dispose();
      }
      super.onClose();
    }

    @override
    void dispose() {
      if (cameraController.value.isInitialized) {
        cameraController.dispose();
      }
      super.dispose();
    }
  }
}


// _liveNessFace(CameraImage image) async {
//     final inputImage = _inputImageFromCameraImage(image);
//     if (inputImage == null) {
//       return;
//     }
//     await faceDetector?.processImage(inputImage).then((List<Face> faces) async {
//       if (faces.length == 1) {
//         var face = faces[0];

//         double leftEyeOpenProbability = face.leftEyeOpenProbability ?? 0;
//         double rightEyeOpenProbability = face.rightEyeOpenProbability ?? 0;
//         double headEulerAngleY = face.headEulerAngleY ?? 0;

//         if (countEyeBlink < 2) {
//           message.value = "কয়েকবার চোখের পলক ফেলুন";

//           if ((leftEyeOpenProbability < 0.1 && rightEyeOpenProbability < 0.1) &&
//               isEyeOpenClose) {
//             isEyeOpenClose = false;
//           }

//           if ((leftEyeOpenProbability > 0.5 && rightEyeOpenProbability > 0.5) &&
//               !isEyeOpenClose) {
//             isEyeOpenClose = true;
//             countEyeBlink++;
//             progressBarValue.value = 50;
//             message.value = "বাম দিকে ঘুরুন";
//             vibrate();
//           }
//         } else if (headEulerAngleY > 8 && countEyeBlink >= 2 && !isLeftMove) {
//           //  user physically turns head left
//           isLeftMove = true;
//           progressBarValue.value = 75;
//           message.value = "ডান দিকে ঘুরুন";
//           vibrate();
//         } else if (headEulerAngleY < -8 &&
//             countEyeBlink >= 2 &&
//             isLeftMove &&
//             !isRightMove) {
//           //  user physically turns head right
//           isRightMove = true;
//           progressBarValue.value = 100;
//           message.value = "প্রস্তুত";
//           vibrate();
//           isTakePhoto = true;
//         } else if (isLeftMove && isRightMove && countEyeBlink >= 2) {
//           if (isFaceStable(face)) {
//             // function to check stability
//             if (isTakePhoto) {
//               message.value =
//                   "আপনার চেহারা ছবির ফ্রেমের মধ্যে এনে স্থির রাখুন ছবি তোলা হচ্ছে";
//               isTakePhoto = false;
//               startTimer();
//               vibrate();
//             }
//           } else {
//             message.value =
//                 "আপনার মুখমণ্ডল স্থির রাখুন"; // prompt user to hold steady
//           }
//         }
//       } else if (faces.isEmpty && (countEyeBlink < 2)) {
//         countEyeBlink = 0;
//         isSmiling = false;
//         isLeftEyeOpen = false;
//         isRightEyeOpen = false;
//         isLeftMove = false;
//         isRightMove = false;
//         isUpMove = false;
//         isDownMove = false;
//         isFaceDetected = false;
//         isTakePhoto = false;
//         message.value = "আপনার মুখমণ্ডল ছবির ফ্রেমের মধ্যে আনুন";
//         progressBarValue.value = 0.0;
//       } else {
//         if (countEyeBlink < 2) {
//           countEyeBlink = 0;
//           isSmiling = false;
//           isLeftEyeOpen = false;
//           isRightEyeOpen = false;
//           isLeftMove = false;
//           isRightMove = false;
//           isUpMove = false;
//           isDownMove = false;
//           isFaceDetected = false;
//           isTakePhoto = false;
//           message.value = "ফ্রেমের মধ্যে একাধিক মুখমন্ডল অনুমোদিত নয়";
//           progressBarValue.value = 0.0;
//         }
//       }
//     }).catchError((e) {
//       errorLog("Error during face detection: $e");
//     });
//   }

  // bool isFaceStable(Face face) {
  //   double headEulerAngleY = face.headEulerAngleY ?? 0;
  //   double headEulerAngleZ = face.headEulerAngleZ ?? 0;

  //   // Check if head rotation values are within a stable range (e.g., ±5 degrees)
  //   return headEulerAngleY.abs() < 5 && headEulerAngleZ.abs() < 5;
  // }
