//
//  ViewModel.m
//  Prudential
//
//  Created by Jeames Gillett on 9/5/18.
//

#import "ViewModel.h"
#import <Cordova/CDV.h>
@import ModelIO;
@import SceneKit;
@import SceneKit.ModelIO;
@import Metal;

#define DEFAULT_SCALE                                   0.95
#define DEFAULT_BACKGROUND_COLOR                        [UIColor clearColor]
#define LIGHT_COLOR_NON_MTL_DEVICE                      [UIColor whiteColor]
#define LIGHT_COLOR_MTL_LESS_THAN_OR_EQUAL_TO_IOS10     [UIColor colorWithWhite:0.1 alpha:1.0]
#define AMBIENT_COLOR_MTL_LESS_THAN_OR_EQUAL_TO_IOS10   [UIColor colorWithWhite:0.4 alpha:1.0]
#define SPECULAR_COLOR_MTL_LESS_THAN_OR_EQUAL_TO_IOS10  [UIColor colorWithWhite:0.4 alpha:1.0]
#define LIGHT_1_COLOR_MTL                               [UIColor colorWithWhite:0.7 alpha:1.0]
#define LIGHT_2_COLOR_MTL                               [UIColor colorWithWhite:0.9 alpha:1.0]
#define AMBIENT_COLOR_MTL                               [UIColor colorWithWhite:0.0 alpha:1.0]
#define SPECULAR_COLOR_MTL                              [UIColor colorWithWhite:0.9 alpha:1.0]

@interface ViewModel ()
@property (weak, nonatomic) IBOutlet SCNView *meshView;
@property (weak, nonatomic) IBOutlet UILabel *measurementDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementHeightLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementWeightLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementChestLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementWaistLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementHipLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementInseamLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementThighLabel;
@property (weak, nonatomic) IBOutlet UILabel *measurementGenderLabel;
// OPTIONAL: MyFiziqSDK provides a single class interface. This property is simply a convenience to keep code tidy.
@property (nonatomic, readonly) MyFiziqSDK *myfiziq;
// OPTIONAL: The avatar result to show.
@property (nonatomic, strong) MyFiziqAvatar *avatarResult;
// OPTIONAL: Gesture recognizers to allow user interaction with the avatar mesh.
@property (strong, nonatomic) UIPanGestureRecognizer *gestureRotationRecognizer;
@property (strong, nonatomic) UIPinchGestureRecognizer *gestureZoomRecognizer;
@property (weak, nonatomic) SCNNode *meshNode;
// NOTE: Attempt to get Apple Metal device to determine rendering mode (dependent on device support).
@property (strong, nonatomic) id<MTLDevice> metalDevice;
// OPTIONAL: The following properties handle the mesh orientation and zoom state.
@property (assign, nonatomic) CGFloat meshCurrentAngle;
@property (assign, nonatomic) CGFloat meshCurrentScale;
@property (assign, nonatomic) SCNVector3 meshCurrentTranslation;
@property (assign, nonatomic) BOOL meshIsBeingRotated;
@property (assign, nonatomic) BOOL meshIsBeingZoomed;
@property (assign, nonatomic) BOOL meshIsBeingMoved;
@end

@implementation ViewModel

- (void)viewDidLoad {
    [super viewDidLoad];
    // OPTIONAL: SceneKit rendering properties to lessen the aliasing (aka Jaggies) effect.
    self.meshView.backgroundColor = [UIColor whiteColor];
    self.meshView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    // OPTIONAL: Disable auto lighting, as custom lighting rig will be set when the mesh is loaded.
    self.meshView.autoenablesDefaultLighting = NO;
    // OPTIONAL: Add the gesture recognizers for user interaction with the mesh view. This also instantiates the gestures.
    [self.meshView addGestureRecognizer:self.gestureRotationRecognizer];
    [self.meshView addGestureRecognizer:self.gestureZoomRecognizer];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self clearPresentation];
}

-(void)viewDidAppear:(BOOL)animated {
    [self loadMesh];
}

- (void)clearPresentation {
    [self.meshView setScene:nil];
}

