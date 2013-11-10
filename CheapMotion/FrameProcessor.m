//
//  FrameProcessor.m
//  CheapMotion
//
//  Created by Ishaan Gulrajani on 11/10/13.
//  Copyright (c) 2013 Watchsend. All rights reserved.
//

#define DOWNSIZE_FACTOR 6
#import "FrameProcessor.h"

static int frameCount = 0;

void* CreateGrayscaleBufferFromCGImage(CGImageRef image) {
    size_t width = CGImageGetWidth(image) / DOWNSIZE_FACTOR;
    size_t height = CGImageGetHeight(image) / DOWNSIZE_FACTOR;
    
    void* buffer = malloc(width*height);
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGContextRef context = CGBitmapContextCreate(buffer,
                                                 width,
                                                 height,
                                                 8, // bits per pixel
                                                 width, // bytes per row
                                                 colorspace,
                                                 (CGBitmapInfo)kCGImageAlphaNone);
    CGColorSpaceRelease(colorspace);
    
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), image);
    
    CGContextRelease(context);
    
    return buffer;
}

void WriteBufferToDisk(unsigned char *buffer, size_t width, size_t height) {
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, buffer, width*height, NULL);
    CGImageRef image = CGImageCreate(width, height, 8, 8, width, colorspace, (CGBitmapInfo)kCGImageAlphaNone, dataProvider, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorspace);
    
    NSData *imageData = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
    CGImageRelease(image);

    // Dictionary that holds post parameters. You can set your post parameters that your server accepts or programmed to accept.
    NSMutableDictionary* _params = [[NSMutableDictionary alloc] init];
    [_params setObject:@"1.0" forKey:@"ver"];
    [_params setObject:@"en" forKey:@"lan"];
    
    // the boundary string : a random string, that will not repeat in post data, to separate post data fields.
    NSString *BoundaryConstant = @"----------V2ymHFg03ehbqgZCaKO6jy";
    
    // string constant for the post parameter 'file'. My server uses this name: `file`. Your's may differ
    NSString* FileParamConstant = @"file";
    
    // the server url to which the image (or the media) is uploaded. Use your server url here
    NSURL* requestURL = [NSURL URLWithString:@"http://cys35ze402xb.runscope.net/upload"];

    
    // create request
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [request setHTTPShouldHandleCookies:NO];
    [request setTimeoutInterval:30];
    [request setHTTPMethod:@"POST"];
    
    // set Content-Type in HTTP header
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", BoundaryConstant];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    // post body
    NSMutableData *body = [NSMutableData data];
    
    // add params (all params are strings)
    for (NSString *param in _params) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", param] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", [_params objectForKey:param]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    // add image data
    if (imageData) {
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"image.jpg\"\r\n", FileParamConstant] dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [body appendData:imageData];
        [body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", BoundaryConstant] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // setting the body of the post to the reqeust
    [request setHTTPBody:body];
    
    // set the content-length
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[body length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    // set URL
    [request setURL:requestURL];
    
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:nil];
    [connection start];
}

int compare_uchars(const void *a, const void *b) {
    const unsigned char *ua = (const unsigned char *)a;
    const unsigned char *ub = (const unsigned char *)b;
    
    return (*ua > *ub) - (*ua < *ub);
}

@implementation FrameProcessor

-(void)processFrame:(CGImageRef)frame1 andFrame:(CGImageRef)frame2 {
    size_t width = CGImageGetWidth(frame1) / DOWNSIZE_FACTOR;
    size_t height = CGImageGetHeight(frame2) / DOWNSIZE_FACTOR;
    size_t size = width*height;
    
    unsigned char *buffer1 = CreateGrayscaleBufferFromCGImage(frame1);
    unsigned char *buffer2 = CreateGrayscaleBufferFromCGImage(frame2);
    
    for(int i=0; i<size; i++) {
        unsigned char diff = abs(buffer2[i] - buffer1[i]);
        buffer1[i] = diff;
        buffer2[i] = diff;
    }
    
    // Pass 1: Filter out all pixels with brightness < 10
    
    for(int i=0; i<size; i++)
        buffer1[i] = 255*(buffer1[i] > 10);
    
    // Pass 2: Filter out all 4x4 blocks with <50% white pixels
    
    int blockSize = 8;
    
    for(int x=0;x<width;x+=blockSize) {
        for(int y=0;y<height;y+=blockSize) {
            int sum = 0;
            for(int dx=0;dx<blockSize;dx++)
                for(int dy=0;dy<blockSize;dy++)
                    sum += buffer1[x+dx+width*(y+dy)];
            
            if(sum < blockSize*blockSize*255/2)
                for(int dx=0;dx<blockSize;dx++)
                    for(int dy=0;dy<blockSize;dy++)
                        buffer1[x+dx+width*(y+dy)] = 0;
        }
    }
    
    // Calculate average brightness (used for height calculation later)
    
    int brightness = 0;
    int countedPixels = 0;
    for(int i=0;i<size;i++) {
        if(buffer1[i]) {
            brightness += buffer2[i];
            countedPixels++;
        }
    }
    
    brightness /= countedPixels;
    
    NSLog(@"Brightness: %i", brightness);
    
    // Find fingertip

    int fingertipX, fingertipY;
    for(int i=0; i<size; i++) {
        if(buffer1[i]) {
            fingertipX = (int)i%width;
            fingertipY = (int)i/width;
            break;
        }
    }
    
    for(int x=0;x<width;x++) {
        for(int y=0;y<height;y++) {
            if(x == fingertipX || y == fingertipY)
                buffer2[x+(width*y)] = 255;
        }
    }
    
    if(frameCount++ % 20 == 4) {
        NSLog(@"WRITING");
        WriteBufferToDisk(buffer1, width, height);
        WriteBufferToDisk(buffer2, width, height);
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Sending");
        [NSString stringWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http:/169.254.226.46:3000/post?x=%f&y=%f&z=%f", fingertipX/320.0, fingertipY/180.0, (255-brightness)/255.0]]
                                 encoding:NSUTF8StringEncoding
                                    error:nil];
    });
    
    free(buffer1);
    free(buffer2);
}

@end
