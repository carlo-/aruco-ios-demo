# Aruco iOS demo
![Platforms](https://img.shields.io/badge/platform-iOS-lightgrey.svg) ![Swift Version](https://img.shields.io/badge/swift-4.1-orange.svg) ![License](https://img.shields.io/badge/license-MIT-blue.svg)

Tiny iOS app integrating the [Aruco](http://www.uco.es/investiga/grupos/ava/node/26) library and the [OpenCV camera calibration tool](https://docs.opencv.org/2.4/doc/tutorials/calib3d/camera_calibration/camera_calibration.html), including a wrapper in Objective-C++ that allows access to the APIs from Swift.

<p align="center">
  <img alt="App screenshot" src="http://public-carlorapisarda.s3.wasabisys.com/aruco-ios-demo-screenshot.png" width="auto" height="350">
</p>

---
## Setup

In order to setup the project, follow these steps:

* Download the Aruco library (v3.0.X) from [here](https://sourceforge.net/projects/aruco/files/?source=navbar).
* Copy the folders `src` and `3rdparty` into the `Aruco` folder of the project.
* From the project root, run `chmod -R 755 ./Aruco/3rdparty/eigen3/Eigen`.
* Download OpenCV 3.4.X (iOS pack) from [here](https://opencv.org/releases.html).
* Make a new folder `Frameworks` in the project root and copy `opencv2.framework` into it.
* Install the remaining dependencies by running `pod install`.

If everything went well, your project should now look like this (omitting less relevant files):

```
.
├── Aruco
│   ├── 3rdparty/
│   ├── ArucoWrapper.h
│   ├── ArucoWrapper.mm
│   └── src/
├── ArucoDemo/
├── ArucoDemo.xcodeproj
├── ArucoDemo.xcworkspace
├── Frameworks
│   └── opencv2.framework
├── Podfile
├── Podfile.lock
└── Pods/
```

## Requirements

* Xcode 9.0
* iOS 10.0 or above

## Contributing

Contributions of any kind are more than welcome! Make a pull request or open an issue.

## License

This project is released under the MIT license. See `LICENSE` for more information.
