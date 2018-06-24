//
//  ArucoWrapper.mm
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 20/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import "ArucoWrapper.h"
#import "Utilities.h"

#import <opencv2/imgproc/imgproc.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core/core.hpp>
#import <aruco.h>


#pragma mark - Constants

ArucoPreviewRotationType const ArucoPreviewRotationTypeNone = -1;
ArucoPreviewRotationType const ArucoPreviewRotationTypeCw90 = cv::ROTATE_90_CLOCKWISE;
ArucoPreviewRotationType const ArucoPreviewRotationTypeCw180 = cv::ROTATE_180;
ArucoPreviewRotationType const ArucoPreviewRotationTypeCw270 = cv::ROTATE_90_COUNTERCLOCKWISE;


#pragma mark - ArucoMarker

@implementation ArucoMarker

-(id _Nullable) initWithCMarker:(aruco::Marker)cmarker {
    if (!(cmarker.isValid() && cmarker.isPoseValid())) {
        return nil;
    } else if (self = [super init]) {
        self.identifier = cmarker.id;
        self.poseRX = cmarker.Rvec.at<float>(0);
        self.poseRY = cmarker.Rvec.at<float>(1);
        self.poseRZ = cmarker.Rvec.at<float>(2);
        self.poseTX = cmarker.Tvec.at<float>(0);
        self.poseTY = cmarker.Tvec.at<float>(1);
        self.poseTZ = cmarker.Tvec.at<float>(2);
    }
    return self;
}

@end


#pragma mark - ArucoTracker

@interface ArucoTracker()
@property std::map<uint32_t, aruco::MarkerPoseTracker> *mapOfTrackers;
@property aruco::MarkerPoseTracker *tracker;
@property aruco::MarkerDetector *detector;
@property aruco::CameraParameters *camParams;
@property CIContext *ciContext;
@property BOOL setupDone;
@end

@implementation ArucoTracker

-(id _Nonnull) initWithCalibrationFile:(NSString *_Nonnull)calibrationFilepath delegate:(_Nonnull id<ArucoTrackerDelegate>)delegate {
    if (self = [super init]) {
        self.mapOfTrackers = new std::map<uint32_t, aruco::MarkerPoseTracker>();
        self.tracker = new aruco::MarkerPoseTracker();
        self.detector = new aruco::MarkerDetector();
        self.camParams = new aruco::CameraParameters();
        self.markerSize = 0.04;
        self.outputImages = true;
        self.previewRotation = -1;
        self.ciContext = [[CIContext alloc] init];
        self.setupDone = false;
        self.delegate = delegate;
        [self readCalibration:calibrationFilepath];
    }
    return self;
}

-(void) readCalibration:(NSString *)filepath {
    self.camParams->readFromXMLFile([filepath UTF8String]);
}

