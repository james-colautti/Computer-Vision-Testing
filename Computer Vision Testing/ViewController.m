//
//  ViewController.m
//  Computer Vision Testing
//
//  Created by James on 2015-03-03.
//  Copyright (c) 2015 James Colautti. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIView *contentView;
@property (weak, nonatomic) IBOutlet UIImageView *placeholderView;
@property (weak, nonatomic) IBOutlet UIImageView *outputView;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureStillImageOutput *imageOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) NSMutableString *mCode;

@property BOOL mAnimating;

@end

@implementation ViewController

#pragma mark - Setup Methods
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
//    // optimizes focus for near
//    if ( [captureDevice lockForConfiguration:NULL] == YES ) {
//        captureDevice.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionFar;
//        [captureDevice unlockForConfiguration];
//    }
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (input)
    {
        self.captureSession = [[AVCaptureSession alloc] init];
        [self.captureSession addInput:input];
        
        self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
        [self.captureSession addOutput:self.imageOutput];
        
        self.videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        [self.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        [self.videoPreviewLayer setFrame:self.contentView.layer.bounds];
        [self.contentView.layer addSublayer:self.videoPreviewLayer];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.captureSession)
    {
        [self.captureSession startRunning];
        
        [self startCapturingImages];
    }
    else
    {
        [self parseTestImage];
    }
}

#pragma mark - Capture Methods
- (void)startCapturingImages
{
    [self captureImageWithCompletion:^(BOOL success, UIImage *image) {
//        [NSTimer scheduledTimerWithTimeInterval:0.2F target:self selector:@selector(startCapturingImages) userInfo:nil repeats:NO];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01F * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self startCapturingImages];
        });
        if (success)
        {
//            CIContext *context = [CIContext contextWithOptions:nil];
//            CIImage *input = [[CIImage alloc] initWithCGImage:[[self scaleAndRotateImage:image] CGImage] options:nil];
//            CIFilter *filter = [CIFilter filterWithName:@"CIEdges"];
//            [filter setValue:input forKey:kCIInputImageKey];
//            [filter setValue:@0.8f forKey:kCIInputIntensityKey];
//            CIImage *result = [filter valueForKey:kCIOutputImageKey];
//            CGRect extent = [result extent];
//            CGImageRef cgImage = [context createCGImage:result fromRect:extent];
//            UIImage *final = [UIImage imageWithCIImage:result];
//            [self.outputView setImage:final];
            
//            [self.outputView setImage:image];
            UIImage *scaledImage = [self scaleImage:image toSize:CGSizeMake(image.size.width / 5, image.size.height / 5)];
            UIImage *input = [self scaleAndRotateImage:scaledImage];
            NSMutableArray *imageRGBArray = [self getRGBAsFromImage:input];
            NSMutableArray *imageGrayScaleArray = [self getGrayScaleFromRGBs:imageRGBArray];
            NSMutableArray *imageSmoothArray = [self smoothFilterRGBs:imageGrayScaleArray size:1];
            NSMutableArray *imageEdgeArray = [self edgeFilterRGBs:imageSmoothArray threshold:0.1F];
            UIImage *edgeImage = [self getImageFromRGBs:imageEdgeArray];
            [self.outputView setImage:edgeImage];
        }
    }];
    
    
}

- (void)captureImageWithCompletion:(void(^)(BOOL success, UIImage *image))completion
{
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.imageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection)
        {
            break;
        }
    }
    
    if (!videoConnection)
    {
        completion(NO, nil);
        return;
    }
    
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        
        completion(YES, image);
    }];
}

- (void)parseTestImage
{
    UIImage *image = [UIImage imageNamed:@"steampunk.jpg"];
    [self.placeholderView setImage:image];
    NSMutableArray *imageRGBArray = [self getRGBAsFromImage:image];
    NSMutableArray *imageGrayScaleArray = [self getGrayScaleFromRGBs:imageRGBArray];
    NSMutableArray *imageSmoothArray = [self smoothFilterRGBs:imageGrayScaleArray size:2];
    NSMutableArray *imageEdgeArray = [self edgeFilterRGBs:imageSmoothArray threshold:0.1F];
    UIImage *edgeImage = [self getImageFromRGBs:imageEdgeArray];
    [self.outputView setImage:edgeImage];
}

