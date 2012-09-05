//
//  SKCCSprite.m
//  OfficeAttacks
//
//  Created by Steve Kanter on 12/7/11.
//  Copyright (c) 2011 Steve Kanter. All rights reserved.
//

#import "SKCCSprite.h"
#import "SKKitDefines.h"

NSString *const SKCCSpriteAnimationSpeedNotification = @"SKCCSpriteAnimationSpeedNotification";

@class SKSpriteAnimationAsyncLoader;
@interface SKCCSprite (SKSpriteAnimationAsyncLoadAdditions)

-(void) removeAsyncLoader:(SKSpriteAnimationAsyncLoader *)loader;
-(void) removeAllAsyncLoaders;
-(void) addAsyncLoader:(SKSpriteAnimationAsyncLoader *)loader;

@end


@interface SKSpriteAnimationAsyncLoader : NSObject

@property(nonatomic, readwrite, SK_PROP_WEAK) SKCCSprite *delegate;
@property(nonatomic, readwrite, copy) NSString *animationName;
@property(nonatomic, readwrite, copy) SKKitBlock animationBlock;
@property(nonatomic, readwrite, copy) NSString *animationSpritesheetControlFile;
@property(nonatomic, readwrite, assign) SKCCSpriteAnimationOptions animationOptions;

-(void) loadTextureAsync:(NSString *)texture;
@end


@implementation SKSpriteAnimationAsyncLoader

@synthesize delegate=_delegate;
@synthesize animationName=_animationName;
@synthesize animationBlock=_animationBlock;
@synthesize animationOptions=_animationOptions;
@synthesize animationSpritesheetControlFile=_animationSpritesheetControlFile;

