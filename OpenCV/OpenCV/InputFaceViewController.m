//
//  InputFaceViewController.m
//  OpenCV
//
//  Created by hty on 2017/12/16.
//  Copyright © 2017年 hantianyu. All rights reserved.
//

#import "InputFaceViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "OpenCVUtils.h"
@interface InputFaceViewController()<AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *detectImageView;
@property (strong, nonatomic) CAShapeLayer *shapeLayer;

@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (strong, nonatomic) AVCapturePhotoOutput *capturePhotoOutput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (weak, nonatomic) IBOutlet UIImageView *testImageView;
@property (strong, nonatomic) NSMutableSet *positonSet;
@property (strong, nonatomic) CIDetector *detector;

@property (weak, nonatomic) IBOutlet UITextField *tfLabel;
@property (weak, nonatomic) IBOutlet UIButton *backButton;

@end

static CGPoint point;
static int countTec;
static int lex = 10;

@implementation InputFaceViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    // 上下文
    CIContext *content = [CIContext contextWithOptions:nil];
    
    // 配置识别质量
    NSDictionary *param = [NSDictionary dictionaryWithObject:CIDetectorAccuracyHigh forKey:CIDetectorAccuracy];
    
    // 创建人脸识别器
    self.detector = [CIDetector detectorOfType:CIDetectorTypeFace context:content options:param];
    point = CGPointZero;
    countTec = 0;
    self.positonSet = [NSMutableSet new];
    //
    _shapeLayer = [CAShapeLayer layer];
    _shapeLayer.frame = _detectImageView.bounds;
    [_detectImageView.layer addSublayer:_shapeLayer];
    _shapeLayer.lineWidth = 1;
    _shapeLayer.strokeColor = [UIColor redColor].CGColor;
    _shapeLayer.fillColor = [UIColor clearColor].CGColor;
    _detectImageView.contentMode = UIViewContentModeCenter;
    _testImageView.contentMode = UIViewContentModeCenter;
    _detectImageView.layer.cornerRadius = 60;
    
    for (int i=1; i<9; i++) {
        UIView *view = [self.view viewWithTag:i];
        view.layer.cornerRadius = 5;
    }
    NSArray *array = [[NSUserDefaults standardUserDefaults] objectForKey:@"labels"];
    self.tfLabel.text =  [NSString stringWithFormat:@"%lu",array.count+1];
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
//    [self.captureSession startRunning];
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

    
    
        UIImage * fixImage =[self fixOrientation:image];
        NSArray *rectArray = [OpenCVUtils facePointDetectForImage:fixImage];
    
        if (rectArray.count > 0) {
            NSLog(@"==");
            for (NSNumber* rectValue in rectArray) {
                CGRect rect = [rectValue CGRectValue];
                CGRect rect1 = CGRectMake(rect.origin.x*fixImage.size.width, rect.origin.y*fixImage.size.height,rect.size.width*fixImage.size.width, rect.size.height*fixImage.size.height);
                
                if (CGRectGetWidth(rect1)<80||CGRectGetHeight(rect1)<80) {
                    proccessing = 0;
                    return;
                }
                int a = [self position:fixImage];
                if (a == -1) {
                    proccessing = 0;
                    return;
                }
                
                if (![self.positonSet containsObject:@(a)]) {
                    dispatch_async(dispatch_get_global_queue(0, 0), ^{
                            [OpenCVUtils inputFace:fixImage rect:rect1 label:[self.tfLabel.text intValue]];//****
                    });
                    [self.positonSet addObject:@(a)];
                    NSLog(@"%d",a);
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIView *view = [self.view viewWithTag:a];
                        view.backgroundColor = [UIColor greenColor];
                    });

                }
    
                if (self.positonSet.count >= 9) {
                    [self dismissViewControllerAnimated:YES completion:nil];
                    NSMutableArray *array = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"labels"]];
                    if (![array containsObject: _tfLabel.text]) {
                        [array addObject:_tfLabel.text];
                        [[NSUserDefaults standardUserDefaults] setObject:array forKey:@"labels"];

                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        UIAlertView *view = [[UIAlertView alloc]initWithTitle:@"录入成功" message:[NSString stringWithFormat:@"label = %@",_tfLabel.text] delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                        [view show];
                    });
                    
                    [OpenCVUtils save];
                    
                    proccessing = 0;
                    return;
                }
                proccessing = 0;
//                UIBezierPath* totalPath = [UIBezierPath bezierPath];
//                UIBezierPath *subpath = [UIBezierPath bezierPathWithRect:[self convertRectFromRect:rect toSize:image.size]];
//                [totalPath appendPath:subpath];
//                __weak __typeof(self) weakSelf = self;
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    weakSelf.shapeLayer.path = totalPath.CGPath;
//                    proccessing = 0;
//                });
            }
        
        
    }else{
        proccessing = 0;
    }

}
- (IBAction)reset:(UIButton *)sender {
    if([[sender titleForState:UIControlStateNormal] isEqualToString:@"开始录入"]){
        [self.captureSession startRunning];
        [sender setTitle:@"停止" forState:UIControlStateNormal];
    }else{
        [self.captureSession stopRunning];
        [sender setTitle:@"开始录入" forState:UIControlStateNormal];

        countTec = 0;
        [self.positonSet removeAllObjects];
        for (int i=1; i<9; i++) {
            UIView *view = [self.view viewWithTag:i];
            view.backgroundColor = [UIColor redColor];
        }
    }
    
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
- (int)position:(UIImage *)image {
    
    
   
    
    // 识别图片
    CIImage *ciImg = [CIImage imageWithCGImage:image.CGImage];
    
    NSDictionary *featuresParam = @{CIDetectorSmile: [NSNumber numberWithBool:true],
                                    CIDetectorEyeBlink: [NSNumber numberWithBool:true]};

    // 获取识别结果
    NSArray *resultArr = [self.detector featuresInImage:ciImg options:featuresParam];
    //67 120
    
    
    for (CIFaceFeature *feature in resultArr) {
        NSLog(@"%f,%f",feature.mouthPosition.x,feature.mouthPosition.y);
        if (!(feature.hasRightEyePosition&&feature.hasLeftEyePosition&&feature.hasMouthPosition&&!feature.leftEyeClosed&&!feature.rightEyeClosed)) {
            return -1;
        }
        int positon = 0;

        if (countTec<5) {
            countTec++;
            point = CGPointMake(feature.mouthPosition.x, feature.mouthPosition.y);
        }
        
        if (feature.mouthPosition.x<point.x-lex) {
            if (feature.mouthPosition.y>point.y+lex) {
                positon = 8;
            }else if(feature.mouthPosition.y<point.y-lex){
                positon = 6;
            }else{
                positon = 7;
            }
        }else if(feature.mouthPosition.x>point.x+lex){
            if (feature.mouthPosition.y>point.y+lex) {
                positon = 2;
            }else if(feature.mouthPosition.y<point.y-lex){
                positon = 4;
            }else{
                positon = 3;
            }
        }else{
            if (feature.mouthPosition.y>point.y+lex) {
                positon = 1;
            }else if(feature.mouthPosition.y<point.y-lex){
                positon = 5;
            }else{
                positon = 0;
            }
        }
        if ([self.positonSet containsObject:@(positon)]) {
            positon = (positon+1)%8;
            if ([self.positonSet containsObject:@(positon)]&&positon>1) {
                positon = (positon-1)%8;
            }
        }
        return positon;

    }
    
    return 0;
}
@end
