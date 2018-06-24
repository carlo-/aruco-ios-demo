//
//  Calibrator.m
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 23/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import "Calibrator.h"
#import "Utilities.h"

#include <opencv2/core/core.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgcodecs/ios.h>
#include <cctype>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <iostream>
#include <fstream>

using namespace cv;
using namespace std;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// code within this segment from: https://docs.opencv.org/2.4/doc/tutorials/calib3d/camera_calibration/camera_calibration.html

enum { DETECTION = 0, CAPTURING = 1, CALIBRATED = 2 };
enum Pattern { CHESSBOARD, CIRCLES_GRID, ASYMMETRIC_CIRCLES_GRID };

static double computeReprojectionErrors(const vector<vector<Point3f>>& objectPoints,
                                        const vector<vector<Point2f>>& imagePoints,
                                        const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                                        const Mat& cameraMatrix, const Mat& distCoeffs,
                                        vector<float>& perViewErrors) {
    vector<Point2f> imagePoints2;
    int i, totalPoints = 0;
    double totalErr = 0, err;
    perViewErrors.resize(objectPoints.size());

    for (i = 0; i < (int)objectPoints.size(); i++) {
        projectPoints(Mat(objectPoints[i]), rvecs[i], tvecs[i],
                      cameraMatrix, distCoeffs, imagePoints2);
        err = norm(Mat(imagePoints[i]), Mat(imagePoints2), NORM_L2);
        int n = (int)objectPoints[i].size();
        perViewErrors[i] = (float)std::sqrt(err*err/n);
        totalErr += err*err;
        totalPoints += n;
    }

    return std::sqrt(totalErr/totalPoints);
}

static void calcChessboardCorners(cv::Size boardSize, float squareSize, vector<Point3f>& corners, Pattern patternType = CHESSBOARD) {

    corners.resize(0);

    switch(patternType) {
        case CHESSBOARD:
        case CIRCLES_GRID:
            for (int i = 0; i < boardSize.height; i++)
                for (int j = 0; j < boardSize.width; j++)
                    corners.push_back(Point3f(float(j*squareSize),
                                              float(i*squareSize), 0));
            break;
        case ASYMMETRIC_CIRCLES_GRID:
            for (int i = 0; i < boardSize.height; i++)
                for (int j = 0; j < boardSize.width; j++)
                    corners.push_back(Point3f(float((2*j + i % 2)*squareSize),
                                              float(i*squareSize), 0));
            break;
        default:
            std::cerr << "Unknown pattern type\n";
    }
}

static bool runCalibration(vector<vector<Point2f>> imagePoints,
                           cv::Size imageSize, cv::Size boardSize, Pattern patternType,
                           float squareSize, float aspectRatio,
                           int flags, Mat& cameraMatrix, Mat& distCoeffs,
                           vector<Mat>& rvecs, vector<Mat>& tvecs,
                           vector<float>& reprojErrs,
                           double& totalAvgErr, double& rms) {
    cameraMatrix = Mat::eye(3, 3, CV_64F);

    if (flags & CALIB_FIX_ASPECT_RATIO)
        cameraMatrix.at<double>(0,0) = aspectRatio;

    distCoeffs = Mat::zeros(8, 1, CV_64F);
    vector<vector<Point3f>> objectPoints(1);
    calcChessboardCorners(boardSize, squareSize, objectPoints[0], patternType);

    objectPoints.resize(imagePoints.size(),objectPoints[0]);

    rms = calibrateCamera(objectPoints, imagePoints, imageSize, cameraMatrix,
                                 distCoeffs, rvecs, tvecs, flags|CALIB_FIX_K4|CALIB_FIX_K5);

    bool ok = checkRange(cameraMatrix) && checkRange(distCoeffs);
    totalAvgErr = computeReprojectionErrors(objectPoints, imagePoints,
                                            rvecs, tvecs, cameraMatrix, distCoeffs, reprojErrs);
    return ok;
}

