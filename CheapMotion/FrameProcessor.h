//
//  FrameProcessor.h
//  CheapMotion
//
//  Created by Ishaan Gulrajani on 11/10/13.
//  Copyright (c) 2013 Watchsend. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FrameProcessor : NSObject

-(void)processFrame:(CGImageRef)frame1 andFrame:(CGImageRef)frame2;

@end