- (UIPanGestureRecognizer *)gestureRotationRecognizer {
    if (!_gestureRotationRecognizer) {
        _gestureRotationRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(meshHandlePan:)];
        _gestureRotationRecognizer.maximumNumberOfTouches = 2;
        _gestureRotationRecognizer.delaysTouchesBegan = NO;
        _gestureRotationRecognizer.cancelsTouchesInView = NO;
    }
    return _gestureRotationRecognizer;
}

- (UIPinchGestureRecognizer *)gestureZoomRecognizer {
    if (!_gestureZoomRecognizer) {
        _gestureZoomRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(meshHandlePinch:)];
        _gestureZoomRecognizer.delaysTouchesBegan = NO;
        _gestureZoomRecognizer.cancelsTouchesInView = NO;
    }
    return _gestureZoomRecognizer;
}

- (id<MTLDevice>)metalDevice {
    if (!_metalDevice) {
        _metalDevice = MTLCreateSystemDefaultDevice();
    }
    return _metalDevice;
}

- (void)meshHandlePan:(UIPanGestureRecognizer *)panRecognizer {
    // NOTE: Determine gesture translation and mesh translation state.
    CGPoint gestureTranslation = [panRecognizer translationInView:self.meshView];
    CGFloat newAngle = gestureTranslation.x*(M_PI)/180.0 + self.meshCurrentAngle;
    SCNVector3 originTranslation = [self.meshView projectPoint:SCNVector3Zero];
    SCNVector3 deltaTranslation = [self.meshView unprojectPoint:SCNVector3Make(originTranslation.x + gestureTranslation.x,
                                                                               originTranslation.y + gestureTranslation.y,
                                                                               originTranslation.z)];
    // NOTE: For single touch panning, rotate the mesh.
    if (panRecognizer == self.gestureRotationRecognizer && panRecognizer.numberOfTouches == 1) {
        if ([panRecognizer state] == UIGestureRecognizerStateBegan) {
            self.meshIsBeingRotated = YES;
        }
        if (self.meshIsBeingRotated && !self.meshIsBeingMoved && !self.meshIsBeingZoomed) {
            self.meshNode.transform = SCNMatrix4Translate(
                                                          SCNMatrix4Scale(
                                                                          SCNMatrix4MakeRotation(newAngle, 0.0f, 1.0f, 0.0f),
                                                                          self.meshCurrentScale, self.meshCurrentScale, self.meshCurrentScale),
                                                          self.meshCurrentTranslation.x,
                                                          self.meshCurrentTranslation.y,
                                                          self.meshCurrentTranslation.z);
        }
        // NOTE: For two finger touch panning, reposition the mesh.
    } else if (panRecognizer == self.gestureRotationRecognizer && panRecognizer.numberOfTouches == 2) {
        if ([panRecognizer state] == UIGestureRecognizerStateBegan) {
            self.meshIsBeingMoved = YES;
        }
        if (self.meshIsBeingMoved && !self.meshIsBeingRotated && !self.meshIsBeingZoomed) {
            self.meshNode.transform = SCNMatrix4Translate(
                                                          SCNMatrix4Scale(
                                                                          SCNMatrix4MakeRotation(self.meshCurrentAngle, 0.0f, 1.0f, 0.0f),
                                                                          self.meshCurrentScale, self.meshCurrentScale, self.meshCurrentScale),
                                                          self.meshCurrentTranslation.x + deltaTranslation.x,
                                                          self.meshCurrentTranslation.y + deltaTranslation.y,
                                                          self.meshCurrentTranslation.z + deltaTranslation.z);
        }
    }
    // NOTE: End gesture response.
    if ([panRecognizer state] == UIGestureRecognizerStateEnded || [panRecognizer state] == UIGestureRecognizerStateCancelled) {
        if (self.meshIsBeingRotated) {
            self.meshCurrentAngle = newAngle;
        }
        if (self.meshIsBeingMoved) {
            _meshCurrentTranslation.x += deltaTranslation.x;
            _meshCurrentTranslation.y += deltaTranslation.y;
            _meshCurrentTranslation.z += deltaTranslation.z;
        }
        self.meshIsBeingMoved = NO;
        self.meshIsBeingRotated = NO;
        self.meshIsBeingZoomed = NO;
    }
}

