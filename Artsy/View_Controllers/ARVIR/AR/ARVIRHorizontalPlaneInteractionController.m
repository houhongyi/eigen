@import OpenGLES;
@import ARKit;
@import SceneKit;

#import "ARDefaults.h"
#import "ARSCNWallNode.h"
#import "SCNArtworkNode.h"
#import "ARAugmentedRealityConfig.h"
#import "ARVIRHorizontalPlaneInteractionController.h"
#import "ARDispatchManager.h"

typedef NS_ENUM(NSInteger, ARHorizontalVIRMode) {
    ARHorizontalVIRModeLaunching,
    ARHorizontalVIRModeDetectedFloor,
    ARHorizontalVIRModePlacedOnWall
};

API_AVAILABLE(ios(11.0))
@interface ARVIRHorizontalPlaneInteractionController()
@property (nonatomic, weak) ARSession *session;
@property (nonatomic, weak) ARSCNView *sceneView;
@property (nonatomic, weak) id <ARVIRDelegate> delegate;
@property (nonatomic, strong) ARAugmentedRealityConfig *config;

@property (nonatomic, assign) ARHorizontalVIRMode state;

@property (nonatomic, strong) NSArray<SCNNode *> *detectedPlanes;
@property (nonatomic, strong) NSArray<SCNNode *> *invisibleFloors;

// The clipped line of the wall while you are setting up
@property (nonatomic, strong) SCNNode *ghostWallLine;
// The full version of the wall which you fire an artwork at
@property (nonatomic, strong) SCNNode *wall;

// The final version of the artwork shown on a wall
@property (nonatomic, strong) SCNNode *artwork;
// The WIP version of the artwork placed on the `wall` above
@property (nonatomic, strong) SCNNode *ghostArtwork;


@property (nonatomic, assign) BOOL hasSentRegisteredCallback;
@property (nonatomic, assign) CGPoint pointOnScreenForArtworkProjection;
@end

NSInteger attempt = 0;

@implementation ARVIRHorizontalPlaneInteractionController

- (instancetype)initWithSession:(ARSession *)session config:(ARAugmentedRealityConfig *)config scene:(ARSCNView *)scene delegate:(id <ARVIRDelegate>)delegate
{
    self = [super init];
    _session = session;
    _sceneView = scene;
    _config = config;

    _invisibleFloors = @[];
    _detectedPlanes = @[];

    _delegate = delegate;

    CGRect bounds = [UIScreen mainScreen].bounds;
    _pointOnScreenForArtworkProjection = CGPointMake(bounds.size.width/2, bounds.size.height/2);
    return self;
}

- (void)setState:(ARHorizontalVIRMode)state
{
    _state = state;

    // Also handle vibrations on state changes
    switch (state) {
        case ARHorizontalVIRModeLaunching:
            break;
        case ARHorizontalVIRModeDetectedFloor:
            [self fadeOutAndPresentTheLine];
            [self vibrate:UIImpactFeedbackStyleLight];
            break;
        case ARHorizontalVIRModePlacedOnWall:
            [self vibrate:UIImpactFeedbackStyleHeavy];
            break;
    }
}

- (void)vibrate:(UIImpactFeedbackStyle)style
{
    ar_dispatch_main_queue(^{
        UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [impact prepare];
        [impact impactOccurred];
    });
}

- (void)pannedOnScreen:(UIPanGestureRecognizer *)gesture;
{
    if (gesture.numberOfTouches) {
        self.pointOnScreenForArtworkProjection = [gesture locationOfTouch:0 inView:gesture.view];
    }
}

- (void)tappedOnScreen:(UITapGestureRecognizer *)gesture
{
    // NOOP
    attempt++;
    NSLog(@"Attempt: %@", @(attempt));
}