- (UIImage *)scaleAndRotateImage:(UIImage *)image {
    int kMaxResolution = 640; // Or whatever
    
    CGImageRef imgRef = image.CGImage;
    
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake(0, 0, width, height);
    if (width > kMaxResolution || height > kMaxResolution) {
        CGFloat ratio = width/height;
        if (ratio > 1) {
            bounds.size.width = kMaxResolution;
            bounds.size.height = roundf(bounds.size.width / ratio);
        }
        else {
            bounds.size.height = kMaxResolution;
            bounds.size.width = roundf(bounds.size.height * ratio);
        }
    }
    
    CGFloat scaleRatio = bounds.size.width / width;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
    CGFloat boundHeight;
    UIImageOrientation orient = image.imageOrientation;
    switch(orient) {
            
        case UIImageOrientationUp: //EXIF = 1
            transform = CGAffineTransformIdentity;
            break;
            
        case UIImageOrientationUpMirrored: //EXIF = 2
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
            
        case UIImageOrientationDown: //EXIF = 3
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationDownMirrored: //EXIF = 4
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
            
        case UIImageOrientationLeftMirrored: //EXIF = 5
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationLeft: //EXIF = 6
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
            
        case UIImageOrientationRightMirrored: //EXIF = 7
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        case UIImageOrientationRight: //EXIF = 8
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
            
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
            
    }
    
    UIGraphicsBeginImageContext(bounds.size);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
        CGContextScaleCTM(context, -scaleRatio, scaleRatio);
        CGContextTranslateCTM(context, -height, 0);
    }
    else {
        CGContextScaleCTM(context, scaleRatio, -scaleRatio);
        CGContextTranslateCTM(context, 0, -height);
    }
    
    CGContextConcatCTM(context, transform);
    
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
    UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return imageCopy;
}

-(UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - Filter Methods
- (NSMutableArray *)getRGBAsFromImage:(UIImage *)image
{
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:height];
    for (int i = 0 ; i < height; i++)
    {
        NSMutableArray *subResult = [NSMutableArray arrayWithCapacity:width];
        for (int j = 0; j < width; j++)
        {
            NSUInteger byteIndex = i * bytesPerRow + j * bytesPerPixel;
            CGFloat red   = (rawData[byteIndex]     * 1.0) / 255.0;
            CGFloat green = (rawData[byteIndex + 1] * 1.0) / 255.0;
            CGFloat blue  = (rawData[byteIndex + 2] * 1.0) / 255.0;
            CGFloat alpha = (rawData[byteIndex + 3] * 1.0) / 255.0;
            UIColor *acolor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
            [subResult addObject:acolor];
        }
        [result addObject:subResult];
    }
    
    free(rawData);
    
    return result;
}

- (NSMutableArray *)getGrayScaleFromImage:(UIImage *)image
{
    NSMutableArray *grayScaleArray = [self getGrayScaleFromRGBs:[self getRGBAsFromImage:image]];
    return grayScaleArray;
}

- (NSMutableArray *)getGrayScaleFromRGBs:(NSMutableArray *)rgbs
{
    NSMutableArray *grayScaleArray = [NSMutableArray arrayWithCapacity:rgbs.count];
    for (NSMutableArray *row in rgbs)
    {
        NSMutableArray *grayScaleRow = [NSMutableArray arrayWithCapacity:row.count];
        for (UIColor *color in row)
        {
            CGFloat red, green, blue, white, alpha;
//            [color getWhite:&white alpha:&alpha];
            [color getRed:&red green:&green blue:&blue alpha:&alpha];
            white = (red + green + blue) / 3.0F;
            UIColor *grayScaleColor = [UIColor colorWithWhite:white alpha:alpha];
            [grayScaleRow addObject:grayScaleColor];
        }
        [grayScaleArray addObject:grayScaleRow];
    }
    
    return grayScaleArray;
}