static void saveCameraParams(const string& filename,
                             cv::Size imageSize, cv::Size boardSize,
                             float squareSize, float aspectRatio, int flags,
                             const Mat& cameraMatrix, const Mat& distCoeffs,
                             const vector<Mat>& rvecs, const vector<Mat>& tvecs,
                             const vector<float>& reprojErrs,
                             const vector<vector<Point2f>>& imagePoints,
                             double totalAvgErr) {

    FileStorage fs(filename, FileStorage::WRITE);

    time_t tt;
    time( &tt );
    struct tm *t2 = localtime( &tt );
    char buf[1024];
    strftime( buf, sizeof(buf)-1, "%c", t2 );

    fs << "calibration_time" << buf;

    if( !rvecs.empty() || !reprojErrs.empty() )
        fs << "nframes" << (int)std::max(rvecs.size(), reprojErrs.size());
    fs << "image_width" << imageSize.width;
    fs << "image_height" << imageSize.height;
    fs << "board_width" << boardSize.width;
    fs << "board_height" << boardSize.height;
    fs << "square_size" << squareSize;

    if (flags & CALIB_FIX_ASPECT_RATIO)
        fs << "aspectRatio" << aspectRatio;

    if (flags != 0) {
        sprintf( buf, "flags: %s%s%s%s",
                flags & CALIB_USE_INTRINSIC_GUESS ? "+use_intrinsic_guess" : "",
                flags & CALIB_FIX_ASPECT_RATIO ? "+fix_aspectRatio" : "",
                flags & CALIB_FIX_PRINCIPAL_POINT ? "+fix_principal_point" : "",
                flags & CALIB_ZERO_TANGENT_DIST ? "+zero_tangent_dist" : "" );
    }

    fs << "flags" << flags;
    fs << "camera_matrix" << cameraMatrix;
    fs << "distortion_coefficients" << distCoeffs;
    fs << "avg_reprojection_error" << totalAvgErr;

    if (!reprojErrs.empty())
        fs << "per_view_reprojection_errors" << Mat(reprojErrs);

    if (!rvecs.empty() && !tvecs.empty()) {
        CV_Assert(rvecs[0].type() == tvecs[0].type());
        Mat bigmat((int)rvecs.size(), 6, rvecs[0].type());
        for(int i = 0; i < (int)rvecs.size(); i++) {
            Mat r = bigmat(Range(i, i+1), Range(0,3));
            Mat t = bigmat(Range(i, i+1), Range(3,6));

            CV_Assert(rvecs[i].rows == 3 && rvecs[i].cols == 1);
            CV_Assert(tvecs[i].rows == 3 && tvecs[i].cols == 1);
            r = rvecs[i].t();
            t = tvecs[i].t();
        }
        fs << "extrinsic_parameters" << bigmat;
    }

    if (!imagePoints.empty()) {
        Mat imagePtMat((int)imagePoints.size(), (int)imagePoints[0].size(), CV_32FC2);
        for (int i = 0; i < (int)imagePoints.size(); i++) {
            Mat r = imagePtMat.row(i).reshape(2, imagePtMat.cols);
            Mat imgpti(imagePoints[i]);
            imgpti.copyTo(r);
        }
        fs << "image_points" << imagePtMat;
    }
}

static bool runAndSave(const string& outputFilename,
                       const vector<vector<Point2f> >& imagePoints,
                       cv::Size imageSize, cv::Size boardSize, Pattern patternType, float squareSize,
                       float aspectRatio, int flags, Mat& cameraMatrix,
                       Mat& distCoeffs, bool writeExtrinsics, bool writePoints,
                       double& totalAvgErr, double& rms) {

    vector<Mat> rvecs, tvecs;
    vector<float> reprojErrs;

    bool ok = runCalibration(imagePoints, imageSize, boardSize, patternType, squareSize,
                             aspectRatio, flags, cameraMatrix, distCoeffs,
                             rvecs, tvecs, reprojErrs, totalAvgErr, rms);
    if (!ok) return false;

    saveCameraParams(outputFilename, imageSize,
                     boardSize, squareSize, aspectRatio,
                     flags, cameraMatrix, distCoeffs,
                     writeExtrinsics ? rvecs : vector<Mat>(),
                     writeExtrinsics ? tvecs : vector<Mat>(),
                     writeExtrinsics ? reprojErrs : vector<float>(),
                     writePoints ? imagePoints : vector<vector<Point2f> >(),
                     totalAvgErr);
    return true;
}

