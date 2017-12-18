//
//  RecognizeFaceViewController.m
//  OpenCV
//
//  Created by hty on 2017/12/16.
//  Copyright © 2017年 hantianyu. All rights reserved.
//

#import "RecognizeFaceViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "OpenCVUtils.h"
@interface RecognizeFaceViewController()<AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *detectImageView;
@property (strong, nonatomic) CAShapeLayer *shapeLayer;

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (strong, nonatomic) AVCapturePhotoOutput *capturePhotoOutput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (strong, nonatomic) CIDetector *detector;
@property (weak, nonatomic) IBOutlet UILabel *checkPeople;


@property (assign, nonatomic) BOOL checkOpenEyes;
@property (assign, nonatomic) BOOL checkCloseEyes;
@property (assign, nonatomic) int checkTime;
@property (assign, nonatomic) NSString * label;

@end


@implementation RecognizeFaceViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    // 上下文
    CIContext *content = [CIContext contextWithOptions:nil];
    
    /**
     1、识别精度 Detector Accuracy
     
     key: CIDetectorAccuracy
     value: CIDetectorAccuracyLow    低精度识别速度快
     CIDetectorAccuracyHigh   高精度识别速度慢
     */
    /**
     2、识别类型 Detector Types
     
     CIDetectorTypeFace      面部识别
     CIDetectorTypeRectangle 矩形识别
     CIDetectorTypeQRCode    条码识别
     CIDetectorTypeText      文本识别
     */
    /**
     3、 具体特征 Feature Detection
     
     CIDetectorImageOrientation  图片方向
     CIDetectorEyeBlink          识别眨眼（closed eyes）
     CIDetectorSmile             笑脸
     CIDetectorFocalLength       焦距
     CIDetectorAspectRatio       矩形宽高比
     CIDetectorReturnSubFeatures 是否检测子特征
     */
    
    // 配置识别质量
    NSDictionary *param = [NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh forKey:CIDetectorAccuracy];
    
    // 创建人脸识别器
    self.detector = [CIDetector detectorOfType:CIDetectorTypeFace context:content options:param];
    
    //    faceRect  = CGSizeMake(100, 100);
    _shapeLayer = [CAShapeLayer layer];
    _shapeLayer.frame = _detectImageView.bounds;
    [_detectImageView.layer addSublayer:_shapeLayer];
    _shapeLayer.lineWidth = 1;
    _shapeLayer.strokeColor = [UIColor redColor].CGColor;
    _shapeLayer.fillColor = [UIColor clearColor].CGColor;
    _detectImageView.contentMode = UIViewContentModeCenter;
    //
    _captureSession = [[AVCaptureSession alloc] init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }
    AVCaptureDevice *captureDevice = nil;
    // 获取输入设备
    AVCaptureDeviceDiscoverySession *discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
    for (AVCaptureDevice *camera in discoverySession.devices) {
        captureDevice = camera;
    }
    if (!captureDevice) {
        NSLog(@"摄像头获取出现错误");
        return;
    }
    
    // 初始化设备数据输入对象
    NSError *error = nil;
    _captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"设备输入对象获取失败：%@", error.localizedDescription);
        return;
    }
    
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
    }
    
    AVCaptureVideoDataOutput *captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureVideoDataOutput.alwaysDiscardsLateVideoFrames = YES;
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", NULL);
    [captureVideoDataOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary
                                   dictionaryWithObject:value forKey:key];
    [captureVideoDataOutput setVideoSettings:videoSettings];
    if ([_captureSession canAddOutput:captureVideoDataOutput]) {
        [_captureSession addOutput:captureVideoDataOutput];
    }
    
    //
    // 视图预览，实时展示摄像头
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
    
    CALayer *layer = _detectImageView.layer;
    layer.masksToBounds = YES;
    _captureVideoPreviewLayer.frame = layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [layer insertSublayer:_captureVideoPreviewLayer below:_shapeLayer];
}
-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self.captureSession startRunning];
}