/*
 OPTIONAL: The following handles mesh interaction for pinch gesture to cause the mesh scale, giving a zoom effect.
 */
- (void)meshHandlePinch:(UIPinchGestureRecognizer *)pinchRecognizer {
    // NOTE: Determine current and intended state.
    CGFloat zoom = pinchRecognizer.scale;
    CGFloat newScale = self.meshCurrentScale * zoom;
    CGFloat curCenterY = self.meshView.bounds.size.height * self.meshCurrentScale * 0.5f;
    CGFloat newCenterY = self.meshView.bounds.size.height * newScale * 0.5f;
    SCNVector3 originTranslation = [self.meshView projectPoint:SCNVector3Zero];
    SCNVector3 deltaTranslation = [self.meshView unprojectPoint:SCNVector3Make(originTranslation.x,
                                                                               originTranslation.y + newCenterY - curCenterY,
                                                                               originTranslation.z)];
    // NOTE: Zoom if pinch gesture is in effect with two fingers.
    if (pinchRecognizer == self.gestureZoomRecognizer && pinchRecognizer.numberOfTouches == 2) {
        if ([pinchRecognizer state] == UIGestureRecognizerStateBegan) {
            self.meshIsBeingZoomed = YES;
        }
        if (self.meshIsBeingZoomed && !self.meshIsBeingRotated && !self.meshIsBeingMoved) {
            self.meshNode.transform = SCNMatrix4Translate(
                                                          SCNMatrix4Scale(
                                                                          SCNMatrix4MakeRotation(self.meshCurrentAngle, 0.0f, 1.0f, 0.0f),
                                                                          newScale, newScale, newScale),
                                                          self.meshCurrentTranslation.x,
                                                          self.meshCurrentTranslation.y + deltaTranslation.y,
                                                          self.meshCurrentTranslation.z);
        }
    }
    // NOTE: End gesture response.
    if ([pinchRecognizer state] == UIGestureRecognizerStateEnded || [pinchRecognizer state] == UIGestureRecognizerStateCancelled) {
        if (self.meshIsBeingZoomed) {
            self.meshCurrentScale = newScale;
            _meshCurrentTranslation.y += deltaTranslation.y;
        }
        self.meshIsBeingMoved = NO;
        self.meshIsBeingRotated = NO;
        self.meshIsBeingZoomed = NO;
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)backToRoot:(id)sender {
    NSLog(@"test button");
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)setAvatar:(MyFiziqAvatar *)avatar {
    // NOTE: Check avatar passed in is valid for rendering.
    if (!avatar || avatar.state != kMFZAvatarStateCompleted) {
        return NO;
    }
    self.avatarResult = avatar;
    return YES;
}

- (void)loadMesh {
    __block UIAlertController *alert = [[UIAlertController alloc] init];
    alert.title = @"Loading...";
    // NOTE: Check avatar to show has been set.
    if (!self.avatarResult) {
        NSLog(@"ERROR: No avatar result not set for display.");
        alert.title = @"Error";
        alert.message = @"Unable to load avatar. Please contact support.";
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction * _Nonnull action) {
//                                                             [self backButtonTap:self];
                                                         }];
        [alert addAction:okAction];
        [self showViewController:alert sender:self];
        return;
    }
    [self showMeshWithCompletion:^(NSError *err) {
        if (err) {
            NSLog(@"ERROR: Failed to show the avatar mesh.");
            alert.title = @"Error";
            alert.message = @"Unable to display the avatar. Please contact support.";
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * _Nonnull action) {
                                                                 //                                                                     [self backButtonTap:self];
                                                             }];
            [alert addAction:okAction];
            [self showViewController:alert sender:self];
        } else {
            //                [self loadMeasurements];
        }
    }];
}