// end of code from OpenCV example ///////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



CalibratorStatusType const CalibratorStatusTypeDetection = DETECTION;
CalibratorStatusType const CalibratorStatusTypeCapturing = CAPTURING;
CalibratorStatusType const CalibratorStatusTypeCalibrated = CALIBRATED;

CalibratorPatternType const CalibratorPatternTypeChessboard = CHESSBOARD;
CalibratorPatternType const CalibratorPatternTypeCirclesGrid = CIRCLES_GRID;
CalibratorPatternType const CalibratorPatternTypeAsymmetricCirclesGrid = ASYMMETRIC_CIRCLES_GRID;

CalibratorPreviewRotationType const CalibratorPreviewRotationTypeNone = -1;
CalibratorPreviewRotationType const CalibratorPreviewRotationTypeCw90 = cv::ROTATE_90_CLOCKWISE;
CalibratorPreviewRotationType const CalibratorPreviewRotationTypeCw180 = cv::ROTATE_180;
CalibratorPreviewRotationType const CalibratorPreviewRotationTypeCw270 = cv::ROTATE_90_COUNTERCLOCKWISE;


@interface Calibrator()
@property (readwrite) int acquiredFrames;
@property (readwrite) CalibratorStatusType status;
@property std::string outputFilepath;
@property clock_t prevTimestamp;
@property Mat cameraMatrix;
@property Mat distCoeffs;
@property vector<vector<Point2f>> imagePoints;
@property bool resetRequested;
@property bool startRequested;
@property bool captureSetup;
@end

@implementation Calibrator

-(id _Nonnull) initWithOutputFile:(NSString *)outputFilepath delegate:(_Nonnull id<CalibratorDelegate>)delegate {
    if (self = [super init]) {
        self.delegate = delegate;
        self.numberOfFrames = 100;
        self.writeExtrinsics = false;
        self.writePoints = false;
        self.undistortImage = false;
        self.flags = 0;
        self.flipVertical = false;
        self.delay = 1000;
        self.squareSize = 1.0;
        self.aspectRatio = 1.0;;
        self.patternWidth = 8;
        self.patternHeight = 6;
        self.pattern = CHESSBOARD;
        self.previewRotation = CalibratorPreviewRotationTypeNone;
        self.outputFilepath = [outputFilepath UTF8String];
        self.resetRequested = false;
        self.startRequested = false;
        self.captureSetup = false;
        [self resetImmediately];
    }
    return self;
}

-(void) resetImmediately {
    self.acquiredFrames = 0;
    self.prevTimestamp = 0;
    self.status = DETECTION;
    self.cameraMatrix = Mat();
    self.distCoeffs = Mat();
    self.imagePoints = vector<vector<Point2f>>();
    self.resetRequested = false;
}

-(void) startImmediately {
    [self resetImmediately];
    self.prevTimestamp = clock();
    self.status = CAPTURING;
    self.startRequested = false;
}

-(void) reset {
    self.resetRequested = true;
}

-(void) abort {
    [self reset];
}

-(void) start {
    if (self.captureSetup) {
        self.startRequested = true;
    } else {
        [NSException raise:@"CaptureNotSetup"
                    format:@"Not ready to start calibrating. Did you forget to call [calibrator prepareForOutput:]?"];
    }
}

-(void) prepareForOutput:(AVCaptureVideoDataOutput *)videoOutput orientation:(AVCaptureVideoOrientation)orientation {

    dispatch_queue_t queue = dispatch_queue_create("calibration-buffer", nil);
    [videoOutput setSampleBufferDelegate:self queue:queue];
    [videoOutput setAlwaysDiscardsLateVideoFrames:true];

    [videoOutput setVideoSettings:@{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    }];

    AVCaptureConnection *conn = [videoOutput connectionWithMediaType:AVMediaTypeVideo];

    if (conn.isVideoMirroringSupported && conn.isVideoOrientationSupported) {
        [conn setVideoOrientation:orientation];
    } else {
        [NSException raise:@"DeviceNotSupported"
                    format:@"Device does not support one or more required features"];
    }

    self.captureSetup = true;
}

