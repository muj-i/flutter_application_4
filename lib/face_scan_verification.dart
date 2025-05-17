import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:dashed_circular_progress_bar/dashed_circular_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_4/kyc_facescan_controller.dart';
import 'package:get/get.dart';

class FaceScanVerification extends GetView<KycFaceScanVerificationController> {
  const FaceScanVerification({super.key});

  @override
  Widget build(BuildContext context) {
    Get.lazyPut<KycFaceScanVerificationController>(
        () => KycFaceScanVerificationController(),
        fenix: true);

    final ValueNotifier<double> valueNotifier = ValueNotifier(0);

    // controller.cleanData();
    // if (controller.cameraController.value.isInitialized) {
    //   controller.cameraController.dispose();
    // }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        controller.cameraController.dispose();
        bool value = await Get.delete<KycFaceScanVerificationController>();
        if (value) {
          navigator.pop();
        }
      },
      child: Obx(
        () => Scaffold(
          appBar: AppBar(
            title: const Text('StringConfig.walletRegistration'),
            // onBackTap: () async {
            //   controller.cameraController.dispose();
            //   await Get.delete<KycFaceScanVerificationController>();
            // },
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: ListView(
              shrinkWrap: true,
              children: [
                const SizedBox(
                  height: (50.0),
                ),
                const Center(
                    child: Text('StringConfig.yourPhoto',
                        style: TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.normal,
                            fontSize: 18),
                        textAlign: TextAlign.center)),

                const SizedBox(
                  height: (5.0),
                ),
                Center(
                    child: Text(
                  controller.message.value,
                  style: const TextStyle(
                      // color: 'ColorConfig.textColorSecondary',
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  textAlign: TextAlign.center,
                )),

                // Photo Capture Timer
                controller.startPhotoCaptureTimer.value
                    ? Column(
                        children: [
                          const SizedBox(
                            height: (5.0),
                          ),
                          TweenAnimationBuilder(
                            tween: Tween(
                                begin: Duration(
                                    seconds:
                                        controller.takePhotoInSeconds.value),
                                end: Duration.zero),
                            duration: Duration(
                                seconds: controller.takePhotoInSeconds.value),
                            builder: (context, value, child) {
                              final seconds = value.inSeconds + 1;
                              // final seconds = value.inSeconds % 60;

                              return RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: <TextSpan>[
                                    TextSpan(
                                        text:
                                            "${seconds.toString().padLeft(2, '0')} ",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.red,
                                            fontWeight: FontWeight.w400)),
                                    const TextSpan(
                                        text: "{StringConfig.secondText} ",
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black,
                                            fontWeight: FontWeight.w400)),
                                  ],
                                ),
                              );
                            },
                            onEnd: () {
                              controller.startPhotoCaptureTimer.value = false;
                            },
                          ),
                        ],
                      )
                    : const SizedBox(),

                /// The Scanner
                const SizedBox(
                  height: (70.0),
                ),
                controller.selfieImagePath.value.isEmpty
                    ? DashedCircularProgressBar.square(
                        valueNotifier: valueNotifier,
                        dimensions: 258,
                        progress: controller.progressBarValue.value,
                        maxProgress: 100,
                        startAngle: -90,
                        foregroundColor: Colors.blueAccent,
                        backgroundColor: Colors.transparent,
                        foregroundStrokeWidth: 19,
                        backgroundStrokeWidth: 19,
                        animation: true,
                        seekSize: 12,
                        seekColor: Colors.transparent,
                        child: controller.isCameraReady.value == true
                            ? customCameraPreview(controller.cameraController)
                            : controller.selfieImagePath.value.isEmpty
                                ? InkWell(
                                    onTap: () {
                                      controller.onReady();
                                    },
                                    child: SizedBox(
                                      width: (100.0),
                                      height: (100.0),
                                      // margin: const EdgeInsets.all(40),
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(50)),
                                        child: Image.asset(
                                          ' AssetConfig.userSelfieIconPng',
                                          width: (100.0),
                                          height: (100.0),
                                        ),
                                      ),
                                    ),
                                  )
                                : const SizedBox())
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: Center(
                          child: Container(
                            width: 255.0,
                            height: 290.0,
                            padding: const EdgeInsets.all(30.0),
                            child: AspectRatio(
                              aspectRatio:
                                  controller.cameraController.value.aspectRatio,
                              child: ClipRRect(
                                clipBehavior: Clip.hardEdge,
                                borderRadius: BorderRadius.circular(4.0),
                                child: Image.file(
                                  File(controller.selfieImagePath.value),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                /// Completion Percentage
                const SizedBox(
                  height: (18.0),
                ),
                controller.selfieImagePath.value.isEmpty
                    ? Center(
                        child: ValueListenableBuilder(
                            valueListenable: valueNotifier,
                            builder: (_, double value, __) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                        '${controller.progressBarValue.value.toInt()}%',
                                        style: const TextStyle(
                                            color: Colors.blueGrey,
                                            fontWeight: FontWeight.w300,
                                            fontSize: 14)),

                                    // const Text('সঠিক', style: TextStyle(color: ColorConfig.textColorSecondary, fontWeight: FontWeight.w400, fontSize: 12)),
                                  ],
                                )),
                      )
                    : const SizedBox(),

                /*
              Center(
                child: ValueListenableBuilder(
                    valueListenable: _valueNotifier,
                    builder: (_, double value, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w300,
                              fontSize: 60
                          ),
                        ),
                        const Text(
                          'Accuracy',
                          style: TextStyle(
                              color: Color(0xffeeeeee),
                              fontWeight: FontWeight.w400,
                              fontSize: 16
                          ),
                        ),
                      ],
                    )
                ),
              ),
      */

                const SizedBox(
                  height: (15.0),
                ),
                controller.selfieImagePath.value.isEmpty
                    ? Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0.0, vertical: 20.0),
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          border: Border.all(color: Colors.grey),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  // controller.showHowToTakeSelfieScan(context);
                                },
                                child: const Row(
                                  children: [
                                    SizedBox(width: (5.0)),
                                    // SvgPicture.asset(
                                    //   AssetConfig.cautionIconSvg,
                                    //   height:
                                    //       (25.0),
                                    //   width: (25.0),
                                    // ),
                                    SizedBox(width: (5.0)),
                                    Expanded(
                                      child: Text(
                                        'StringConfig.howtoScanFace',
                                        // style: ,
                                        textAlign: TextAlign.start,
                                        //overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(),
                const SizedBox(
                  height: (150.0),
                ),
              ],
            ),
          ),
          // bottomNavigationBar: SafeArea(
          //   child: Padding(
          //     // height: (130),
          //     padding:
          //         const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          //     child: Column(
          //       mainAxisSize: MainAxisSize.min,
          //       mainAxisAlignment: MainAxisAlignment.end,
          //       children: [
          //         controller.selfieImagePath.value.isNotEmpty
          //             ? PrimaryButton(
          //                 isPrimaryButton: false,
          //                 btnText: StringConfig.captureImageAgain,
          //                 onPressed: () async {
          //                   await Get.delete<KycFaceScanVerificationController>();
          //                   // Get.lazyPut<KycFaceScanVerificationController>(() => KycFaceScanVerificationController(), fenix: true);
          //                   goRouterPushReplacement(context,
          //                       RouterPath.faceScanVerificationPath);
          //                 },
          //               )
          //             : const SizedBox(),
          //         SizedBox(
          //           height: (8.0),
          //         ),

          //       ],
          //     ),
          //   ),
          // ),
        ),
      ),
    );
  }

  Widget customCameraPreview(CameraController controller) {
    return Center(
      child: Container(
        width: 240.0,
        height: 240.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(500.0),
        ),
        clipBehavior: Clip.hardEdge,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