- (void)showMeshWithCompletion:(void (^)(NSError *))completionBlock {
    // NOTE: Check that the mesh file is available.
    NSError *err;
    if (!self.avatarResult || !self.avatarResult.meshCachedFile || ![self.avatarResult.meshCachedFile isFileURL]
        || ![self.avatarResult.meshCachedFile checkResourceIsReachableAndReturnError:&err]) {
        NSLog(@"ERROR: No avatar mesh file downloaded.");
        if (completionBlock) {
            completionBlock([NSError errorWithDomain:@"com.myfiziq" code:-10 userInfo:nil]);
        }
        return;
    }
    // NOTE: Check if native SceneKit version of mesh file exists (from prior load), otherwise convert the WaveFront OBJ
    // mesh file to the native SceneKit format using ModelIO. As ModelIO demands a lot of memory when converting the
    // mesh file, it is recommended that the resulting SceneKit mesh be saved to app cache so that the conversion only
    // needs to be done once per avatar result.
    // OPTIONAL: The SceneKit mesh file will be stored in the same cache directory as the downloaded OBJ file, but the
    // SceneKit mesh file can be saved anywhere.
    NSURL *parentDirectory = [self.avatarResult.meshCachedFile URLByDeletingLastPathComponent];
    NSString *fileNameWithExtension = self.avatarResult.meshCachedFile.lastPathComponent;
    NSString *fileName = [fileNameWithExtension stringByDeletingPathExtension];
    NSString *scnFileName = [NSString stringWithFormat:@"%@.%@", fileName, @"scn"];
    NSURL *scnFile = [NSURL URLWithString:scnFileName relativeToURL:parentDirectory];
    // NOTE: Check if mesh previously converted. Otherwise, convert the mesh using ModelIO.
    if (![scnFile isFileURL] || ![scnFile checkResourceIsReachableAndReturnError:&err]) {
        // NOTE: ModelIO can sometimes throw an exception during the conversion, which should be hndled safely.
        @try {
            // NOTE: Load the mesh using ModelIO and create scene using the imported asset.
            MDLAsset *mdl = [[MDLAsset alloc] initWithURL:self.avatarResult.meshCachedFile];
            MDLMesh *mesh = (MDLMesh*)[mdl objectAtIndex:0];
            // NOTE: The OBJ mesh file does not contain lighting normals, which need to be computed for SceneKit to
            // render the mesh with appropriate lighting.
            [mesh addNormalsWithAttributeNamed:MDLVertexAttributeNormal creaseThreshold:0.2f];
            SCNScene *scnMdl = [SCNScene sceneWithMDLAsset:mdl];
            [scnMdl writeToURL:scnFile options:nil delegate:nil progressHandler:nil];
        } @catch (NSException *exception) {
            NSLog(@"ERROR: ModelIO threw an exception during mesh conversion.");
        }
    }
    // NOTE: With the native SceneKit version of the mesh file present, construct the scene for rendering.
    SCNScene *scene;
    if ([scnFile isFileURL] || [scnFile checkResourceIsReachableAndReturnError:&err]) {
        scene = [SCNScene sceneWithURL:scnFile options:nil error:&err];
    } else {
        NSLog(@"ERROR: Native SceneKit mesh file not found. Error may have occurred when attempting to convert the OBJ file.");
        if (completionBlock) {
            completionBlock([NSError errorWithDomain:@"com.myfiziq" code:-11 userInfo:nil]);
        }
        return;
    }
    // NOTE: Check that the scene was constructed.
    if (!scene) {
        NSLog(@"ERROR: Scene not constructed. Mesh file might be corrupt.");
        if (completionBlock) {
            completionBlock([NSError errorWithDomain:@"com.myfiziq" code:-12 userInfo:nil]);
        }
        return;
    }
    // NOTE: Ready to rig model and lighting. As non-Metal capable device tends to render slightly different to Metal
    // capable device, the lighting profiles are slight different so that the end result is similar, regardless of
    // device used.
    self.meshNode = scene.rootNode.childNodes.firstObject;
    self.meshCurrentAngle = 0.0f;
    self.meshCurrentScale = 1.0f;
    _meshCurrentTranslation = SCNVector3Make(0.0f, 0.05f, 0.0f);
    SCNMaterial *avatarMaterial = self.meshNode.geometry.firstMaterial;
    SCNNode *lightNode1 = [SCNNode node];
    SCNNode *lightNode2 = [SCNNode node];
    if (self.metalDevice && [[[UIDevice currentDevice] systemVersion] intValue] <= 10) {
        // NOTE: iOS 10 and below has a lighting bug, so unique lighting profile used as a work around.
        avatarMaterial.diffuse.contents = AMBIENT_COLOR_MTL_LESS_THAN_OR_EQUAL_TO_IOS10;
        avatarMaterial.specular.contents = SPECULAR_COLOR_MTL_LESS_THAN_OR_EQUAL_TO_IOS10;
        lightNode1.position = SCNVector3Make(0.2, 1, 1);
        lightNode1.light = [SCNLight light];
        lightNode1.light.type = SCNLightTypeOmni;
        lightNode1.light.color = LIGHT_COLOR_MTL_LESS_THAN_OR_EQUAL_TO_IOS10;
        lightNode1.light.zFar = 500.0f;
        lightNode1.light.zNear = 0.025f;
        [scene.rootNode addChildNode:lightNode1];
    } else if (self.metalDevice) {
        // NOTE: iOS 11+ fixed the lighting issue.
        avatarMaterial.diffuse.contents = AMBIENT_COLOR_MTL;
        avatarMaterial.specular.contents = SPECULAR_COLOR_MTL;
        lightNode1.position = SCNVector3Make(0.2, 1, 20);
        lightNode1.light = [SCNLight light];
        lightNode1.light.type = SCNLightTypeOmni;
        lightNode1.light.color = LIGHT_1_COLOR_MTL;
        lightNode1.light.zFar = 500.0f;
        lightNode1.light.zNear = 0.025f;
        [scene.rootNode addChildNode:lightNode1];
        lightNode2.position = SCNVector3Make(0.2, 3, 1);
        lightNode2.light = [SCNLight light];
        lightNode2.light.type = SCNLightTypeOmni;
        lightNode2.light.color = LIGHT_2_COLOR_MTL;
        lightNode2.light.zFar = 500.0f;
        lightNode2.light.zNear = 0.025f;
        [scene.rootNode addChildNode:lightNode2];
    } else {
        // NOTE: Non-metal capable device lighting (it uses OpenGL).
        lightNode1.position = SCNVector3Make(0.2, 1, 1);
        lightNode1.light = [SCNLight light];
        lightNode1.light.type = SCNLightTypeOmni;
        lightNode1.light.color = LIGHT_COLOR_NON_MTL_DEVICE;
        lightNode1.light.zFar = 500.0f;
        lightNode1.light.zNear = 0.025f;
        [scene.rootNode addChildNode:lightNode1];
    }
    // NOTE: Apply the SceneKit scene to the view, effectively rendering the mesh. Animate to the initial position.
    [self.meshView setScene:scene];
    [self animateMeshToInitialPerspective];
    if (completionBlock) {
        completionBlock(nil);
    }
}

