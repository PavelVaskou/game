/*
     File: APLSpaceScene.m
 Abstract: 
 This is the scene that implements the physics demo. It is responsible for handling keyboard inputs and driving the simulation in response to user input and physics interactions.
 
  Version: 1.2
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import "APLSpaceScene.h"
#import "APLShipSprite.h"

#define RADIANS_TO_DEGREES(radians) ((radians) * (180.0 / M_PI))
#define DEGREES_TO_RADIANS(angle) ((angle) / 180.0 * M_PI)


@interface APLSpaceScene ()
@property BOOL contentCreated;
@property BOOL runEngine;
@property (nonatomic, strong) NSMutableArray* arraywithFrieds;
@property (nonatomic, strong) SKLabelNode* myLabel;
@property APLShipSprite *controlledShip;
@end

// Useful randomizer functions.
static inline CGFloat myRandf() {
    return rand() / (CGFloat) RAND_MAX;
}

static inline CGFloat myRand(CGFloat low, CGFloat high) {
    return myRandf() * (high - low) + low;
}

/* Simulation constants used to tweak  game play. */

// sizes for the various kinds of objects
static const CGFloat shotSize = 4;
static const CGFloat asteroidSize = 18;
static const CGFloat planetSize = 128;

// explosion constants
static const CFTimeInterval missileExplosionDuration = 0.1;

// collison constants
static const CGFloat collisonDamageThreshold = 3.0;

// missile constants
static const NSInteger missileDamage = 1;

@implementation APLSpaceScene

#pragma mark Initialization

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
    
    }
    return self;
}

- (void)didMoveToView:(SKView *)view
{
    if (!self.contentCreated)
    {
        [self createSceneContents];
        self.contentCreated = YES;
    }
}

- (void)createSceneContents
{
    self.backgroundColor = [SKColor blackColor];
    self.scaleMode = SKSceneScaleModeAspectFit;
    
    // Give the scene an edge and configure other physics info on the scene.
    self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
    self.physicsBody.categoryBitMask = edgeCategory;
    self.physicsBody.collisionBitMask = 0;
    self.physicsBody.contactTestBitMask = 0;
    self.physicsWorld.gravity = CGVectorMake(0,0);
    self.physicsWorld.contactDelegate = self;
    
    self.controlledShip = [APLShipSprite shipSprite];
    self.controlledShip.position = CGPointMake (100, 100);
    [self addChild:self.controlledShip];
    

    SKAction *scaleDown = [SKAction rotateByAngle:-M_PI*2 duration:1];
    SKAction *fullScale = [SKAction repeatActionForever:[SKAction sequence:@[scaleDown]]];
    [self.controlledShip runAction:fullScale];

    self.arraywithFrieds = [NSMutableArray array];
    for (int i = 0; i < 10; i++)
    {
        SKNode *rock = [self newAFriendNode];
        
        CGFloat x = arc4random()%500;
        CGFloat y = arc4random()%500;
        rock.position = CGPointMake(x, y);
        rock.name = [NSString stringWithFormat:@"Friend %d", i];
        [self addChild:rock];
        
        [self.arraywithFrieds addObject:rock];
    }
    
    for (int i = 0; i < 10; i++)
    {
        SKNode *rock = [self newEmenyNode];
        rock.name = [NSString stringWithFormat:@"Enemy %d", i];
        
        CGFloat x = arc4random()%500;
        CGFloat y = arc4random()%500;
        rock.position = CGPointMake(x, y);
        [self addChild:rock];
    }
    
    [self setStart];
    
    
    self.myLabel = [SKLabelNode labelNodeWithFontNamed:@"Arial"];
    self.myLabel.text = @"";
    self.myLabel.fontSize = 20;
    self.myLabel.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame) + 200);
    
    [self addChild:self.myLabel];

}

- (void)setStart
{
    self.controlledShip.physicsBody.categoryBitMask = shipCategory;
    self.controlledShip.physicsBody.collisionBitMask =   friendly | edgeCategory;
    self.controlledShip.physicsBody.contactTestBitMask =  friendly | edgeCategory;
    
    SKNode* node = [self.arraywithFrieds objectAtIndex:5];
    
    self.controlledShip.position = node.position;
}

- (SKNode*) newAFriendNode
{
    /* Creates and returns a new asteroid game object.
     
     For this sample, we just use a shape node for the asteroid.
     */
    SKShapeNode *asteroid = [[SKShapeNode alloc] init];
    CGMutablePathRef myPath = CGPathCreateMutable();
    CGPathAddArc(myPath, NULL, 0,0, asteroidSize, 0, M_PI*2, YES);
    asteroid.path = myPath;
    CGPathRelease(myPath);
    asteroid.strokeColor = [SKColor clearColor];
    asteroid.fillColor = [SKColor whiteColor];
    
    asteroid.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:asteroidSize];
    asteroid.physicsBody.categoryBitMask = enemy;
    asteroid.physicsBody.collisionBitMask =  enemy | edgeCategory | friendly;
  //  asteroid.physicsBody.contactTestBitMask = friendly;
    
    return asteroid;
}