- (void)placeArtwork
{
    if (@available(iOS 11.0, *)) {
        NSDictionary *options = @{
            SCNHitTestIgnoreHiddenNodesKey: @NO,
            SCNHitTestFirstFoundOnlyKey: @YES,
            SCNHitTestOptionSearchMode: @(SCNHitTestSearchModeAll)
        };

        NSArray <SCNHitTestResult *> *results = [self.sceneView hitTest:self.pointOnScreenForArtworkProjection options: options];
        for (SCNHitTestResult *result in results) {

            // When you want to place down an Artwork
            if ([result.node isEqual:self.wall]) {
                SCNBox *box = [SCNArtworkNode nodeWithConfig:self.config];
                SCNNode *artwork = [SCNNode nodeWithGeometry:box];
                artwork.position = result.localCoordinates;
                // Pitch, Yaw, Roll
//                artwork.eulerAngles = SCNVector3Make(0, 0, M_PI);

                [result.node addChildNode:artwork];

                self.artwork = artwork;
                [self.ghostWallLine removeFromParentNode];
                return;
            }

            // When you want to place the invisible wall, based on the current ghostWall
            if (!self.wall && [self.invisibleFloors containsObject:result.node]) {
                // TODO moved to the runtime

                ARSCNWallNode *wall = [ARSCNWallNode fullWallNode];
                SCNNode *userWall = [SCNNode nodeWithGeometry:wall];
                userWall.position = SCNVector3Make(
                                                   result.localCoordinates.x,
                                                   result.localCoordinates.y,
                                                   result.localCoordinates.z + wall.height/2
                                                   );

                userWall.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);
                [result.node addChildNode: userWall];


                self.wall = userWall;

//                SCNNode *targetNode = [SCNNode node];
//                targetNode.position = self.sceneView.pointOfView.position;
//                [self.sceneView.scene.rootNode addChildNode:targetNode];

                SCNLookAtConstraint *lookAtCamera = [SCNLookAtConstraint lookAtConstraintWithTarget:self.sceneView.pointOfView];
                lookAtCamera.gimbalLockEnabled = YES;
                userWall.constraints = @[lookAtCamera];
            }
        }
    }
}

- (void)restart
{
    [self.ghostWallLine removeFromParentNode];
    self.ghostWallLine = nil;

    [self.wall removeFromParentNode];
    self.wall = nil;

    [self.artwork removeFromParentNode];
    self.artwork = nil;
}

SCNNode *ARPointCloudNode = nil;

- (void)fadeOutAndPresentTheLine
{
    SCNAction *fade = [SCNAction fadeInWithDuration: 0.3];
    [ARPointCloudNode runAction:fade completionHandler:^{
        [ARPointCloudNode removeFromParentNode];
        ARPointCloudNode = nil;
    }];
}


- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame API_AVAILABLE(ios(11.0));
{
    NSInteger pointCount = frame.rawFeaturePoints.count;
    if (pointCount && self.state == ARHorizontalVIRModeLaunching) {
        // We want a root node to work in, it's going to hold the all of the represented spheres
        // that come together to make the point cloud
        if (!ARPointCloudNode) {
            ARPointCloudNode = [SCNNode node];
            [self.sceneView.scene.rootNode addChildNode:ARPointCloudNode];
        }

        // It's going to need some colour
        SCNMaterial *whiteMaterial = [SCNMaterial material];
        whiteMaterial.diffuse.contents = [UIColor whiteColor];
        whiteMaterial.locksAmbientWithDiffuse = YES;

        // Remove the old point clouds (this happens per-frame
        for (SCNNode *child in ARPointCloudNode.childNodes) {
            [child removeFromParentNode];
        }

        // Use the frames point cloud to create a set of SCNSpheres
        // which live at the feature point in the AR world
        for (NSInteger i = 0; i < pointCount; i++) {
            vector_float3 point = frame.rawFeaturePoints.points[i];
            SCNVector3 vector = SCNVector3Make(point[0], point[1], point[2]);

            SCNSphere *pointSphere = [SCNSphere sphereWithRadius:0.004];
            pointSphere.materials = @[whiteMaterial];

            SCNNode *pointNode = [SCNNode nodeWithGeometry:pointSphere];
            pointNode.position = vector;

            [ARPointCloudNode addChildNode:pointNode];
        }
    }

    // Bail early if we don't have walls to fire at, or have an artwork already up
    if (!self.invisibleFloors.count || self.artwork) {
        return;
    }

    NSDictionary *options = @{
        SCNHitTestIgnoreHiddenNodesKey: @NO,
        SCNHitTestFirstFoundOnlyKey: @YES,
        SCNHitTestOptionSearchMode: @(SCNHitTestSearchModeAll),
        SCNHitTestBackFaceCullingKey: @NO
    };

    NSArray <SCNHitTestResult *> *results = [self.sceneView hitTest:self.pointOnScreenForArtworkProjection options: options];
    for (SCNHitTestResult *result in results) {
        
        if ([self.wall isEqual:result.node]) {
            // Create a ghost artwork
            if (!self.ghostArtwork) {
                // TODO add white lines around the artwork

                SCNBox *box = [SCNArtworkNode nodeWithConfig:self.config];
                SCNNode *artwork = [SCNNode nodeWithGeometry:box];
                artwork.position = result.localCoordinates;
                // Pitch, Yaw, Roll
//                artwork.eulerAngles = SCNVector3Make(0, 0, M_PI);
                artwork.opacity = 0.5;

                [result.node addChildNode:artwork];
                self.ghostArtwork = artwork;
            }
            self.ghostArtwork.position = result.localCoordinates;
        }

        if ([self.invisibleFloors containsObject:result.node]) {
            // Create a ghost wall if we don't have one already
            if (!self.ghostWallLine) {
                ARSCNWallNode *ghostBox = [ARSCNWallNode shortWallNode];
                SCNNode *ghostWall = [SCNNode nodeWithGeometry:ghostBox];
                ghostWall.opacity = 0.80;

                [result.node addChildNode:ghostWall];

                SCNLookAtConstraint *lookAtCamera = [SCNLookAtConstraint lookAtConstraintWithTarget:self.sceneView.pointOfView];
                lookAtCamera.gimbalLockEnabled = YES;
                ghostWall.constraints = @[lookAtCamera];


                self.ghostWallLine = ghostWall;
            }

            if(!self.wall) {
                ARSCNWallNode *wall = [ARSCNWallNode fullWallNode];
                SCNNode *userWall = [SCNNode nodeWithGeometry:wall];
                userWall.position = SCNVector3Make(
                   result.localCoordinates.x,
                   result.localCoordinates.y,
                   result.localCoordinates.z + wall.height/2
                   );

//            userWall.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);
            [result.node addChildNode: userWall];


            self.wall = userWall;

            SCNLookAtConstraint *lookAtCamera = [SCNLookAtConstraint lookAtConstraintWithTarget:self.sceneView.pointOfView];
            lookAtCamera.gimbalLockEnabled = YES;
            userWall.constraints = @[lookAtCamera];

//            [self.ghostWallLine removeFromParentNode];
//            self.ghostWallLine = nil;
            }

//
//            SCNNode *targetNode = [SCNNode node];
//            targetNode.position = self.sceneView.pointOfView.position;
//            [self.sceneView.scene.rootNode addChildNode:targetNode];

//            SCNLookAtConstraint *lookAtCamera = [SCNLookAtConstraint lookAtConstraintWithTarget:targetNode];
//            lookAtCamera.gimbalLockEnabled = YES;
//            //                lookAtCamera.localFront = SCNVector3Make(0, 1, 0);
//            lookAtCamera.localFront = [SCNNode localUp  ];
//            self.wall.constraints = @[lookAtCamera];



            self.wall.position = SCNVector3Make(
               result.localCoordinates.x,
               result.localCoordinates.y,
               result.localCoordinates.z // + self.wall.height/2
           );


            self.wall.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);




            //                targetNode.position = self.sceneView.session.currentFrame.camera;

            // While the positioning of some of this is still unpredictable, I'd like to keep my
            // notes and other attempts around while I figure out some of the details

            // Try clone the node

            //                SCNNode *wall = [self.ghostWall clone];
            //                wall.constraints = @[];
            //                [wall lookAt:self.sceneView.pointOfView.worldPosition];
            //                [result.node.parentNode addChildNode:wall];
            //
            //                SCNNode *staticCameraReference = [self.sceneView.pointOfView copy];
            //                [self.sceneView.pointOfView.parentNode addChildNode:staticCameraReference];

            // Pitch, Yaw, Roll
            //
            //                SCNLookAtConstraint *lookAtCamera = [SCNLookAtConstraint lookAtConstraintWithTarget:staticCameraReference];
            //                lookAtCamera.gimbalLockEnabled = YES;
            //                userWall.constraints = @[lookAtCamera];
            //

            // When adding as a child node and setting the same as the ghost

            //                [result.node addChildNode: userWall];
            //                userWall.position = self.ghostWall.position;


            //                userWall.transform = self.ghostWall.transform;
            //                userWall.orientation = self.ghostWall.orientation;
            //                userWall.eulerAngles = self.ghostWall.eulerAngles;
            //                userWall.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);
            //
            //
            //                userWall.position = SCNVector3Make(
            //                 self.ghostWall.position.x,
            //                 self.ghostWall.position.y + wall.height,
            //                 self.ghostWall.position.z
            //               );
            //
            //                permenentWall.worldTransform = self.ghostWall.worldTransform;
            //                [userWall lookAt:self.sceneView.pointOfView.worldPosition];
            //                userWall.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);
            //
            //                permenentWall.eulerAngles = self.ghostWall.eulerAngles;
            //                permenentWall.rotation = self.ghostWall.world;
            //
            //                [self.sceneView.scene.rootNode addChildNode:userWall];



            /**
             The camera’s orientation defined as Euler angles.

             @dicussion The order of components in this vector matches the axes of rotation:
             1. Pitch (the x component) is the rotation about the node’s x-axis (in radians)
             2. Yaw   (the y component) is the rotation about the node’s y-axis (in radians)
             3. Roll  (the z component) is the rotation about the node’s z-axis (in radians)
             ARKit applies these rotations in the reverse order of the components:
             1. first roll
             2. then yaw
             3. then pitch
             */

            //                ghostWall.rotation = self.sceneView.session.currentFrame.camera
//            ARCamera *camera = self.sceneView.session.currentFrame.camera;
//            NSLog(@"V: %f %f %f", camera.eulerAngles[0],camera.eulerAngles[1],camera.eulerAngles[2] );
//            NSLog(@"L: %f %f %f", self.ghostWallLine.orientation.x,self.ghostWallLine.orientation.y, self.ghostWallLine.orientation.z);
//            self.ghostWallLine.eulerAngles = SCNVector3Make(self.sceneView.session.currentFrame.camera.eulerAngles[1], 0, 0);
//            self.ghostWallLine.eulerAngles = SCNVector3FromFloat3(camera.eulerAngles);

            SCNTransaction.animationDuration = 0.1;
            self.ghostWallLine.position = result.localCoordinates;
            [self.delegate isShowingGhostWork:YES];
            return;
        }
    }

    if (self.ghostWallLine) {
        [self.delegate isShowingGhostWork:NO];
        [self.ghostWallLine removeFromParentNode];
        self.ghostWallLine = nil;
    }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor API_AVAILABLE(ios(11.0))
{
    // Used to update and re-align vertical planes as ARKit sends new updates for the positioning
    if (!anchor) { return; }
    if (![anchor isKindOfClass:ARPlaneAnchor.class]) { return; }

    // We can get some really gnarly jumps of world positioniing  with this version of ARVIR, I had initially
    // assumed this could be fixed

    // Animate instead of jumping positions
    SCNTransaction.animationDuration = 0.1;
    ARPlaneAnchor *planeAnchor = (id)anchor;

    for (SCNNode *planeNode in node.childNodes) {
        SCNPlane *plane = (id)planeNode.geometry;

        if ([self.detectedPlanes containsObject:planeNode]) {
            plane.width = planeAnchor.extent.x;
            plane.height = planeAnchor.extent.z;
            planeNode.position = SCNVector3FromFloat3(planeAnchor.center);
        }

        if ([self.invisibleFloors containsObject:planeNode]) {
            planeNode.position = SCNVector3FromFloat3(planeAnchor.center);
        }
    }
}

