NWGKeyValueObserving.h

typedef void (^KeyValueObserverBlock)( NSDictionary * change ) ;

@interface KeyValueObserver : NSObject

@property ( nonatomic, readonly, copy )	NSString * 			keyPath ;
@property ( nonatomic, readonly ) 	id 				target ;
@property ( nonatomic, readonly ) 	NSKeyValueObservingOptions	options ;

+(instancetype)observeKeyPath:(NSString*)keyPath ofObject:(id)target options:(NSKeyValueObservingOptions)options block:(KeyValueObserverBlock)block ;

// options = NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
+(instancetype)observeKeyPath:(NSString*)keyPath ofObject:(id)target block:(KeyValueObserverBlock)block ;

-(void)stopObserving ;

@end