- (SKNode*) newEmenyNode
{
    /* Creates and returns a new asteroid game object.
     
     For this sample, we just use a shape node for the asteroid.
     */
    SKShapeNode *asteroid = [[SKShapeNode alloc] init];
    CGMutablePathRef myPath = CGPathCreateMutable();
    CGPathAddArc(myPath, NULL, 0,0, asteroidSize, 0, M_PI*2, YES);
    asteroid.path = myPath;
    CGPathRelease(myPath);
    asteroid.strokeColor = [SKColor clearColor];
    asteroid.fillColor = [SKColor redColor];
    
    asteroid.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:asteroidSize];
    asteroid.physicsBody.categoryBitMask = friendly;
    asteroid.physicsBody.collisionBitMask = shipCategory | enemy | edgeCategory | friendly;
  //  asteroid.physicsBody.contactTestBitMask = friendly;
    
    return asteroid;
}

- (SKEmitterNode*) newExplosionNode: (CFTimeInterval) explosionDuration
{
    SKEmitterNode *emitter =  [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:@"explosion" ofType:@"sks"]];
    
    // Explosions always place their particles into the scene.
    emitter.targetNode = self;
    
    // Stop spawning particles after enough have been spawned.
    emitter.numParticlesToEmit = explosionDuration * emitter.particleBirthRate;
    
    // Calculate a time value that allows all the spawned particles to die. After this, the emitter node can be removed.

    CFTimeInterval totalTime = explosionDuration + emitter.particleLifetime+emitter.particleLifetimeRange/2;
    [emitter runAction:[SKAction sequence:@[[SKAction waitForDuration:totalTime],
                                            [SKAction removeFromParent]]]];
    return emitter;
}

#pragma mark Physics Handling and Game Logic

- (void)detonateMissile:(SKNode *)missile
{
    SKEmitterNode *explosion = [self newExplosionNode: missileExplosionDuration];
    explosion.position = missile.position;
    [self addChild:explosion];
    [missile removeFromParent];
}

- (void) attackTarget: (SKPhysicsBody*) target withMissile: (SKNode*) missile
{
    // Only ships take damage from missiles.
    if ((target.categoryBitMask & shipCategory) != 0)
    {
        APLShipSprite *targetShip = (APLShipSprite*) target.node;
        [targetShip applyDamage:missileDamage];
    }
    
    [self detonateMissile:missile];
}

- (void)didBeginContact:(SKPhysicsContact *)contact
{
    // Handle contacts between two physics bodies.
    
    // Contacts are often a double dispatch problem; the effect you want is based
    // on the type of both bodies in the contact. This sample  solves
    // this in a brute force way, by checking the types of each. A more complicated
    // example might use methods on objects to perform the type checking.
    
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;

    // The contacts can appear in either order, and so normally you'd need to check
    // each against the other. In this example, the category types are well ordered, so
    // the code swaps the two bodies if they are out of order. This allows the code
    // to only test collisions once.
    
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
    {

        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
        
        self.myLabel.text = @"STOP";
        self.runEngine = NO;
        [self.controlledShip removeAllActions];
        
        NSLog(@" A < B First: %@ \nSecond: %@", firstBody.node, secondBody.node);
        
    }
    else
    {

        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
        
        NSLog(@" A > B First: %@ \nSecond: %@", firstBody.node, secondBody.node);
    }
    
    // Missiles attack whatever they hit, then explode.
    
    if ((firstBody.categoryBitMask & missileCategory) != 0)
    {
        NSLog(@"3");
        [self attackTarget: secondBody withMissile:firstBody.node];
    }
    
    // Ships collide and take damage. The collision damage is based on the strength of the collision.
    if ((firstBody.categoryBitMask & shipCategory) != 0)
    {
  
        // The edge exists just to keep all gameplay on one screen, so ships should not take damage when they hit the
        // edge.
        
        if ((contact.collisionImpulse > collisonDamageThreshold) && ((secondBody.categoryBitMask & edgeCategory) == 0))
        {
            NSLog(@"5");
            APLShipSprite *targetShip = (APLShipSprite*)firstBody.node;
            [targetShip applyDamage:contact.collisionImpulse / collisonDamageThreshold];
            
            // If two ships collide with each other, both take damage. Planets and asteroids take no damage from ships.
            if (secondBody.categoryBitMask & shipCategory)
            {
                NSLog(@"6");
                targetShip = (APLShipSprite*)secondBody.node;
                [targetShip applyDamage:contact.collisionImpulse / collisonDamageThreshold];
            }
        }
    }
    
    // Asteroids that hit planets are destroyed.
    if (((firstBody.categoryBitMask & enemy) != 0) &&
        ((secondBody.categoryBitMask & friendly) != 0))
    {
        NSLog(@"7");
        [firstBody.node removeFromParent];
    }
}


