//
//  SKCCLayer.h
//  OfficeAttacks
//
//  Created by Steve Kanter on 12/8/11.
//  Copyright (c) 2011 Steve Kanter. All rights reserved.
//

/** SKCCLayer is the base class for all non-colored layers.  This class handles touches and clicks via SKInputManager. */
@interface SKCCLayer : CCLayer <CCRGBAProtocol> {
	BOOL opacityPropogates_;
	GLbyte originalOpacity_;
}
/** Fade out ALL UIKit elements that are subviews of CCDirector's  view and then call the block
 @param block an SKKitBlock to call after the views have been faded out.
 */
-(void) fadeOutUIKitWithBlock:(SKKitBlock)block;


/** Add an observer to [NSNotificationCenter defaultCenter].  The reason we do this is so that when it returns its observer object, we hold onto that object in an iVar so when we call removeObserver on ourselves, it removes all these blocks as well.
 @param name name of the notification
 @param object to listen on, or nil for any object.
 @param queue the NSOperationQueue to listen on.  Usually either nil or [NSOperationQueue currentQueue]
 @param block the block to call with the notification */
-(void) addObserverForName:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue usingBlock:(SKNotificationCenterBlock)block;

/** Remove the receiver as an observer from [NSNotificationCenter defaultCenter] and remove any blocks added from self addObserverForName:object:queue:usingBlock: */
-(void) removeObserver;
/** Get a __weak version of self.  Usefull for addObserverForName:object:queue:usingBlock:
 @returns __weak version of self. */
-(SKCCLayer *) weak;


/** Relative frame for a specific node - takes into account a lot of different info - could be a better way - hack for now.
 @param whom who to get the relative frame of */
-(CGRect) relativeFrameFor:(CCNode *)whom;
/** Relative frame for a this node */
-(CGRect) relativeFrame;
/** The frame for this node - uses it's childrens' relativeFrames. */
-(CGRect) frame;

/** Whether or not the opacity of this node gets propogated to it's children, with the children taking their originalOpacity's into account. */
@property(nonatomic, assign) BOOL opacityPropogates;
/** The "original opacity" of the layer.  That's to say, what the "base" opacity of the node is.
 
 For example, if you want to CCFadeOut from half-opacity of the node, originalOpacity_ should be set to 127 BEFORE the fade out is called.
 */
@property(nonatomic, assign) GLbyte originalOpacity;

@end