- (NSMutableArray *)smoothFilterRGBs:(NSMutableArray *)rgbs size:(int)size
{
    NSMutableArray *edgeArray = [NSMutableArray arrayWithCapacity:rgbs.count];
    CGFloat width = [[rgbs firstObject] count];
    CGFloat height = [rgbs count];
    for (int i = 0; i < height; i++)
    {
//        NSMutableArray *row[3];
//        if (i > 0)
//        {
//            row[0] = [rgbs objectAtIndex:i - 1];
//        }
//        row[1] = [rgbs objectAtIndex:i];
//        if (i < rgbs.count - 1)
//        {
//            row[2] = [rgbs objectAtIndex:i + 1];
//        }
        NSMutableArray *edgeRowArray = [NSMutableArray arrayWithCapacity:width];
        for (int j = 0; j < width; j++)
        {
            CGFloat filterValue;
            CGFloat white, alpha;
            for (int ii = -size; ii <= size; ii++)
            {
                for (int jj = -size; jj <= size; jj++)
                {
                    if (i + ii >= 0 && i + ii < height && j + jj >= 0 && j + jj < width)
                    {
                        NSMutableArray *row = [rgbs objectAtIndex:i + ii];
                        UIColor *color = [row objectAtIndex:j + jj];
                        [color getWhite:&white alpha:&alpha];
                        filterValue += white;
                    }
                }
            }
//            if (j > 0)
//            {
//                UIColor *color = [row2 objectAtIndex:j - 1];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (j < row2.count - 1)
//            {
//                UIColor *color = [row2 objectAtIndex:j + 1];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (i > 0)
//            {
//                UIColor *color = [row1 objectAtIndex:j];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (i < rgbs.count - 1)
//            {
//                UIColor *color = [row3 objectAtIndex:j];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (j > 0 && i > 0)
//            {
//                UIColor *color = [row1 objectAtIndex:j - 1];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (j > 0 && i < rgbs.count - 1)
//            {
//                UIColor *color = [row3 objectAtIndex:j - 1];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (j < row2.count - 1 && i > 0)
//            {
//                UIColor *color = [row1 objectAtIndex:j + 1];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
//            
//            if (j < row2.count - 1 && i < rgbs.count - 1)
//            {
//                UIColor *color = [row3 objectAtIndex:j + 1];
//                [color getWhite:&white alpha:&alpha];
//                filterValue += white;
//            }
            
            filterValue = filterValue / ((size * 2 + 1) * (size * 2 + 1));
            
            UIColor *newColor;
            newColor = [UIColor colorWithWhite:filterValue alpha:1.0F];
            [edgeRowArray addObject:newColor];
        }
        [edgeArray addObject:edgeRowArray];
    }
    
    return edgeArray;
}

