// NWGKeyValueObserving.m
// by nielsbot ( niels@nielsbot.com)

@interface NSObject ( KeyValueObserving )
@property ( nonatomic, strong, readonly ) NSMutableSet * nwgRegisteredKeyValueObservers ;
-(void)removeKVOObservers ;
@end

@interface NWGKeyValueObserver ()
@property ( nonatomic, copy ) NSString * keyPath ;
@property ( nonatomic, copy ) KeyValueObserverBlock block ;
@property ( nonatomic, weak ) id target ;
@property ( nonatomic ) NSKeyValueObservingOptions options ;
@end

static void CustomSubclassDealloc( id self, SEL _cmd )
{
	[ self removeKVOObservers ] ;
}

static void CustomSubclassRemoveObservers( id self, SEL _cmd )
{
	[ ((NSObject*)self).nwgRegisteredKeyValueObservers makeObjectsPerformSelector:@selector( stopObserving ) ] ;
}

static CFMutableDictionaryRef __subclassForClassDictionary ;
static Class ObservableClassForClass( Class targetClass )
{
	assert( targetClass ) ;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		__subclassForClassDictionary = CFDictionaryCreateMutable( kCFAllocatorDefault, 0, NULL, NULL ) ;
	});

	if ( CFDictionaryContainsValue( __subclassForClassDictionary, (__bridge void *)targetClass ) )
	{
		return targetClass ;
	}
	
	Class subclass = CFDictionaryGetValue( __subclassForClassDictionary, (__bridge void *)targetClass ) ;
	
	if ( !subclass )
	{
		NSString * newClassName = [ NSString stringWithFormat:@"%@-%@", NSStringFromClass( targetClass ), @"NWGKVO" ] ;
		subclass = objc_allocateClassPair( targetClass, [ newClassName UTF8String ], 0 ) ;
		objc_registerClassPair( subclass ) ;
		
		class_addMethod( subclass, NSSelectorFromString(@"dealloc"), (IMP)CustomSubclassDealloc, "v@:" ) ;
		class_addMethod( subclass, NSSelectorFromString(@"removeObservers"), (IMP)CustomSubclassRemoveObservers, "v@:" ) ;

		CFDictionaryAddValue( __subclassForClassDictionary, (__bridge void *)targetClass, (__bridge void *)subclass ) ;
	}
	
	return subclass ;
}

static void MakeObservableClass( id target )
{
	
	Class newClass = ObservableClassForClass( [ target class ] ) ;
	if ( object_getClass( target ) != newClass )
	{
		object_setClass( target, newClass ) ;
	}
}

@implementation NWGKeyValueObserver

+(instancetype)observeKeyPath:(NSString*)keyPath ofObject:(id)target options:(NSKeyValueObservingOptions)options block:(KeyValueObserverBlock)block ;
{
	if ( keyPath.length == 0 || !target || options == 0 || !block ) { return nil ; }
	
	KeyValueObserver * result = [ [ [ self class ] alloc ] init ] ;
	result.keyPath = keyPath ;
	result.target = target ;
	result.block = block ;
	result.options = options ;
	[ result startObserving ] ;
	return result ;
}

+(instancetype)observeKeyPath:(NSString*)keyPath ofObject:(id)target block:(KeyValueObserverBlock)block ;
{
	return [ self observeKeyPath:keyPath
						ofObject:target
						 options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
						   block:block ] ;
}

-(void)startObserving
{
	@synchronized( self )
	{
		@try
		{
			MakeObservableClass( self.target ) ;
			
			[ ((NSObject*)self.target).nwgRegisteredKeyValueObservers addObject:self ] ;
			[ self.target addObserver:self forKeyPath:self.keyPath options:self.options context:(__bridge void *)self ] ;
		}
		@catch( id e )
		{
			NSLog(@"%s:%u exception %@\n", __PRETTY_FUNCTION__, __LINE__, e ) ;
		}
		
	}
}

-(void)stopObserving
{
	@synchronized( self )
	{
		NSMutableSet * observers = ((NSObject*)self.target).nwgRegisteredKeyValueObservers ;
		
		if ( [ observers containsObject:self ] )
		{
			[ self.target removeObserver:self forKeyPath:self.keyPath ] ;
			[ observers removeObject:self ] ;
		}
	}
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ( context == (__bridge void *)self )
	{
		self.block( change ) ;
	}
	else
	{
		[ super observeValueForKeyPath:keyPath ofObject:object change:change context:context ] ;
	}
}

-(void)dealloc
{
	[ self stopObserving ] ;
}

-(NSString *)description
{
	NSString * __bitNames[] = {
		@"NEW", @"OLD", @"INITIAL", @"PRIOR"
	} ;
	
	NSUInteger options = self.options ;
	NSUInteger mask = 0x1 ;
	NSMutableArray * kinds = [ NSMutableArray array ] ;
	for( int index=0; index < (sizeof( __bitNames ) / sizeof( __bitNames[0] )); ++index )
	{
		if ( ( mask & options ) != 0 ) { [ kinds addObject:__bitNames[ index ] ] ; }
		mask <<= 1 ;
	}
	
	return [ NSString stringWithFormat:@"%@<%p> keyPath=%@ target=%@ kinds=%@", [ self class ], self, self.keyPath, self.target, [ kinds componentsJoinedByString:@"," ] ] ;
}

-(void)observedObjectWillDealloc
{
	[ self stopObserving ] ;
}

@end

@implementation NSObject (KeyValueObserving)

static const char * kNWGRegisteredKeyValueObserversKey = "kNWGRegisteredKeyValueObserversKey" ;

-(NSMutableSet *)nwgRegisteredKeyValueObservers
{
	NSMutableSet * result = objc_getAssociatedObject( self, kNWGRegisteredKeyValueObserversKey ) ;
	if ( !result )
	{
		result = [ NSMutableSet set ] ;
		objc_setAssociatedObject( self, kNWGRegisteredKeyValueObserversKey, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC ) ;
	}
	
	return result ;
}

-(void)removeKVOObservers
{
	[ self.nwgRegisteredKeyValueObservers makeObjectsPerformSelector:@selector( observedObjectWillDealloc ) ] ;
}

@end
