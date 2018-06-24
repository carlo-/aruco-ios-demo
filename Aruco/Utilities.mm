//
//  Utilities.m
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 23/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import "Utilities.h"

cv::Mat BufferToMat(CMSampleBufferRef buffer) {

    // begin processing
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    int bufferWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
    int bufferHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
    int bytesPerRow = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    unsigned char *pixel = (unsigned char *)CVPixelBufferGetBaseAddress(pixelBuffer);

    // put buffer in open cv, no memory copied
    cv::Mat mat(bufferHeight, bufferWidth, CV_8UC4, pixel, bytesPerRow);

    // end processing
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    return mat;
}
