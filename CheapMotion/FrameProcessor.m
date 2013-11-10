//
//  FrameProcessor.m
//  CheapMotion
//
//  Created by Ishaan Gulrajani on 11/10/13.
//  Copyright (c) 2013 Watchsend. All rights reserved.
//

#define DOWNSIZE_FACTOR 6
#import "FrameProcessor.h"

static int j = 0;

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
    
    NSLog(@"write to disk");
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
    
    qsort(buffer1, size, sizeof(unsigned char), compare_uchars);
    
    int runLengths[256];
    int runLocations[256];
    int runIndex = 0;
    for(int i=1; i<size; i++) {
        if(buffer1[i] == buffer1[i-1])
            runLengths[runIndex]++;
        else {
            runIndex++;
            runLocations[runIndex] = i;
        }
    }
    
    size_t minRunIndex = 0;
    for(int i=0; i<=runIndex; i++) {
        if(runLengths[i] < runLengths[minRunIndex])
            minRunIndex = i;
    }
    
//    unsigned char high = MAX(buffer1[(int)(size*0.95)], 225);
//    unsigned char low = 4; // 5 / 256 = 2% brightness
//
//    size_t lowCutoff = runLocations[minRunIndex - 3];
//    while(lowCutoff < size && buffer1[lowCutoff] < 10)
//        lowCutoff++;
    
//    size_t run = 0;
//    for(int i=1;i<size;i++) {
//        if(buffer1[i] == buffer1[i-1])
//            run++;
//        else {
////        NSLog(@"Run: %zu", run);
//        if(run < 10) {
//            lowCutoff = i;
//            break;
//        } else {
//            run = 0;
//        }
//        }
//    }
    
//    NSLog(@"low cutoff: %zu", lowCutoff);

//    int highCutoff = lowCutoff;
//    
//    while(highCutoff < size && buffer1[highCutoff] < high)
//        highCutoff++;
//
//    size_t highCutoff = size - 1;
//    
//    unsigned char fingerColor = buffer1[lowCutoff];
//
//    NSLog(@"lowCutoff: %f, fingerColor: %u", (double)lowCutoff / size, fingerColor);
//    NSLog(@"sorted: %u %u %u", buffer1[size/4], buffer1[size/2], buffer1[3*size/4]);
    
    int fingerColor = 0;
    int fingerPixelCount = 0;
    for(int i=0; i<size; i++) {
        if(buffer2[i] > 4) {
            fingerColor += buffer2[i];
            fingerPixelCount += 1;
            buffer2[i] = 255;
        } else {
            buffer2[i] = 0;
        }
//        buffer2[i] = (buffer2[i] > 10) ? 255 : 0;
        
//        if(buffer2[i] > high || buffer2[i] < low)
//            buffer2[i] = 0;

    }
    
    fingerColor /= fingerPixelCount;
    
    NSLog(@"fingerSize: %i, fingerColor: %i", fingerPixelCount, fingerColor);
    
    if(++j % 10 == 4) {
        NSLog(@"WRITING");
//        WriteBufferToDisk(buffer1, width, height);
        WriteBufferToDisk(buffer2, width, height);
    }
    
    free(buffer1);
    free(buffer2);
}

@end