- (void)animateMeshToInitialPerspective {
    if (self.meshNode) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            // NOTE: A scale of 1.0 sometimes cut off the head for tall avatars, so reduce slightly.
            CGFloat initScale = DEFAULT_SCALE;
            SCNVector3 initTranslation = SCNVector3Make(0.0f, 0.05f, 0.0f);
            // NOTE: Block user interaction until the animation has completed.
            self.meshIsBeingMoved = YES;
            self.meshIsBeingRotated = YES;
            self.meshIsBeingZoomed = YES;
            [self.meshNode removeAllActions];
            // NOTE: Animate the mesh.
            [self.meshNode runAction:[SCNAction moveTo:initTranslation duration:0.3f] completionHandler:^{
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    _meshCurrentTranslation = SCNVector3Make(0.0f, 0.05f, 0.0f);
                    self.meshIsBeingMoved = NO;
                }];
            }];
            [self.meshNode runAction:[SCNAction scaleTo:initScale duration:0.3f] completionHandler:^{
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    self.meshCurrentScale = DEFAULT_SCALE;
                    self.meshIsBeingZoomed = NO;
                }];
            }];
            [self.meshNode runAction:[SCNAction rotateToX:0 y:0 z:0 duration:0.3f shortestUnitArc:YES] completionHandler:^{
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    self.meshCurrentAngle = 0.0f;
                    self.meshIsBeingRotated = NO;
                }];
            }];
        }];
    }
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