-(void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

    if (_resetRequested) {
        [self resetImmediately];
        [self.delegate calibratorDidCancelAcquisition:self];
    }

    if (_startRequested) {
        [self startImmediately];
        [self.delegate calibratorDidStartAcquisition:self];
    }

    cv::Mat bgraImage = BufferToMat(sampleBuffer);

    // flip image vertically if requested
    if (_flipVertical) cv::flip(bgraImage, bgraImage, 0);

    cv::Mat view, viewGray;
    cv::cvtColor(bgraImage, view, cv::COLOR_BGRA2RGB);
    cv::cvtColor(view, viewGray, cv::COLOR_RGB2GRAY);
    cv::Size imageSize = view.size();
    cv::Size boardSize = cv::Size(_patternWidth, _patternHeight);

    bool acquired = false;
    bool found = false;
    vector<Point2f> pointbuf;

    // if not yet calibrated, look for pattern
    if (_status != CALIBRATED) {

        switch (_pattern) {
            case CHESSBOARD:
                found = cv::findChessboardCorners(view, boardSize, pointbuf, CALIB_CB_ADAPTIVE_THRESH | CALIB_CB_FAST_CHECK | CALIB_CB_NORMALIZE_IMAGE);
                break;
            case CIRCLES_GRID:
                found = cv::findCirclesGrid(view, boardSize, pointbuf);
                break;
            case ASYMMETRIC_CIRCLES_GRID:
                found = cv::findCirclesGrid(view, boardSize, pointbuf, CALIB_CB_ASYMMETRIC_GRID);
                break;
            default:
                [NSException raise:@"UnknownPatternType" format:@"Unknown pattern type '%i'", _pattern];
                return;
        }

        // improve the accuracy of the corners' coordinates
        if (_pattern == CHESSBOARD && found) {
            cv::cornerSubPix(viewGray, pointbuf, cv::Size(11,11), cv::Size(-1,-1), TermCriteria(TermCriteria::EPS+TermCriteria::COUNT, 30, 0.1));
        }
    }

    // if pattern found, store new set of image points every some milliseconds
    if (_status == CAPTURING && found && (clock() - _prevTimestamp > _delay*1e-3*CLOCKS_PER_SEC)) {
        _imagePoints.push_back(pointbuf);
        _prevTimestamp = clock();
        _acquiredFrames = (int)_imagePoints.size();
        acquired = true;
    }

    // if pattern found, draw corners
    if (found) cv::drawChessboardCorners(view, boardSize, Mat(pointbuf), found);

    // if frame used for calibration, make image blink
    if (acquired) cv::bitwise_not(view, view);

    // if requested, undistort image with calibration data
    if (_status == CALIBRATED && _undistortImage) {
        Mat temp = view.clone();
        cv::undistort(temp, view, _cameraMatrix, _distCoeffs);
    }

    // if requested, apply rotation to the preview image
    if (_previewRotation >= 0) {
        cv::rotate(view, view, _previewRotation);
    }

    // return the preview image
    UIImage *preview = MatToUIImage(view);
    [_delegate calibrator:self didProcessFrame:preview];
    if (acquired) [_delegate calibrator:self didAcquireFrame:preview atStep:_acquiredFrames];

    // if we have acquired enough image points, perform final steps
    if (_status == CAPTURING && _imagePoints.size() >= _numberOfFrames) {

        [_delegate calibratorDidCompleteAcquisition:self];

        // run calibration based on the acquired image points
        double totalAvgErr = 0, rms = 0;
        bool result = runAndSave(_outputFilepath, _imagePoints, imageSize, boardSize, (Pattern)_pattern, _squareSize, _aspectRatio,
                                 _flags, _cameraMatrix, _distCoeffs, _writeExtrinsics, _writePoints, totalAvgErr, rms);

        // return the result
        _status = result ? CALIBRATED : DETECTION;
        [_delegate calibrator:self didTerminateWithResult:result avgReprojectionError:totalAvgErr rms:rms];
    }
}

@end