- (void)renderer:(id <SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor API_AVAILABLE(ios(11.0));
{
    // Only handle adding plane nodes
    if (!anchor) { return; }
    if (![anchor isKindOfClass:ARPlaneAnchor.class]) { return; }
    if (self.invisibleFloors.count) { return; }

    if (self.state == ARHorizontalVIRModeLaunching){
        self.state = ARHorizontalVIRModeDetectedFloor;
    }

    // Send a callback that we're in a state to attach works
    if (!self.hasSentRegisteredCallback) {
        [self.delegate hasRegisteredPlanes];
        self.hasSentRegisteredCallback = YES;
    }

    // Create an anchor node, which can get moved around as we become more sure of where the
    // plane actually is.
    ARPlaneAnchor *planeAnchor = (id)anchor;
    if (@available(iOS 11.3, *)) {
        if (planeAnchor.alignment == ARPlaneAnchorAlignmentVertical) {
            return;
        }
    } else {
        // Fallback on earlier versions
    }

    SCNNode *planeNode = [self whiteBoxForPlaneAnchor:planeAnchor];
    [node addChildNode:planeNode];

    SCNNode *wallNode = [self invisibleWallNodeForPlaneAnchor:planeAnchor];
    [node addChildNode:wallNode];

    self.invisibleFloors = [self.invisibleFloors arrayByAddingObject:wallNode];
    self.detectedPlanes = [self.detectedPlanes arrayByAddingObject:planeNode];
}

- (SCNNode *)whiteBoxForPlaneAnchor:(ARPlaneAnchor *)planeAnchor API_AVAILABLE(ios(11.0))
{
    SCNPlane *plane = [SCNPlane planeWithWidth:planeAnchor.extent.x height:planeAnchor.extent.z];
    UIColor *planeColor = self.config.debugMode ? [[UIColor whiteColor] colorWithAlphaComponent:0.3] : [UIColor clearColor];
    plane.firstMaterial.diffuse.contents = planeColor;

    SCNNode *planeNode = [SCNNode nodeWithGeometry:plane];
    planeNode.position = SCNVector3Make(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z);
    planeNode.name = @"Detected Area";

//    planeNode.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);
    return planeNode;
}

- (SCNNode *)invisibleWallNodeForPlaneAnchor:(ARPlaneAnchor *)planeAnchor API_AVAILABLE(ios(11.0))
{
    SCNPlane *hiddenPlane = [SCNPlane planeWithWidth:64 height:64];

    UIColor *planeColor = self.config.debugMode ? [UIColor colorWithRed:0.410 green:0.000 blue:0.775 alpha:0.50] : [UIColor clearColor];

    hiddenPlane.materials.firstObject.diffuse.contents = planeColor;

    SCNNode *hittablePlane = [SCNNode nodeWithGeometry:hiddenPlane];

    SCNVector3 wallCenter = SCNVector3FromFloat3(planeAnchor.center);
    // As we're creating a wall, we want it to be raised higher than it would be lower.
    // E.g. a wall goes more "up" than "down" from the planes y center point
//    wallCenter.y -= 5 * 0.8;
    // The plane will always be a *tiny* bit infront of the wall, so offset a bit
//    wallCenter.x -= 0.1;
    hittablePlane.position = wallCenter;
    hittablePlane.eulerAngles = SCNVector3Make(-M_PI_2, 0, 0);

    return hittablePlane;
}

@end
