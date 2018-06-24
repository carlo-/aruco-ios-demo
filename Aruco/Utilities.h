//
//  Utilities.h
//  ArucoDemo
//
//  Created by Carlo Rapisarda on 23/06/2018.
//  Copyright © 2018 Carlo Rapisarda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <opencv2/core/core.hpp>

cv::Mat BufferToMat(CMSampleBufferRef buffer);