-(void) doneLoading:(CCTexture2D *)texture {
	[[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:_animationSpritesheetControlFile
																 texture:texture];
	[[self delegate] runAnimation:_animationName completionBlock:_animationBlock options:_animationOptions];
	[[self delegate] removeAsyncLoader:self];
}
-(void) loadTextureAsync:(NSString *)texture {
	[[CCTextureCache sharedTextureCache] addImageAsync:texture target:self selector:@selector(doneLoading:)];
}

@end


/** A private class to SKCCSprite for maintaining a list of cached config files. */
@interface SKSpriteManager : SKSingleton {
	NSMutableDictionary *configs_;
}
+(SKSpriteManager *) sharedSpriteManager;
-(NSDictionary *) getConfigByFilename:(NSString *)filename;
@end

@implementation SKSpriteManager
SK_MAKE_SINGLETON(SKSpriteManager, sharedSpriteManager)
-(id) init {
	if( (self = [super init]) ) {
		configs_ = [[NSMutableDictionary alloc] initWithCapacity:10];
	}
	return self;
}
-(NSDictionary *) getConfigByFilename:(NSString *)filename {
	NSDictionary *config = [configs_ objectForKey:filename];
	if(!config) {
		NSString *file = filename;
		if(![filename isAbsolutePath]) {
			file = RESOURCEFILE(filename);
		}
		config = [NSDictionary dictionaryWithContentsOfFile:file];
		if(config) {
			[configs_ setObject:config forKey:filename];
		}
	}
	return config;
}
-(void) dealloc {
	configs_ = nil;
#if !__has_feature(objc_arc)
	[super dealloc];
#endif
}

@end


@interface SKCCSprite ()
@property(nonatomic, readwrite, strong) NSString *lastUsedAnimation;
@end

@implementation SKCCSprite {
//#if IS_iOS
	__strong NSMutableArray *observers_;
//#endif
	
	__strong NSString *_spritesheetPrefix;
	__strong NSMutableArray *_loaders;
}

@synthesize originalOpacity=originalOpacity_;
@synthesize opacityPropogates=opacityPropogates_;
@synthesize inputEnabled=inputEnabled_;
@synthesize textureFilename=textureFilename_;
@synthesize config=config_;
@synthesize grayscaleMode=grayscaleMode_;
@synthesize lastUsedAnimation=lastUsedAnimation_;
@synthesize runningAnimations=runningAnimations_;
@synthesize runningAnimationsBasedOnSpeed=_runningAnimationsBasedOnSpeed;

-(void) setupTextureFilenameWithFilename:(NSString *)filename {
	self.textureFilename = filename;
#if CC_IS_RETINA_DISPLAY_SUPPORTED
#error fix this - it's old and doesn't support iPad retina.  should resolve that.
	if( CC_CONTENT_SCALE_FACTOR() == 2 ) {
		NSString *filenameWithoutExtension = [ccRemoveHDSuffixFromFile(filename) stringByDeletingPathExtension];
		NSString *extension = [filename pathExtension];
		NSString *retinaName = [filenameWithoutExtension stringByAppendingString:CC_RETINA_DISPLAY_FILENAME_SUFFIX];
		retinaName = [retinaName stringByAppendingPathExtension:extension];
		self.textureFilename = retinaName;
	}
#endif
}

#if IS_Mac
-(NSString *) removeSuffix:(NSString*)suffix fromPath:(NSString*)path {
	// quick return
	if( ! suffix || [suffix length] == 0 )
		return path;
	
	NSString *name = [path lastPathComponent];
	
	// check if path already has the suffix.
	if( [name rangeOfString:suffix].location != NSNotFound ) {
		
		NSString *newLastname = [name stringByReplacingOccurrencesOfString:suffix withString:@""];
		
		NSString *pathWithoutLastname = [path stringByDeletingLastPathComponent];
		return [pathWithoutLastname stringByAppendingPathComponent:newLastname];
	}
	
	// suffix was not removed
	return path;
}
#endif

-(void) setupConfigWithFilename:(NSString *)filename {
	
	// see if the file with whatever suffix is already on it exists.
	
	NSString *finalFilename = nil;
	NSString *testFilename = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
	BOOL found = NO;
	if([[NSFileManager defaultManager] fileExistsAtPath:testFilename]) {
		finalFilename = testFilename;
		found = YES;
	}
	if(!found && [[NSFileManager defaultManager] fileExistsAtPath:RESOURCEFILE(testFilename)]) {
		finalFilename = testFilename;
		found = YES;
	}
	if(!found) {
		// strip off the suffix, and then try adding on the default suffix for the current mode.
#if IS_iOS
		testFilename = [[CCFileUtils sharedFileUtils] removeSuffixFromFile:filename];
#endif
#if IS_Mac
		testFilename = [self removeSuffix:@"-hd" fromPath:testFilename];
		testFilename = [self removeSuffix:@"-iPadHD" fromPath:testFilename];
#endif
		// turn the relative into an absolute, to see if having the suffix helps.
		testFilename = [[CCFileUtils sharedFileUtils] fullPathFromRelativePath:testFilename];
		// remove the path extension
		testFilename = [testFilename stringByDeletingPathExtension];
		// slap on the plist extension and BAM - we got a plist filename.
		testFilename = [testFilename stringByAppendingPathExtension:@"plist"];
		if([[NSFileManager defaultManager] fileExistsAtPath:testFilename]) {
			finalFilename = testFilename;
			found = YES;
		}
	}
	if(!found) {
#if IS_iOS
		finalFilename = [[CCFileUtils sharedFileUtils] removeSuffixFromFile:filename];
#endif
		// remove the path extension
		finalFilename = [finalFilename stringByDeletingPathExtension];
		// slap on the plist extension and BAM - we got a plist filename.
		finalFilename = [finalFilename stringByAppendingPathExtension:@"plist"];
		found = YES;
		// default to NO extension.
	}
	config_ = [[SKSpriteManager sharedSpriteManager] getConfigByFilename:finalFilename];
}
-(id) initWithTexture:(CCTexture2D *)texture rect:(CGRect)rect rotated:(BOOL)rotated {
	if( (self = [super initWithTexture:texture rect:rect rotated:rotated]) ) {
		inputEnabled_ = YES;
		textureFilename_ = nil;
		config_ = nil;
		grayscaleMode_ = NO;
		lastUsedAnimation_ = nil;
		_spritesheetPrefix = nil;
//#if IS_iOS
		observers_ = [NSMutableArray arrayWithCapacity:3];
//#endif
		runningAnimations_ = [[NSMutableDictionary alloc] initWithCapacity:2];
		_runningAnimationsBasedOnSpeed = [NSMutableArray arrayWithCapacity:2];
		originalOpacity_ = -1;
		
		_loaders = [NSMutableArray arrayWithCapacity:10];
	}
	return self;
}
-(void) setSpritesheetPrefix:(NSString *)prefix {
	_spritesheetPrefix = prefix;
}
+(NSString *) texturePackerAbsoluteFileFromControlFile:(NSString *)controlFile {
	return [[CCFileUtils sharedFileUtils] fullPathFromRelativePath:controlFile];
}

+(id) spriteFromTexturePackerControlFile:(NSString *)filename {
	SKCCSprite *sprite = [[[self class] alloc] init];
	[sprite setupConfigWithFilename:filename];
	NSDictionary *config = [sprite config];
	if([config objectForKey:@"spritesheetControlFile"]) {
		NSString *controlFile = [[config objectForKey:@"spritesheetControlFile"] stringByAppendingPathExtension:@"plist"];
		[[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:[self texturePackerAbsoluteFileFromControlFile:controlFile]];
		[sprite setSpritesheetPrefix:[config objectForKey:@"spritesheetFramePrefix"]];
		[sprite setupTextureFilenameWithFilename:[config objectForKey:@"spritesheetControlFile"]];
	}
	return sprite;
}
+(id) spriteWithFirstFrameOfSpritesheetFromFile:(NSString *)filename {
	SKCCSprite *sprite = [[self class] spriteWithFile:filename];
	if(sprite.config) {
		CGSize size = SKCGSizeMake([[[sprite config] objectForKey:@"spriteWidth"] intValue], [[[sprite config] objectForKey:@"spriteHeight"] intValue]);
		sprite.textureRect = CGRectMake(0, 0, size.width, size.height);
	}
	return sprite;
}
-(id) initWithFile:(NSString *)filename {
	if( (self = [super initWithFile:filename]) ) {
		[self setupTextureFilenameWithFilename:filename];
		[self setupConfigWithFilename:filename];
	}
	return self;
}
-(id) initWithFile:(NSString *)filename rect:(CGRect)rect {
	if( (self = [super initWithFile:filename rect:rect]) ) {
		[self setupTextureFilenameWithFilename:filename];
		[self setupConfigWithFilename:filename];
	}
	return self;
}
-(void) onEnter {
	[super onEnter];
	[[self weak] addObserverForName:SKCCSpriteAnimationSpeedNotification
							 object:nil
							  queue:nil
						 usingBlock:^(NSNotification *notification) {
							 float speed = [[[notification userInfo] objectForKey:@"animationSpeed"] floatValue];
							 for(CCAction *action in _runningAnimationsBasedOnSpeed) {
								 if((notification.object == nil || notification.object == action) && [action isKindOfClass:[CCSpeed class]]) {
									 ((CCSpeed *)action).speed = speed;
								 }
							 }
						 }];
}
-(void) onExit {
	self.runningAnimations = nil;
	_runningAnimationsBasedOnSpeed = nil;
	[[SKInputManager sharedInputManager] removeHandler:self];
	[self removeAllAsyncLoaders];
	[super onExit];
}

-(CGPoint) inputPositionInOpenGLTerms:(id)touch {
#if IS_iOS
	CGPoint position = [touch locationInView:[[CCDirector sharedDirector] view]];
	return [[CCDirector sharedDirector] convertToGL:position];
#elif IS_Mac
	return NSPointToCGPoint([touch locationInWindow]);
#endif
}
-(CGPoint) inputPositionInNode:(id)touch {
	return [self convertToNodeSpace:[self inputPositionInOpenGLTerms:touch]];
}
-(BOOL) inputIsInBoundingBox:(id)touch {
	CGPoint pos = [self inputPositionInNode:touch];
	
	CGRect box = CGRectMake(0, 0, self.contentSize.width, self.contentSize.height);
	return CGRectContainsPoint(box, pos);
}
#if IS_iOS
-(BOOL) skTouchBegan:(UITouch *)touch {
	if(!inputEnabled_ || !visible_) return NO;
	BOOL myTouch = [self inputIsInBoundingBox:touch];
	if(myTouch) {
		CGPoint pos = [self inputPositionInOpenGLTerms:touch];
		[self inputBeganWithLocation:pos];
	}
	return myTouch;
}
-(void) skTouchMoved:(UITouch *)touch {
	CGPoint pos = [self inputPositionInOpenGLTerms:touch];
	[self inputMovedWithLocation:pos];
}
-(void) skTouchEnded:(UITouch *)touch {
	CGPoint pos = [self inputPositionInOpenGLTerms:touch];
	[self inputEndedWithLocation:pos];
}
-(void) skTouchCancelled:(UITouch *)touch {
	CGPoint pos = [self inputPositionInOpenGLTerms:touch];
	[self inputCancelledWithLocation:pos];
}
#endif
#if IS_Mac
-(BOOL) skClickBegan:(NSEvent *)event {
	if(!inputEnabled_ || !visible_) return NO;
	BOOL myClick = [self inputIsInBoundingBox:event];
	if(myClick) {
		CGPoint pos = [self inputPositionInOpenGLTerms:event];
		[self inputBeganWithLocation:pos];
	}
	return myClick;

}
-(void) skClickMoved:(NSEvent *)event {
	CGPoint pos = [self inputPositionInOpenGLTerms:event];
	[self inputMovedWithLocation:pos];
}
-(void) skClickEnded:(NSEvent *)event {
	CGPoint pos = [self inputPositionInOpenGLTerms:event];
	[self inputEndedWithLocation:pos];
}
-(void) skClickCancelled:(NSEvent *)event {
	CGPoint pos = [self inputPositionInOpenGLTerms:event];
	[self inputCancelledWithLocation:pos];
}
#endif
-(void) inputBeganWithLocation:(CGPoint)position {
	
}
-(void) inputMovedWithLocation:(CGPoint)position {
	
}
-(void) inputEndedWithLocation:(CGPoint)position {
	
}
-(void) inputCancelledWithLocation:(CGPoint)position {
	
}
-(void) addToInputManagerWithPriority:(int)priority {
	[[SKInputManager sharedInputManager] addHandler:self withPriority:priority];
}
-(void) setInputBeganHandler:(SKInputHandlerBlock)block {
	SKInputManager *inputManager = [SKInputManager sharedInputManager];
	SKInputManagerHandler *handler = [inputManager handlerObjectForNode:self];
	[handler setInputBeganBlock:block];
}
-(void) setInputMovedHandler:(SKInputHandlerBlock)block {
	SKInputManager *inputManager = [SKInputManager sharedInputManager];
	SKInputManagerHandler *handler = [inputManager handlerObjectForNode:self];
	[handler setInputMovedBlock:block];
}
-(void) setInputEndedHandler:(SKInputHandlerBlock)block {
	SKInputManager *inputManager = [SKInputManager sharedInputManager];
	SKInputManagerHandler *handler = [inputManager handlerObjectForNode:self];
	[handler setInputEndedBlock:block];
}
-(void) setInputCancelledHandler:(SKInputHandlerBlock)block {
	SKInputManager *inputManager = [SKInputManager sharedInputManager];
	SKInputManagerHandler *handler = [inputManager handlerObjectForNode:self];
	[handler setInputCancelledBlock:block];
}
-(void) setMouseMovedHandler:(SKInputHandlerBlock)block {
	SKInputManager *inputManager = [SKInputManager sharedInputManager];
	SKInputManagerHandler *handler = [inputManager handlerObjectForNode:self];
	[handler setMouseMovedBlock:block];
}

-(void) _setInput:(BOOL)enabled onChildrenOf:(SKCCSprite *)parent {
	if([parent isKindOfClass:[SKCCSprite class]]) {
		parent.inputEnabled = enabled;
	}
	if([parent children] && [[parent children] count] > 0) {
		for(SKCCSprite *child in [parent children]) {
			[self _setInput:enabled onChildrenOf:child];
		}
	}
}

-(void) disableInputOnSelfAndChildren {
	[self _setInput:NO onChildrenOf:self];
}
-(void) enableInputOnSelfAndChildren {
	[self _setInput:YES onChildrenOf:self];
}

-(int) getSpriteSheetColumn:(int)frameNumber {
	int numColumns = [[self.config objectForKey:@"numColumns"] intValue];
	return frameNumber % numColumns;
}
-(int) getSpriteSheetRow:(int)frameNumber {
	int numColumns = [[self.config objectForKey:@"numColumns"] intValue];
	return ceil(frameNumber / numColumns);
}
-(NSString *) getRunningZeros:(int)lengthOfNumbers forNumber:(int)number {
	NSMutableString *final = [NSMutableString stringWithFormat:@"%i", number];
	while([final length] < lengthOfNumbers) {
		[final insertString:@"0" atIndex:0];
	}
	return final;
}
-(NSString *) getRandomAnimationKey {
	NSArray *keys = [self allAnimationNames];
	NSString *key = [keys objectAtIndex:RANDOM_INT(0,[keys count]-1)];
	return key;
}
-(void) stopAllAnimations {
	for(id key in [self runningAnimations]) {
		CCAction *ac = [[self runningAnimations] objectForKey:key];
		[self stopAction:ac];
	}
	[[self runningAnimations] removeAllObjects];
	[_runningAnimationsBasedOnSpeed removeAllObjects];
}
-(void) stopAnimationByName:(NSString *)name {
	CCAction *ac = [[self runningAnimations] objectForKey:name];
	[self stopAction:ac];
	[[self runningAnimations] removeObjectForKey:name];
	if([_runningAnimationsBasedOnSpeed containsObject:ac]) {
		[_runningAnimationsBasedOnSpeed removeObject:ac];
	}
}

-(NSArray *) allAnimationNames {
	return [[[self config] objectForKey:@"animations"] allKeys];
}

-(BOOL) containsAnimation:(NSString *)name {
	return [[self allAnimationNames] containsObject:name];
}
-(NSString *) animationNameForKey:(int)animationKey fromGroupWithKey:(int)animationGroupKey {
	// get all the groups
	NSDictionary *groups = [[self config] objectForKey:@"animationGroups"];
	for(NSString *name in groups) {
		NSDictionary *group = [groups objectForKey:name];
		int groupKey = [[group objectForKey:@"groupKey"] intValue];
		// see if the group's key is the one we want
		if(groupKey == animationGroupKey) {
			NSDictionary *groupAnimations = [group objectForKey:@"animations"];
			for(NSString *animationKeyString in groupAnimations) {
				int thisAnimationKey = [animationKeyString intValue];
				// see if the group defines the name of the animation for this key
				if(thisAnimationKey == animationKey) {
					return [groupAnimations objectForKey:animationKeyString];
				}
			}
		}
	}
#if ANIMATION_TEST
	return nil;
#endif
	// since we got this far, the group we wanted either didn't exist, or the animation didn't exist in it. return an animation if possible
	for(NSString *name in groups) {
		NSDictionary *group = [groups objectForKey:name];
		NSDictionary *groupAnimations = [group objectForKey:@"animations"];
		for(NSString *animationKeyString in groupAnimations) {
			int thisAnimationKey = [animationKeyString intValue];
			// see if THIS group defines the name of the animation for this key
			if(thisAnimationKey == animationKey) {
				return [groupAnimations objectForKey:animationKeyString];
			}
		}
	}	
	return nil;
}
-(NSString *) textureFilenameFromSpritesheetControlFile:(NSString *)plist {
	NSString *path = [[self class] texturePackerAbsoluteFileFromControlFile:plist];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
	
    NSString *texturePath = nil;
    NSDictionary *metadataDict = [dict objectForKey:@"metadata"];
    if( metadataDict )
        // try to read  texture file name from meta data
        texturePath = [metadataDict objectForKey:@"textureFileName"];
	
	
    if( texturePath ) {
        // build texture path relative to plist file
        NSString *textureBase = [plist stringByDeletingLastPathComponent];
        texturePath = [textureBase stringByAppendingPathComponent:texturePath];
    }
	return texturePath;
}

-(NSString *) runRandomAnimation {
	return [self runRandomAnimationWithCompletionBlock:nil options:0];
}
-(NSString *) runRandomAnimationWithCompletionBlock:(SKKitBlock)block {
	return [self runRandomAnimationWithCompletionBlock:block options:0];
}
-(NSString *) runRandomAnimationWithCompletionBlock:(SKKitBlock)block options:(SKCCSpriteAnimationOptions)options {
	NSString *key = [self getRandomAnimationKey];
	[self runAnimation:key completionBlock:block options:options];
	return key;
}

-(void) runAnimation:(NSString *)name {
	[self runAnimation:name completionBlock:nil options:0];
}
-(void) runAnimation:(NSString *)name completionBlock:(SKKitBlock)block {
	[self runAnimation:name completionBlock:block options:0];
}
-(void) runAnimation:(NSString *)name completionBlock:(SKKitBlock)block options:(SKCCSpriteAnimationOptions)options {
	[self runAnimation:name completionBlock:block options:options playbackSpeed:1.f];
}
-(void) runAnimation:(NSString *)name completionBlock:(SKKitBlock)block options:(SKCCSpriteAnimationOptions)options playbackSpeed:(float)speed {
	
	if(!name) return;
	
	BOOL restoreFrame = options & SKCCSpriteAnimationOptionsRestoreOriginalFrame;
	
	// of the animation requires a control file loaded, and it's not, whether or not to load it in a seperate thread.
	BOOL preloadControlFileAsync = options & SKCCSpriteAnimationOptionsPreloadControlFileAsync;
	
//	BOOL randomFrame = options & SKCCSpriteAnimationOptionsRandomStartingFrame;
	self.lastUsedAnimation = name;
	NSDictionary *animationData = [[[self config] objectForKey:@"animations"] objectForKey:name];
	if(!animationData && block) {
		[self runAction:[CCCallBlock actionWithBlock:block]];  //this way, we call the completion block but wait until the next run of the loop.  prevents the block being called before you're ready for it.
		return;
	}
	NSString *animationName = [self.textureFilename stringByAppendingFormat:@":%@", name];
	if(self.grayscaleMode) {
		animationName = [animationName stringByAppendingString:@":grayscale"];
	}
	CCAnimation *animation = [[CCAnimationCache sharedAnimationCache] animationByName:animationName];
	//NSLog(@"animation: %@", animationName);
	
	if(!animation && [animationData objectForKey:@"randomPreloadFrameRanges"]) {
		NSMutableDictionary *newAnimationData = [animationData mutableCopy];
		NSDictionary *frameKeys = [animationData objectForKey:@"randomPreloadFrameRanges"];
		NSString *key = [[frameKeys allKeys] objectAtIndex:RANDOM_INT(0, [frameKeys count] - 1)];
		NSString *range = [frameKeys objectForKey:key];
		[newAnimationData setObject:key forKey:@"preloadAnimationControlFile"];
		[newAnimationData setObject:range forKey:@"frameRange"];
		animationData = [newAnimationData copy];
	}
	
	if(!animation && [animationData objectForKey:@"preloadAnimationControlFile"]) {
		NSString *path = [[animationData objectForKey:@"preloadAnimationControlFile"] stringByAppendingPathExtension:@"plist"];
		NSString *fullPath = [[self class] texturePackerAbsoluteFileFromControlFile:path];
		NSString *currentPath = fullPath;
#if IS_iOS
		currentPath = [[CCFileUtils sharedFileUtils] removeSuffixFromFile:fullPath];
#endif
		NSString *key = [self textureFilenameFromSpritesheetControlFile:currentPath];
		if(![[CCTextureCache sharedTextureCache] textureForKey:key] &&
		   !(options & SKCCSpriteAnimationOptionsSkipPreload)) {
			if(preloadControlFileAsync) {
				SKSpriteAnimationAsyncLoader *loader = [[SKSpriteAnimationAsyncLoader alloc] init];
				loader.delegate = self;
				loader.animationName = name;
				loader.animationBlock = block;
				options = options | SKCCSpriteAnimationOptionsSkipPreload;
				loader.animationOptions = options;
				loader.animationSpritesheetControlFile = path;
				
				[loader loadTextureAsync:key];
				
				return; // we're going to load again later, so no sense continuing. things will shit.
			} else {
				[[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile:path];
			}
		}
	}
	
	if(!animation) {
		
		NSMutableArray *frameIndexes = [animationData objectForKey:@"frames"];
		
		if([animationData objectForKey:@"frameRange"]) {
			NSArray *array = [[animationData objectForKey:@"frameRange"] componentsSeparatedByString:@"-"];
			if([array count] == 2) {
				int startIndex = [[array objectAtIndex:0] intValue];
				int endIndex = [[array objectAtIndex:1] intValue];
				frameIndexes = [NSMutableArray arrayWithCapacity:endIndex - startIndex + 1];
				for(int i = startIndex; i <= endIndex; i++) {
					[frameIndexes addObject:[NSNumber numberWithInt:i]];
				}
			} else if([array count] == 1) {
				frameIndexes = [NSMutableArray arrayWithCapacity:1];
				[frameIndexes addObject:[NSNumber numberWithInt:[[array objectAtIndex:0] intValue]]];
			}
		}
		
		NSMutableArray *frames = [NSMutableArray arrayWithCapacity:[frameIndexes count]];
		
		if(!_spritesheetPrefix) { // not from texturepacker
			CCSpriteBatchNode *spriteSheet = [CCSpriteBatchNode batchNodeWithTexture:texture_];
			CCTexture2D *animationTexture = spriteSheet.textureAtlas.texture;
			CGRect baseRect = SKCGRectMake(0,0, [[self.config objectForKey:@"spriteWidth"] intValue], [[self.config objectForKey:@"spriteHeight"] intValue]);
			for(NSNumber *frameNumber in frameIndexes) {
				CGRect frameRect = baseRect;
				frameRect.origin.x = frameRect.size.width * [self getSpriteSheetColumn:([frameNumber intValue] - 1)];
				frameRect.origin.y = frameRect.size.height * [self getSpriteSheetRow:([frameNumber intValue] - 1)];
				[frames addObject:[CCSpriteFrame frameWithTexture:animationTexture rect:frameRect]];
			}
		} else {
			for(NSNumber *frameNumber in frameIndexes) {
				NSString *key = [_spritesheetPrefix stringByAppendingString:[self getRunningZeros:4 forNumber:[frameNumber intValue]]];
				CCSpriteFrame *frame = [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName:key];
				if(frame) {
					[frames addObject:frame];
				}
			}
		}
		animation = [CCAnimation animationWithSpriteFrames:frames delay:[[animationData objectForKey:@"timePerFrame"] floatValue]];
		animation.restoreOriginalFrame = restoreFrame;
		//we don't wanna cross-contaminate "walk" animations, for example.
		//specific to the sprite "type" [name] and animation name.
		//this way multiple instances of the same sprite type still use the same one, though.
		
		[[CCAnimationCache sharedAnimationCache] addAnimation:animation name:animationName];
	}
	id finalAnimation;
	int repeat = [[animationData objectForKey:@"repeat"] intValue];
	
	CCAnimate *animate = [CCAnimate actionWithAnimation:animation];
	
	if(options & SKCCSpriteAnimationOptionsDontRepeat) {
		// don't repeat.
		repeat = 0;
	}
	
	if(repeat == -1) {
		finalAnimation = [CCRepeatForever actionWithAction:animate];
	} else if(repeat == 0) {
		finalAnimation = animate;
	} else {
		finalAnimation = [CCRepeat actionWithAction:animate times:repeat];
	}
	if([animationData objectForKey:@"sound"]) {
//		[[SKAudioManager sharedAudioManager] playSoundFile:[animationData objectForKey:@"sound"]];
	}
	if([animationData objectForKey:@"translations"]) {
		NSDictionary *translationData = [animationData objectForKey:@"translations"];
		for(NSString *translationKey in translationData) {
			NSDictionary *translation = [translationData objectForKey:translationKey];
			id translationAction = [CCScaleTo actionWithDuration: [[translation objectForKey:@"time"] floatValue]
														   scale: [[translation objectForKey:@"scaleTo"] floatValue]];
			if([translationKey isEqual:@"scale"]) {
				finalAnimation = [CCSpawn actions:finalAnimation, translationAction, nil];
			}
			// add more "translation"s here if/as needed.
		}
	}
	BOOL hasANextAnimationAndShouldntCallBlockOurselves = ([animationData objectForKey:@"nextAnimation"]) && (options & SKCCSpriteAnimationOptionsPassCompletedBlockOn);
	if(block &&
	   ![finalAnimation isKindOfClass:[CCRepeatForever class]] &&
	   !hasANextAnimationAndShouldntCallBlockOurselves) { // can't sequence actions that never end.
		finalAnimation = [CCSequence actions:finalAnimation, [CCCallBlock actionWithBlock:block], nil];
	}
	if(![finalAnimation isKindOfClass:[CCRepeatForever class]] && [animationData objectForKey:@"nextAnimation"]) {
		SKKitBlock completionBlock = nil;
		if((options & SKCCSpriteAnimationOptionsPassCompletedBlockOn)) {
			completionBlock = block;
			options = options ^ SKCCSpriteAnimationOptionsPassCompletedBlockOn;
		}
		finalAnimation = [CCSequence actionOne:finalAnimation
										   two:[CCCallBlock actionWithBlock:^{
				[self runAnimation:[animationData objectForKey:@"nextAnimation"]
				   completionBlock:completionBlock
						   options:options];
		}]];
	}
	if(options & SKCCSpriteAnimationOptionsRespondToSpeedNotifications) {
		if(speed <= 0.f) {
			speed = 1.f; // 0 speed and negative speeds are not allowed.
		}
		
		finalAnimation = [CCSpeed actionWithAction:finalAnimation speed:speed];
		[_runningAnimationsBasedOnSpeed addObject:finalAnimation];
	}
	
	[self stopAnimationByName:name];
	[[self runningAnimations] setObject:finalAnimation forKey:name];
	[self runAction:finalAnimation];
	[animate update:0]; //to prevent flicker
}
-(void) setOpacity:(GLubyte)opacity {
	if(self.originalOpacity != -1) {
		opacity = OPACITY(REVERSEOPACITY(self.originalOpacity) * REVERSEOPACITY(opacity));
	}
	[super setOpacity:opacity];
	if(self.opacityPropogates) {
		for(SKCCSprite *child in self.children) {
			if([child respondsToSelector:@selector(setOpacity:)]) {
				if([child respondsToSelector:@selector(originalOpacity)] && child.originalOpacity != -1) {
					[child setOpacity:OPACITY(REVERSEOPACITY(child.originalOpacity) * REVERSEOPACITY(opacity))];
				} else {
					[child setOpacity:opacity];
				}
			}
			if(![child respondsToSelector:@selector(opacityPropogates)]) {
				for(SKCCSprite *innerChild in child.children) {
					if([innerChild respondsToSelector:@selector(setOpacity:)]) {
						if([innerChild respondsToSelector:@selector(originalOpacity)] && innerChild.originalOpacity != -1) {
							[innerChild setOpacity:OPACITY(REVERSEOPACITY(innerChild.originalOpacity) * REVERSEOPACITY(opacity))];
						} else {
							[innerChild setOpacity:opacity];
						}
					}
				}
			}
		}
	}
}
//#if IS_iOS
-(void) addObserverForName:(NSString *)name object:(id)object queue:(NSOperationQueue *)queue usingBlock:(void (^)(NSNotification *notification))block {
	id observer = [(NSNotificationCenter *)[NSNotificationCenter defaultCenter] addObserverForName:name object:object queue:queue usingBlock:block];
	[observers_ addObject:observer];
}

-(SKCCSprite *) weak {
	OA_VAR_WEAK id weakSelf = self;
	return weakSelf;
}
-(void) removeObserver {
	for(id observer in observers_) {
		[[NSNotificationCenter defaultCenter] removeObserver:observer];
	}
	[observers_ removeAllObjects];
}
//#endif


-(CGRect) relativeFrameFor:(CCNode *)whom {
	CGPoint pos = [whom boundingBox].origin;
	CCNode *obj = whom.parent;
	float overallXScale = 1.0;
	float overallYScale = 1.0;
	while(obj && ![obj isKindOfClass:[CCLayer class]]) {
		pos.x += obj.boundingBox.origin.x;
		pos.y += obj.boundingBox.origin.y;
		overallXScale *= obj.scaleX;
		overallYScale *= obj.scaleY;
		obj = obj.parent;
		if(!obj) {obj = nil;}
	}
	overallXScale *= whom.scaleX;
	overallYScale *= whom.scaleY;
	return CGRectMake(pos.x * overallXScale, pos.y * overallYScale,
					  [whom boundingBox].size.width * overallXScale, [whom boundingBox].size.height * overallYScale);
}

-(CGRect) relativeFrame {
	return [self relativeFrameFor:self];
}
-(CGRect) frame {
	CGRect finalFrame = [self relativeFrame];
	for(id child in self.children) {
		if([child respondsToSelector:@selector(relativeFrame)]) {
			finalFrame = CGRectUnion(finalFrame, [(SKCCSprite *)child relativeFrame]);
		} else if([child isKindOfClass:[CCNode class]]) {
			finalFrame = CGRectUnion(finalFrame, [self relativeFrameFor:child]);
		}
	}
	return finalFrame;
}

-(void) removeAsyncLoader:(SKSpriteAnimationAsyncLoader *)loader {
	[_loaders removeObject:loader];
}
-(void) removeAllAsyncLoaders {
	[_loaders removeAllObjects];
}
-(void) addAsyncLoader:(SKSpriteAnimationAsyncLoader *)loader {
	[_loaders addObject:loader];
}
-(NSArray *) _allChildrenInNodeTree:(CCNode *)node includingSelf:(BOOL)includeSelf {
	NSMutableArray *array = [NSMutableArray arrayWithCapacity:10];
	if(includeSelf) {
		[array addObject:node];
	}
	if(node.children && [node.children count] > 0) {
		for(CCNode *child in node.children) {
			[array addObjectsFromArray:[self _allChildrenInNodeTree:child includingSelf:YES]];
		}
	}
	return array;
}
-(NSArray *) allChildrenInNodeTreeIncludingSelf:(BOOL)includeSelf {
	return [self _allChildrenInNodeTree:self includingSelf:includeSelf];
}

@end