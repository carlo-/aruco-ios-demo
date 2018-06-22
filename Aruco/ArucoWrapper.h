//
//  ArucoWrapper.h
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 20/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ArucoGenerator: NSObject
@property BOOL enclosingCorners;
@property BOOL waterMark;
@property int pixelSize;
-(UIImage *_Nonnull) generateMarkerImage:(int)markerID;
-(id _Nonnull) initWithDictionary:(NSString *_Nonnull)dictionaryName;
-(id _Nonnull) init;
@end

@interface ArucoMarker: NSObject
@property int identifier;
@property float poseTX;
@property float poseTY;
@property float poseTZ;
@property float poseRX;
@property float poseRY;
@property float poseRZ;
@end

@interface ArucoDetector: NSObject
@property float markerSize;
-(NSArray<ArucoMarker *> *_Nonnull) detect:(UIImage *_Nonnull)image;
-(UIImage *_Nonnull) drawMarkers:(UIImage *_Nonnull)image;
@end

@protocol ArucoTrackerDelegate;

@interface ArucoTracker: NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property BOOL outputImages;
@property float markerSize;
@property (weak) _Nullable id<ArucoTrackerDelegate> delegate;
-(void) readCalibration:(NSString *_Nonnull)filepath;
-(void) prepareForOutput:(AVCaptureVideoDataOutput *_Nonnull)videoOutput;
-(id _Nonnull) initWithCalibrationFile:(NSString *_Nonnull)calibrationFilepath delegate:(_Nonnull id<ArucoTrackerDelegate>)delegate;
@end

@protocol ArucoTrackerDelegate
-(void) arucoTracker:(ArucoTracker *_Nonnull)tracker didDetectMarkers:(NSArray<ArucoMarker *> *_Nonnull)markers preview:(UIImage *_Nullable)preview;
@end