#pragma mark - Controls and Control Logic



- (void)update:(NSTimeInterval)currentTime
{

    
    if (self.runEngine)
    {
        [self.controlledShip activateMainEngine];
    }
    
//    [self updatePlayerShip:currentTime];
    
}

- (void)updatePlayerShip:(NSTimeInterval)currentTime
{
    /* 
     Use the stored key information to control the ship.
     */
    
    if (actions[kPlayerForward])
    {
        [self.controlledShip activateMainEngine];
    }
    else
    {
        [self.controlledShip deactivateMainEngine];
    }
    
    if (actions[kPlayerBack])
    {
        [self.controlledShip reverseThrust];
    }
    
    if (actions[kPlayerLeft])
    {
        [self.controlledShip rotateShipLeft];
    }
    
    if (actions[kPlayerRight])
    {
        [self.controlledShip rotateShipRight];
    }
    
    if (actions[kPlayerAction])
    {
        [self.controlledShip removeAllActions];
        
        //[self.controlledShip attemptMissileLaunch:currentTime];
    }
}


- (void)keyDown:(NSEvent *)theEvent
{
    /*
     Convert key down events into game actions
     */
     
    // first we check the arrow keys since they are on the numeric keypad
    if ([theEvent modifierFlags] & NSNumericPadKeyMask)
    { // arrow keys have this mask
        NSString *theArrow = [theEvent charactersIgnoringModifiers];
        unichar keyChar = 0;
        if ( [theArrow length] == 1 ) {
            keyChar = [theArrow characterAtIndex:0];
            switch (keyChar) {
                case NSLeftArrowFunctionKey:
                    actions[kPlayerLeft] = YES;
                    break;
                case NSRightArrowFunctionKey:
                    actions[kPlayerRight] = YES;
                    break;
                case NSUpArrowFunctionKey:
                    actions[kPlayerForward] = YES;
                    break;
                case NSDownArrowFunctionKey:
                    actions[kPlayerBack] = YES;
                    break;
            }
        }
    }
    
    // and now we check the keyboard
    NSString *characters = [theEvent characters];
    if ([characters length]) {
        for (int s = 0; s<[characters length]; s++) {
            unichar character = [characters characterAtIndex:s];
            switch (character) {
                case 'w':
                {
                    self.controlledShip.physicsBody.categoryBitMask = shipCategory;
                    self.controlledShip.physicsBody.collisionBitMask =   friendly | edgeCategory;
                    self.controlledShip.physicsBody.contactTestBitMask =  friendly | edgeCategory;
                    
                    SKNode* node = [self.arraywithFrieds objectAtIndex:5];
                    
                    self.controlledShip.position = node.position;
                }
                    break;
                case 'a':
                    actions[kPlayerLeft] = YES;
                    break;
                case 'd':
                    actions[kPlayerRight] = YES;
                    break;
                case 's':
                    actions[kPlayerBack] = YES;
                    break;
                case ' ':
                {
                    self.runEngine = !self.runEngine;
                    [self.controlledShip removeAllActions];
//                    actions[kPlayerAction] = YES;
                    break;
                    
                }
                case 'r':
                {
                    APLSpaceScene *reset = [[APLSpaceScene alloc] initWithSize: self.frame.size];
                    [self.view presentScene:reset transition:[SKTransition flipVerticalWithDuration:0.35]];
                }
                    break;
            }
        }
    }
}

- (void)keyUp:(NSEvent *)theEvent
{
    /*
     Convert key up events into game actions
     */
    
    if ([theEvent modifierFlags] & NSNumericPadKeyMask)
    { 
        NSString *theArrow = [theEvent charactersIgnoringModifiers];
        unichar keyChar = 0;
        if ( [theArrow length] == 1 ) {
            keyChar = [theArrow characterAtIndex:0];
            switch (keyChar) {
                case NSLeftArrowFunctionKey:
                    actions[kPlayerLeft] = NO;
                    break;
                case NSRightArrowFunctionKey:
                    actions[kPlayerRight] = NO;
                    break;
                case NSUpArrowFunctionKey:
                    actions[kPlayerForward] = NO;
                    break;
                case NSDownArrowFunctionKey:
                    actions[kPlayerBack] = NO;
                    break;
            }
        }
    }
    
    NSString *characters = [theEvent characters];
    if ([characters length]) {
        for (int s = 0; s<[characters length]; s++) {
            unichar character = [characters characterAtIndex:s];
            switch (character) {
                case 'w':
                    actions[kPlayerForward] = NO;
                    break;
                case 'a':
                    actions[kPlayerLeft] = NO;
                    break;
                case 'd':
                    actions[kPlayerRight] = NO;
                    break;
                case 's':
                    actions[kPlayerBack] = NO;
                    break;
                case ' ':
                    actions[kPlayerAction] = NO;
                    break;
            }
        }
    }
}


@end