-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.captureSession stopRunning];
}
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    static int proccessing = 0;
    if (proccessing) {
        return;
    }
    proccessing = 1;
    
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress,
                                                    width, height, 8, bytesPerRow, colorSpace,
                                                    kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    
    UIImage *image= [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationLeftMirrored];
    
    CGImageRelease(newImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);

    
    
    UIImage *fixImage = [self fixOrientation:image];

    NSArray *rectArray = [OpenCVUtils facePointDetectForImage:fixImage];
    
    
    
    if (rectArray.count > 0) {
        UIBezierPath* totalPath = [UIBezierPath bezierPath];
        for (NSNumber* rectValue in rectArray) {
            CGRect rect = [rectValue CGRectValue];
            CGRect rect1 =CGRectMake(rect.origin.x*fixImage.size.width, rect.origin.y*fixImage.size.height,rect.size.width*fixImage.size.width, rect.size.height*fixImage.size.height);
            if ([self checkBlink:[OpenCVUtils getHandlerImage:fixImage rect:CGRectMake(rect1.origin.x-20, rect1.origin.y-20, rect1.size.width+40, rect1.size.height+40)]]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.checkPeople.text = @"通过";

                });

                NSDictionary *dic = [OpenCVUtils recognizeFaceImages:fixImage rect:rect1];//*****
                self.label = dic[@"label"];
                if ([dic[@"label"] isEqualToString:self.label]&&[dic[@"confidence"] floatValue]>40) {
                    _checkTime ++ ;
                }else{
                    _checkTime =0;
                }
                if (_checkTime ==5) {
                    NSLog(@"result ==%@",self.label);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.label isEqualToString:@"-1"]) {
                            UIAlertView *view = [[UIAlertView alloc]initWithTitle:@"未检测到对应信息" message:[NSString stringWithFormat:@"label = %@",self.label] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                            [view show];
                        }else{
                            UIAlertView *view = [[UIAlertView alloc]initWithTitle:@"解锁成功" message:[NSString stringWithFormat:@"label = %@",self.label] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                            [view show];
                        }
                        [self dismissViewControllerAnimated:YES completion:nil];

                    });
                    
                }
                
            }
            rect = [self convertRectFromRect:rect toSize:image.size];
            UIBezierPath *subpath = [UIBezierPath bezierPathWithRect:rect];
            [totalPath appendPath:subpath];
        }
        
        __weak __typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.shapeLayer.path = totalPath.CGPath;
            proccessing = 0;
        });
    }else{
        proccessing = 0;
    }
    
    //    __weak __typeof(self) weakSelf = self;
    //    dispatch_async(dispatch_get_main_queue(), ^{
    //        weakSelf.resultImage.image = [OpenCVUtil faceDetectForImage:[self fixOrientation:image]];
    //        proccessing = 0;
    //    });
}
- (IBAction)backButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (UIImage *)fixOrientation:(UIImage *)aImage {
    
    // No-op if the orientation is already correct
    if (aImage.imageOrientation == UIImageOrientationUp)
        return aImage;
    
    // We need to calculate the proper transformation to make the image upright.
    // We do it in 2 steps: Rotate if Left/Right/Down, and then flip if Mirrored.
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, aImage.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, aImage.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        default:
            break;
    }
    
    switch (aImage.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, aImage.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        default:
            break;
    }
    
    // Now we draw the underlying CGImage into a new context, applying the transform
    // calculated above.
    CGContextRef ctx = CGBitmapContextCreate(NULL, aImage.size.width, aImage.size.height,
                                             CGImageGetBitsPerComponent(aImage.CGImage), 0,
                                             CGImageGetColorSpace(aImage.CGImage),
                                             CGImageGetBitmapInfo(aImage.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (aImage.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            // Grr...
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.height,aImage.size.width), aImage.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,aImage.size.width,aImage.size.height), aImage.CGImage);
            break;
    }
    
    // And now we just create a new UIImage from the drawing context
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}
- (CGRect)convertRectFromRect:(CGRect)fromRect toSize:(CGSize)size{
    
    //    float scale = size.width/size.height;
    return CGRectMake(_detectImageView.frame.size.width*fromRect.origin.x, _detectImageView.frame.size.height*fromRect.origin.y,fromRect.size.width*_detectImageView.frame.size.width, fromRect.size.height*_detectImageView.frame.size.height);
}
- (BOOL)checkBlink:(UIImage *)image {
    
    if (self.checkOpenEyes&&self.checkCloseEyes)
    {
        return YES;
    }
  
    // 识别图片
    CIImage *ciImg = [CIImage imageWithCGImage:image.CGImage];
    
    // 识别特征: 这里添加了眨眼和微笑
    // CIDetectorSmile 眼部的识别效果很差，很难识别出来
    NSDictionary *featuresParam = @{CIDetectorSmile: [NSNumber numberWithBool:true],
                                    CIDetectorEyeBlink: [NSNumber numberWithBool:true]};
    
    // 获取识别结果
    NSArray *resultArr = [self.detector featuresInImage:ciImg options:featuresParam];
    
    
    
    for (CIFaceFeature *feature in resultArr) {
        if (feature.leftEyeClosed&&feature.rightEyeClosed) {
            self.checkCloseEyes = YES;
        }else if(!(feature.leftEyeClosed&&feature.rightEyeClosed)){
            self.checkOpenEyes = YES;
        }
    }
    return NO;
}


@end