-(void) prepareForOutput:(AVCaptureVideoDataOutput *)videoOutput orientation:(AVCaptureVideoOrientation)orientation {

    dispatch_queue_t queue = dispatch_queue_create("video-sample-buffer", nil);
    [videoOutput setSampleBufferDelegate:self queue:queue];
    [videoOutput setAlwaysDiscardsLateVideoFrames:true];

    [videoOutput setVideoSettings:@{
        (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
    }];

    AVCaptureConnection *conn = [videoOutput connectionWithMediaType:AVMediaTypeVideo];

    if (conn.isVideoMirroringSupported && conn.isVideoOrientationSupported) {
        [conn setVideoOrientation:orientation];
    } else {
        [NSException raise:@"DeviceNotSupported" format:@"Device does not support one or more required features"];
    }

    self.setupDone = false;
}

-(void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {

    cv::Mat bgraImage = BufferToMat(sampleBuffer);

    cv::Mat colorImage, grayImage;
    cv::cvtColor(bgraImage, colorImage, cv::COLOR_BGRA2RGB);
    cv::cvtColor(colorImage, grayImage, cv::COLOR_RGB2GRAY);

    if (!self.setupDone) {
        self.camParams->CamSize = colorImage.size();
        self.setupDone = true;
    }

    auto mapOfTrackers = *self.mapOfTrackers;
    bool hasValidCamParams = self.camParams->isValid();
    std::vector<aruco::Marker> markers = self.detector->detect(grayImage, *self.camParams, self.markerSize);

    NSMutableArray *result = [NSMutableArray new];

    for (auto& m : markers) {
        mapOfTrackers[m.id].estimatePose(m, *self.camParams, self.markerSize);
        ArucoMarker *markerObj = [[ArucoMarker alloc] initWithCMarker:m];
        if (markerObj != nil) [result addObject:markerObj];
    }

    UIImage *preview = nil;

    if (self.outputImages) {

        for (auto& m : markers) {
            m.draw(colorImage, cv::Scalar(0, 0, 255), 2);
            if (hasValidCamParams && m.isPoseValid()) {
                aruco::CvDrawingUtils::draw3dCube(colorImage, m, *self.camParams);
                aruco::CvDrawingUtils::draw3dAxis(colorImage, m, *self.camParams);
            }
        }

        if (_previewRotation >= 0) {
            cv::rotate(colorImage, colorImage, _previewRotation);
        }

        preview = MatToUIImage(colorImage);
    }

    [self.delegate arucoTracker:self didDetectMarkers:result preview:preview];
}

@end


#pragma mark - ArucoGenerator

@interface ArucoGenerator()
@property std::string dictionaryName;
@property aruco::Dictionary dictionary;
@end

@implementation ArucoGenerator

-(id _Nonnull) initWithDictionary:(NSString *_Nonnull)dictionaryName {
    if (self = [super init]) {
        self.dictionaryName = [dictionaryName UTF8String];
        self.dictionary = aruco::Dictionary::load(self.dictionaryName);
        self.enclosingCorners = false;
        self.waterMark = true;
        self.pixelSize = 75;
    }
    return self;
}

-(id _Nonnull) init {
    return [[ArucoGenerator alloc] initWithDictionary:@"ARUCO"];
}

-(UIImage *) generateMarkerImage:(int)markerID {
    cv::Mat markerImage = self.dictionary.getMarkerImage_id(markerID, self.pixelSize, self.waterMark, self.enclosingCorners);
    return MatToUIImage(markerImage);
}

@end


#pragma mark - ArucoDetector

@interface ArucoDetector()
@property aruco::MarkerDetector *detector;
@property aruco::CameraParameters *camParams;
@end

@implementation ArucoDetector

-(id _Nonnull) init {
    if (self = [super init]) {
        self.detector = new aruco::MarkerDetector();
        self.camParams = new aruco::CameraParameters();
        self.markerSize = 0.04;
    }
    return self;
}

-(NSArray<ArucoMarker *> *) detect:(UIImage *)image {

    cv::Mat colorImage, grayImage;
    UIImageToMat(image, colorImage);
    cvtColor(colorImage, grayImage, cv::COLOR_BGR2GRAY);
    std::vector<aruco::Marker> markers = self.detector->detect(grayImage, *self.camParams, self.markerSize);
    NSMutableArray *result = [NSMutableArray new];

    for (auto& m : markers) {
        ArucoMarker *markerObj = [[ArucoMarker alloc] initWithCMarker:m];
        if (markerObj != nil) [result addObject:markerObj];
    }

    return result;
}

-(UIImage *) drawMarkers:(UIImage *)image {

    cv::Mat colorImage, grayImage;
    UIImageToMat(image, colorImage);
    cvtColor(colorImage, grayImage, cv::COLOR_BGR2GRAY);
    std::vector<aruco::Marker> markers = self.detector->detect(grayImage, *self.camParams, self.markerSize);

    for (auto& m : markers) {
        m.draw(colorImage, cv::Scalar(0,0,255), 2);
    }

    return MatToUIImage(colorImage);
}

@end
