//
//  ViewController.h
//  CheapMotion
//
//  Created by Ishaan Gulrajani on 11/10/13.
//  Copyright (c) 2013 Watchsend. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
    AVCaptureSession *captureSession;
    AVCaptureDevice *captureDevice;
    BOOL torchOn;
    AVCaptureVideoDataOutput *videoDataOutput;
    dispatch_queue_t videoOutputQueue;
    CGImageRef oddFrame;
    int droppedFrames;
    int i;
}

@end
