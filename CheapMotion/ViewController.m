//
//  ViewController.m
//  CheapMotion
//
//  Created by Ishaan Gulrajani on 11/10/13.
//  Copyright (c) 2013 Watchsend. All rights reserved.
//

#import "ViewController.h"
#import "FrameProcessor.h"

#define EFFECTIVE_FRAMERATE 15

@implementation ViewController

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self initializeTorch];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.5/(2.0*EFFECTIVE_FRAMERATE)) * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [NSTimer scheduledTimerWithTimeInterval:1.0/(2.0*EFFECTIVE_FRAMERATE)
                                         target:self
                                       selector:@selector(toggleTorch)
                                       userInfo:nil
                                        repeats:YES];
    });
}

- (void)initializeTorch {
    captureSession = [[AVCaptureSession alloc] init];
    
    [captureSession beginConfiguration];
    
    captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    if ([captureDevice hasTorch] && [captureDevice hasFlash]) {
        AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
        
        if (deviceInput) {
            [captureSession addInput:deviceInput];
        }
        
        videoOutputQueue = dispatch_queue_create("com.watchsend.CheapMotion.VideoOutputQueue", DISPATCH_QUEUE_SERIAL);
        
        videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        [videoDataOutput setSampleBufferDelegate:self queue:videoOutputQueue];
        [captureSession addOutput:videoDataOutput];
        
        [captureDevice lockForConfiguration:nil];
        [captureDevice setActiveVideoMinFrameDuration:CMTimeMake(1, 2*EFFECTIVE_FRAMERATE)];
        [captureDevice unlockForConfiguration];
        
        [captureSession commitConfiguration];
        [captureSession startRunning];
    }
}

- (void)setTorchOn:(BOOL)strobeOn {
    [captureDevice lockForConfiguration:nil];

    torchOn = strobeOn;
    [captureDevice setTorchMode:strobeOn];
    [captureDevice setFlashMode:strobeOn];
    
    [captureDevice unlockForConfiguration];
}

-(void)toggleTorch {
    [self setTorchOn:!torchOn];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
        
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        CIContext *context = [CIContext contextWithOptions:nil];
        CGImageRef image = [context createCGImage:ciImage
                                         fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(imageBuffer), CVPixelBufferGetHeight(imageBuffer))];
 
        // This method gets called with every frame. Every odd frame has no flash, and every even frame has flash.
        // Our job is to pair successive flash off/on frames and process them together.
        
        // Make sure that an even number of frames get dropped so we don't break synchronization.
        droppedFrames %= 2;
        if(droppedFrames) {
            droppedFrames--;
            return;
        }
        
        if(oddFrame) {
            // This is an even frame; process it along with the previous frame
            
            
            FrameProcessor *fp = [[FrameProcessor alloc] init];
            [fp processFrame:oddFrame andFrame:image];
            
            CGImageRelease(image);
            CGImageRelease(oddFrame);

            oddFrame = NULL;
            
        } else {
            // This is an odd frame; store it and wait for the next frame.
            oddFrame = image;
        }
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"(dropped frame)");
    droppedFrames++;
    
    // Make sure that there are no dropped frames between pairs by retroactively "dropping" the last odd frame if there is one.
    if(oddFrame) {
        CGImageRelease(oddFrame);
        oddFrame = NULL;
        droppedFrames++;
    }
}

@end