- (NSMutableArray *)edgeFilterRGBs:(NSMutableArray *)rgbs threshold:(CGFloat)threshold
{
    NSMutableArray *edgeArray = [NSMutableArray arrayWithCapacity:rgbs.count];
    for (int i = 0; i < rgbs.count; i++)
    {
        NSMutableArray *row1, *row2, *row3;
        if (i > 0)
        {
            row1 = [rgbs objectAtIndex:i - 1];
        }
        row2 = [rgbs objectAtIndex:i];
        if (i < rgbs.count - 1)
        {
            row3 = [rgbs objectAtIndex:i + 1];
        }
        NSMutableArray *edgeRowArray = [NSMutableArray arrayWithCapacity:row2.count];
        for (int j = 0; j < row2.count; j++)
        {
            CGFloat filterValue, filterValueH, filterValueV;
            CGFloat white, alpha;
            if (j > 0)
            {
                UIColor *color1 = [row2 objectAtIndex:j - 1];
                [color1 getWhite:&white alpha:&alpha];
                filterValueH += white;
            }
            
            if (j < row2.count - 1)
            {
                UIColor *color3 = [row2 objectAtIndex:j + 1];
                [color3 getWhite:&white alpha:&alpha];
                filterValueH -= white;
            }
            
            if (i > 0)
            {
                UIColor *color1 = [row1 objectAtIndex:j];
                [color1 getWhite:&white alpha:&alpha];
                filterValueV -= white;
            }
            
            if (i < rgbs.count - 1)
            {
                UIColor *color3 = [row3 objectAtIndex:j];
                [color3 getWhite:&white alpha:&alpha];
                filterValueV += white;
            }
            
            filterValueH = fabs(filterValueH) / 2.0F;
            filterValueV = fabs(filterValueV) / 2.0F;
            filterValue = filterValueH + filterValueV;
            
            UIColor *newColor;
            if (threshold)
            {
                if (filterValue > threshold)
                {
                    newColor = [UIColor colorWithWhite:1.0F alpha:1.0F];
                }
                else
                {
                    newColor = [UIColor colorWithWhite:0.0F alpha:1.0F];
                }
            }
            else
            {
                newColor = [UIColor colorWithWhite:filterValue alpha:1.0F];
            }
            [edgeRowArray addObject:newColor];
        }
        [edgeArray addObject:edgeRowArray];
    }
    
    return edgeArray;
}

- (UIImage *)getImageFromRGBs:(NSMutableArray *)rgbs
{
    NSUInteger width = [[rgbs firstObject] count];
    NSUInteger height = [rgbs count];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    
    for (int i = 0; i < rgbs.count; i++)
    {
        NSMutableArray *row = [rgbs objectAtIndex:i];
        for (int j = 0; j < row.count; j++)
        {
            UIColor *color = [row objectAtIndex:j];
            NSUInteger byteIndex = i * bytesPerRow + j * bytesPerPixel;

            CGFloat red, green, blue, white, alpha;
            BOOL isColor = [color getRed:&red green:&green blue:&blue alpha:&alpha];
            if (isColor)
            {
                rawData[byteIndex] = red * 250.0F;
                rawData[byteIndex + 1] = green * 250.0F;
                rawData[byteIndex + 2] = blue * 250.0F;
                rawData[byteIndex + 3] = alpha * 250.0F;
            }
            else
            {
                BOOL isWhite = [color getWhite:&white alpha:&alpha];
                if (isWhite)
                {
                    rawData[byteIndex] = white * 250.0F;
                    rawData[byteIndex + 1] = white * 250.0F;
                    rawData[byteIndex + 2] = white * 250.0F;
                    rawData[byteIndex + 3] = alpha * 250.0F;
                }
                else
                {
                    rawData[byteIndex] = 0.0F;
                    rawData[byteIndex + 1] = 0.0F;
                    rawData[byteIndex + 2] = 0.0F;
                    rawData[byteIndex + 3] = 0.0F;
                }
            }
        }
    }
    
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    
    CGContextRelease(context);
    
    free(rawData);
    
    return image;
}

- (NSArray*)getRGBAsFromImage:(UIImage*)image atX:(int)x andY:(int)y count:(int)count
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    
    // First get the image into your data buffer
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char *rawData = (unsigned char*) calloc(height * width * 4, sizeof(unsigned char));
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    // Now your rawData contains the image data in the RGBA8888 pixel format.
    NSUInteger byteIndex = (bytesPerRow * y) + x * bytesPerPixel;
    for (int i = 0 ; i < count ; ++i)
    {
        CGFloat red   = (rawData[byteIndex]     * 1.0) / 255.0;
        CGFloat green = (rawData[byteIndex + 1] * 1.0) / 255.0;
        CGFloat blue  = (rawData[byteIndex + 2] * 1.0) / 255.0;
        CGFloat alpha = (rawData[byteIndex + 3] * 1.0) / 255.0;
        byteIndex += bytesPerPixel;
        
        UIColor *acolor = [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
        [result addObject:acolor];
    }
    
    free(rawData);
    
    return result;
}

#pragma mark - Cleanup Methods
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
