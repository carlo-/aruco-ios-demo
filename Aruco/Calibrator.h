//
//  Calibrator.h
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 23/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>


typedef int CalibratorStatusType NS_TYPED_ENUM;
CalibratorStatusType extern const CalibratorStatusTypeDetection;
CalibratorStatusType extern const CalibratorStatusTypeCapturing;
CalibratorStatusType extern const CalibratorStatusTypeCalibrated;

typedef int CalibratorPatternType NS_TYPED_ENUM;
CalibratorPatternType extern const CalibratorPatternTypeChessboard;
CalibratorPatternType extern const CalibratorPatternTypeCirclesGrid;
CalibratorPatternType extern const CalibratorPatternTypeAsymmetricCirclesGrid;

typedef int CalibratorPreviewRotationType NS_TYPED_ENUM;
CalibratorPreviewRotationType extern const CalibratorPreviewRotationTypeNone;
CalibratorPreviewRotationType extern const CalibratorPreviewRotationTypeCw90;
CalibratorPreviewRotationType extern const CalibratorPreviewRotationTypeCw180;
CalibratorPreviewRotationType extern const CalibratorPreviewRotationTypeCw270;


@protocol CalibratorDelegate;

@interface Calibrator : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak) _Nullable id<CalibratorDelegate> delegate;
@property int numberOfFrames;
@property (readonly) int acquiredFrames;
@property bool writeExtrinsics;
@property bool writePoints;
@property bool undistortImage;
@property int flags;
@property bool flipVertical;
@property int delay;
@property float squareSize;
@property float aspectRatio;
@property int patternWidth;
@property int patternHeight;
@property CalibratorPreviewRotationType previewRotation;
@property CalibratorPatternType pattern;
@property (readonly) CalibratorStatusType status;
-(void) reset;
-(void) abort;
-(void) start;
-(void) prepareForOutput:(AVCaptureVideoDataOutput *_Nonnull)videoOutput orientation:(AVCaptureVideoOrientation)orientation;
-(id _Nonnull) initWithOutputFile:(NSString *_Nonnull)outputFilepath delegate:(_Nonnull id<CalibratorDelegate>)delegate;
@end

@protocol CalibratorDelegate
-(void) calibrator:(Calibrator *_Nonnull)calibrator didProcessFrame:(UIImage *_Nonnull)frame;
-(void) calibrator:(Calibrator *_Nonnull)calibrator didAcquireFrame:(UIImage *_Nonnull)frame atStep:(int)step;
-(void) calibrator:(Calibrator *_Nonnull)calibrator didTerminateWithResult:(BOOL)result avgReprojectionError:(double)avgError rms:(double)rms;
@end
