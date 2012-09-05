//
//  SKUtilities.h
//  OfficeAttacksLevelBuilder
//
//  Created by Steve Kanter on 12/15/11.
//  Copyright (c) 2011 Steve Kanter. All rights reserved.
//

#import "SKSingleton.h"


typedef struct _SKCircle {
	CGPoint location;
	float radius;
} SKCircle;


NS_INLINE SKCircle SKCircleMake(CGPoint location, float radius) {
	SKCircle circle;
	circle.location = location;
	circle.radius = radius;
	return circle;
}

typedef struct _SKEllipse {
	CGPoint location;
	CGSize radius;
} SKEllipse;


NS_INLINE SKEllipse SKEllipseMake(CGPoint location, CGSize radius) {
	SKEllipse ellipse;
	ellipse.location = location;
	ellipse.radius = radius;
	return ellipse;
}

#define __KEY_INTO_STRING_INTERNAL(_string_) #_string_
#define __KEY_INTO_STRING(_string_) __KEY_INTO_STRING_INTERNAL(_string_)

#define ENCODE_INT_WITH_KEY(_iVarAndKey_) [coder encodeInt:_##_iVarAndKey_\
													forKey:@__KEY_INTO_STRING(_iVarAndKey_)]
#define ENCODE_BOOL_WITH_KEY(_iVarAndKey_) [coder encodeBool:_##_iVarAndKey_\
													  forKey:@__KEY_INTO_STRING(_iVarAndKey_)]
#define ENCODE_FLOAT_WITH_KEY(_iVarAndKey_) [coder encodeFloat:_##_iVarAndKey_\
														forKey:@__KEY_INTO_STRING(_iVarAndKey_)]
#define ENCODE_OBJECT_WITH_KEY(_iVarAndKey_) [coder encodeObject:_##_iVarAndKey_\
														  forKey:@__KEY_INTO_STRING(_iVarAndKey_)]

#define DECODE_INT_WITH_KEY(_iVarAndKey_) _##_iVarAndKey_ = [decoder decodeIntForKey:@__KEY_INTO_STRING(_iVarAndKey_)]
#define DECODE_BOOL_WITH_KEY(_iVarAndKey_) _##_iVarAndKey_ = [decoder decodeBoolForKey:@__KEY_INTO_STRING(_iVarAndKey_)]
#define DECODE_FLOAT_WITH_KEY(_iVarAndKey_) _##_iVarAndKey_ = [decoder decodeFloatForKey:@__KEY_INTO_STRING(_iVarAndKey_)]
#define DECODE_OBJECT_WITH_KEY(_iVarAndKey_) _##_iVarAndKey_ = [decoder decodeObjectForKey:@__KEY_INTO_STRING(_iVarAndKey_)]

/** SKUtilities is generally a singleton class.  It's designed to do random tasks that are easiest to perform on an object. */

@interface SKUtilities : SKSingleton {
	BOOL isIpad;
	BOOL isRetina;
}

/** Determine if a circle and rectangle intersect.
 @param circle a SKCircle to test
 @param rect rect to test. */
+(BOOL) intersectsCircle:(SKCircle)circle andRect:(CGRect) rect;

/** Determine if an ellipse and rectangle intersect.
 @param ellipse a SKEllipse to test
 @param rect rect to test. */
+(BOOL) intersectsEllipse:(SKEllipse)ellipse andRect:(CGRect) rect;

/** Determine if a point is in an ellipse.
 @param ellipse a SKEllipse to test
 @param point point to test. */
+(BOOL) ellipse:(SKEllipse)ellipse containsPoint:(CGPoint) point;

/** Determine if a polygon contains a point.
 @param poli the poligon
 @param numberOfPoints number of points in the polygon
 @param point the point to test */
+(BOOL) poly:(CGPoint *)poli numberOfPoints:(NSUInteger)numberOfPoints containsPoint:(CGPoint)point;

/** Get the dot product of two points
 @param point1 first point
 @param point2 second point
 @returns dot product */
+(float) dotProductOf:(CGPoint)point1 and:(CGPoint)point2;

/** Get the distance between two points
 @param point1 first point
 @param point2 second point
 @returns distance between them */
+(float) distanceBetween:(CGPoint)point1 and:(CGPoint)point2;

/** Get the distance from a point to a line segment
 @param point the point
 @param start start of line segment
 @param end end of line segment
 @returns distance */
+(float) distanceFrom:(CGPoint)point toLineSegmentStart:(CGPoint)start andEnd:(CGPoint)end;



// no sense rewriting the wheel / lazy / time crunched. www.musicalgeometry.com/?p=1197
+(NSArray *) splitString:(NSString*)str maxCharacters:(NSInteger)maxLength;

/** Class method that returns the shard instance of SKUtilities
 @returns shared instance */
+(SKUtilities *) sharedUtilities;

/** Whether or not the device is an iPad.  Cached for performance benefits. */
@property(nonatomic, readonly) BOOL isIpad;
/** Whether or not the device is retina.  Cached for performance benefits. */
@property(nonatomic, readonly) BOOL isRetina;
@end

/** Random convenience methods to be added to all objects. */
@interface NSObject (SKKitUtilitiesAdditions)
/** Convenience method for performSelector:withObject:afterDelay:
 @param aSelector selector
 @param delay delay */
-(void) performSelector:(SEL)aSelector afterDelay:(NSTimeInterval)delay;
@end

/** Random convenience methods to be added to all cocos2d nodes. */
@interface CCNode (SKKitUtilitiesAdditions)
/** Run the specified block after the provided delay.  Runs a sequence with a delay then CCCallBlock on the reciever.
 @param block block to be called
 @param delay delay to wait before calling block
 @returns the action sequence */
-(CCAction *) runBlock:(SKKitBlock)block afterDelay:(NSTimeInterval)delay;
/** Run the specified block after the provided delay repeating the specified amount.  Runs a sequence inside of a repeat with a delay then CCCallBlock on the reciever.
 @param block block to be called
 @param delay delay to wait before calling block
 @param repeatAmount number of times to repeat.  -1 repeats forever.
 @returns the action sequence */
-(CCAction *) runBlock:(SKKitBlock)block afterDelay:(NSTimeInterval)delay repeat:(int)repeatAmount;
/** Provides the highest z order of all of the children of the receiver.  Useful to ensure that a node you're about to add gets placed at the very front of the view. */
@property(nonatomic, readonly) int highestZOrder;
@end