//
//  The MIT License (MIT)
//  Copyright (c) 2016 Nuno Salvador
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "IRCDStack.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <libkern/OSAtomic.h>
#import <UIKit/UIKit.h>

static void class_swizzleSelector(Class class, SEL originalSelector, SEL newSelector) {
    Method origMethod = class_getInstanceMethod(class, originalSelector);
    Method newMethod = class_getInstanceMethod(class, newSelector);
    if(class_addMethod(class, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(class, newSelector, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    }
    else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

NSString *const CoreDataStackErrorDomain = @"CoreDataStackErrorDomain";

@interface IRCDStack ()

@property (nonatomic, strong) NSString *storeType;
@property (nonatomic, strong) NSURL *storeURL;
@property (nonatomic, strong) NSURL *modelURL;
@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong, readwrite) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readwrite) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readwrite) NSManagedObjectContext *backgroundManagedObjectContext;

@end

@implementation IRCDStack

#pragma mark - Initialization

- (instancetype)init {
    return [super init];
}

- (instancetype)initWithType:(NSString *)storeType modelFilename:(NSString *)modelFilename inBundle:(NSBundle *)bundle {
    NSURL *momOrMomdURL = [IRCDStack getMomFileURLWithFilename:modelFilename inBundle:bundle];
    NSURL *libraryDirectory = [[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask].lastObject;
    NSURL *storeUrl = [libraryDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite", modelFilename]];
    return [self initWithType:NSSQLiteStoreType storeUrl:storeUrl modelUrl:momOrMomdURL inBundle:bundle];
}

- (instancetype)initWithType:(NSString *)storeType storeUrl:(NSURL *)storeUrl modelUrl:(NSURL *)modelURL inBundle:(NSBundle *)bundle {
    if (self = [super init]) {
        self.storeType = storeType;
        self.storeURL = storeUrl;
        self.modelURL = modelURL;
        self.bundle = bundle;
        
        self.managedObjectContext = [self setupManagedObjectContextWithConcurrencyType:NSMainQueueConcurrencyType];
        self.backgroundManagedObjectContext = [self setupManagedObjectContextWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
#if TARGET_OS_IOS
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automaticallySaveDataStore)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automaticallySaveDataStore)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#elif TARGET_OS_WATCH
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(automaticallySaveDataStore)
                                                     name:NSExtensionHostDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSManagedObjectContext *)setupManagedObjectContextWithConcurrencyType:(NSManagedObjectContextConcurrencyType)concurrencyType {
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];
    managedObjectContext.persistentStoreCoordinator = [self persistentStoreCoordinator];
    managedObjectContext.mergePolicy = concurrencyType == NSMainQueueConcurrencyType ? [self mainThreadMergePolicy] : [self backgroundThreadMergePolicy];
    managedObjectContext.undoManager = nil; // This is be especially beneficial for background worker threads, as well as for large import or batch operations.
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(managedObjectContextDidSaveNotificationCallback:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:managedObjectContext];
    
    return managedObjectContext;
}

#pragma mark - Core Data stack

- (NSManagedObjectModel *)managedObjectModel {
    // The managed object model for the application. It is a fatal error for the application not to be able to find and load its model.
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    
    // Create the expected store dir
    NSString *storeDirectory = self.storeURL.URLByDeletingLastPathComponent.path;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:storeDirectory isDirectory:NULL]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:storeDirectory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        
        NSAssert(error == nil, @"Error while creating default store url %@:\nError: \"%@\"", storeDirectory, error);
    }
    
    // Create the NSManagedObjectModel
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:self.modelURL];
    NSAssert(_managedObjectModel != nil, @"NSManagedObjectModel is nil when initialized with %@", self.modelURL);
    
    return _managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it.
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSError *error = nil;
    NSDictionary *persistentStoreCoordinatorOptions = @{ NSSQLitePragmasOption : @{@"journal_mode" : @"WAL"},
                                                         NSMigratePersistentStoresAutomaticallyOption: @YES,
                                                         NSInferMappingModelAutomaticallyOption : @YES };
    // Check if we need a migration, or is the current model is incompatible
    // (based on: http://pablin.org/2013/05/24/problems-with-core-data-migration-manager-and-journal-mode-wal/)
    if (self.requiresMigration) {
        NSError *error = nil;
        if (![self migrateDataStore:&error]) {
            NSLog(@"[CoreDataStack] migrating data store failed: %@", error);
        }
    }
    
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    NSPersistentStore *persistentStore = [_persistentStoreCoordinator addPersistentStoreWithType:self.storeType configuration:nil URL:self.storeURL options:persistentStoreCoordinatorOptions error:&error];
    if (!persistentStore) {
        // Report any error we got.
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[NSLocalizedDescriptionKey] = @"Failed to initialize the application's saved data";
        dict[NSLocalizedFailureReasonErrorKey] = @"There was an error creating or loading the application's saved data.";
        dict[NSUnderlyingErrorKey] = error;
        error = [NSError errorWithDomain:CoreDataStackErrorDomain code:9999 userInfo:dict];
        NSLog(@"[CoreDataStack] could not add persistent store: %@", error);
        NSLog(@"[CoreDataStack] deleting old data store");
        [[NSFileManager defaultManager] removeItemAtURL:self.storeURL error:NULL];
        
        persistentStore = [_persistentStoreCoordinator addPersistentStoreWithType:self.storeType configuration:nil URL:self.storeURL options:persistentStoreCoordinatorOptions error:&error];
        if (!persistentStore) {
            NSLog(@"[CoreDataStack] could not add persistent store: %@", error);
            abort();
        }
    }
    
#ifdef DEBUG
    [self enableCoreDataThreadDebugging];
#endif
    
    return _persistentStoreCoordinator;
}

#pragma mark - Custom

+ (NSURL *)getMomFileURLWithFilename:(NSString *)filename inBundle:(NSBundle *)bundle {
    NSURL *momURL = [bundle URLForResource:filename withExtension:@"mom"];
    NSURL *momdURL = [bundle URLForResource:filename withExtension:@"momd"];
    
    if (momURL && momdURL) {
        NSDate *momCreationDate = [[NSFileManager defaultManager] attributesOfItemAtPath:momURL.path error:NULL].fileCreationDate;
        NSDate *momdCreationDate = [[NSFileManager defaultManager] attributesOfItemAtPath:momdURL.path error:NULL].fileCreationDate;

        if (momCreationDate.timeIntervalSince1970 > momdCreationDate.timeIntervalSince1970) {
            momdURL = nil;
        }
        else {
            momURL = nil;
        }
    }
    
    NSAssert(momURL != nil || momdURL != nil, @"No %@.mom or %@.momd found in the bundle %@", filename, filename, bundle);
    
    return momURL ? : momdURL;
}

- (id)mainThreadMergePolicy {
    return NSMergeByPropertyObjectTrumpMergePolicy;
}

- (id)backgroundThreadMergePolicy {
    return NSMergeByPropertyObjectTrumpMergePolicy;
}

- (NSArray *)currentManagedObjectsContexts {
    NSMutableArray *mocs = [NSMutableArray array];

    NSManagedObjectContext *mainThreadManagedObjectContext = self.managedObjectContext;
    if (mainThreadManagedObjectContext) {
        [mocs addObject:mainThreadManagedObjectContext];
    }

    NSManagedObjectContext *backgroundThreadManagedObjectContext = self.backgroundManagedObjectContext;
    if (backgroundThreadManagedObjectContext) {
        [mocs addObject:backgroundThreadManagedObjectContext];
    }
    
    return mocs;
}

- (void)managedObjectContextDidSaveNotificationCallback:(NSNotification *)notification {
    NSManagedObjectContext *changedContext = notification.object;

    for (NSManagedObjectContext *otherContext in [self currentManagedObjectsContexts]) {
        if (changedContext.persistentStoreCoordinator == otherContext.persistentStoreCoordinator && otherContext != changedContext) {
            if (changedContext == self.backgroundManagedObjectContext) {
                [otherContext performBlockAndWait:^{
                    [otherContext mergeChangesFromContextDidSaveNotification:notification];
                }];
            }
            else {
                [otherContext performBlock:^{
                    [otherContext mergeChangesFromContextDidSaveNotification:notification];
                }];
            }
        }
    }
}

- (void)automaticallySaveDataStore {
    for (NSManagedObjectContext *context in [self currentManagedObjectsContexts]) {
        if (!context.hasChanges) {
            continue;
        }
        
        [context performBlock:^{
            NSError *error = nil;
            if (![context save:&error]) {
                NSLog(@"WARNING: Error while automatically saving changes from DataStore of class %@: %@", self, error);
            }
        }];
    }
}

- (void)enableCoreDataThreadDebugging {
    @synchronized(self) {
        NSManagedObjectModel *model = self.persistentStoreCoordinator.managedObjectModel;
        
        for (NSEntityDescription *entity in model.entities) {
            Class class = NSClassFromString(entity.managedObjectClassName);
            
            if (!class || objc_getAssociatedObject(class, _cmd)) {
                continue;
            }
            
            IMP implementation = imp_implementationWithBlock(^(id _self, NSString *key) {
                struct objc_super super = {
                    .receiver = _self,
                    .super_class = [class superclass]
                };
                ((void(*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&super, @selector(willAccessValueForKey:), key);
            });
            class_addMethod(class, @selector(willAccessValueForKey:), implementation, "v@:@");
            
            implementation = imp_implementationWithBlock(^(id _self, NSString *key) {
                struct objc_super super = {
                    .receiver = _self,
                    .super_class = [class superclass]
                };
                ((void(*)(struct objc_super *, SEL, id))objc_msgSendSuper)(&super, @selector(willChangeValueForKey:), key);
            });
            class_addMethod(class, @selector(willChangeValueForKey:), implementation, "v@:@");
            
            objc_setAssociatedObject(class, _cmd, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

@end

@implementation IRCDStack (Migration)

- (BOOL)requiresMigration {
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000
    NSDictionary *options = @{
                              NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES
                              };
    
    NSDictionary *sourceStoreMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.storeType URL:self.storeURL options:options error:NULL];
#else
    NSDictionary *sourceStoreMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.storeType URL:self.storeURL error:NULL];
#endif
    
    if (!sourceStoreMetadata) {
        return NO;
    }
    
    return ![self.managedObjectModel isConfiguration:nil compatibleWithStoreMetadata:sourceStoreMetadata];
}

- (BOOL)migrateDataStore:(NSError **)error {
    static OSSpinLock lock = OS_SPINLOCK_INIT;
    
    OSSpinLockLock(&lock);
    
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES,
                               NSInferMappingModelAutomaticallyOption: @YES };
    
    NSError *addStoreError = nil;
    NSPersistentStoreCoordinator *persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
    
    if ([persistentStoreCoordinator addPersistentStoreWithType:self.storeType configuration:nil URL:self.storeURL options:options error:&addStoreError]) {
        NSLog(@"[CoreDataStack] automatic persistent store migration completed %@", options);
        OSSpinLockUnlock(&lock);
        return YES;
    } else {
        NSLog(@"[CoreDataStack] could not automatic migrate persistent store with %@", options);
        NSLog(@"[CoreDataStack] addStoreError = %@", addStoreError);
    }
    
    BOOL success = [self performMigrationFromDataStoreAtURL:self.storeURL toDestinationModel:self.managedObjectModel error:error];
    OSSpinLockUnlock(&lock);
    
    return success;
}


- (BOOL)performMigrationFromDataStoreAtURL:(NSURL *)dataStoreURL
                        toDestinationModel:(NSManagedObjectModel *)destinationModel
                                     error:(NSError **)error {
    BOOL(^updateError)(NSInteger errorCode, NSString *description) = ^BOOL(NSInteger errorCode, NSString *description) {
        if (!error) {
            return NO;
        }
        
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: description };
        *error = [NSError errorWithDomain:CoreDataStackErrorDomain code:errorCode userInfo:userInfo];
        
        return NO;
    };
    
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES,
                               NSInferMappingModelAutomaticallyOption: @YES };
    
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.storeType URL:dataStoreURL options:options error:error];
#else
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:self.storeType URL:dataStoreURL error:error];
#endif
    
    if (!sourceMetadata) {
        return NO;
    }
    
    if ([destinationModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata]) {
        return YES;
    }
    
    NSArray *bundles = @[ self.bundle ];
    NSManagedObjectModel *sourceModel = [NSManagedObjectModel mergedModelFromBundles:bundles forStoreMetadata:sourceMetadata];
    
    if (!sourceModel) {
        return updateError(IRCDStackManagedObjectModelNotFound, [NSString stringWithFormat:@"NSManagedObjectModel is nil for source metadata %@", sourceMetadata]);
    }
    
    NSMutableArray *objectModelPaths = [NSMutableArray array];
    NSArray *allManagedObjectModels = [self.bundle pathsForResourcesOfType:@"momd" inDirectory:nil];
    
    for (NSString *managedObjectModelPath in allManagedObjectModels) {
        NSArray *array = [self.bundle pathsForResourcesOfType:@"mom" inDirectory:managedObjectModelPath.lastPathComponent];
        [objectModelPaths addObjectsFromArray:array];
    }
    
    NSArray *otherModels = [self.bundle pathsForResourcesOfType:@"mom" inDirectory:nil];
    [objectModelPaths addObjectsFromArray:otherModels];
    
    if (objectModelPaths.count == 0) {
        return updateError(IRCDStackManagedObjectModelNotFound, [NSString stringWithFormat:@"No NSManagedObjectModels found in bundle %@", self.bundle]);
    }
    
    NSMappingModel *mappingModel = nil;
    NSManagedObjectModel *targetModel = nil;
    NSString *modelPath = nil;
    
    for (modelPath in objectModelPaths.reverseObjectEnumerator) {
        NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
        targetModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        mappingModel = [NSMappingModel mappingModelFromBundles:bundles forSourceModel:sourceModel destinationModel:targetModel];
        if (mappingModel) {
            break;
        }
    }
    
    if (!mappingModel) {
        return updateError(IRCDStackMappingModelNotFound, [NSString stringWithFormat:@"Unable to find NSMappingModel for store at URL %@", dataStoreURL]);
    }
    
    NSMigrationManager *migrationManager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel destinationModel:targetModel];
    
    NSString *modelName = modelPath.lastPathComponent.stringByDeletingPathExtension;
    NSString *storeExtension = dataStoreURL.path.pathExtension;
    NSString *storePath = dataStoreURL.path.stringByDeletingPathExtension;
    NSString *destinationPath = [NSString stringWithFormat:@"%@.%@.%@", storePath, modelName, storeExtension];
    NSURL *destinationURL = [NSURL fileURLWithPath:destinationPath];
    
    // By this point store meta data is not compatible. Change journal mode to delete for full suport
    NSDictionary *sourceOptions = @{ NSSQLitePragmasOption: @{@"journal_mode": @"DELETE"},
                                     NSMigratePersistentStoresAutomaticallyOption : @YES,
                                     NSInferMappingModelAutomaticallyOption : @YES };
    BOOL didMigrate = [migrationManager migrateStoreFromURL:dataStoreURL
                                                       type:self.storeType
                                                    options:sourceOptions
                                           withMappingModel:mappingModel
                                           toDestinationURL:destinationURL
                                            destinationType:self.storeType
                                         destinationOptions:options
                                                      error:error];
    if (!didMigrate) {
        return NO;
    }
    
    if (![[NSFileManager defaultManager] removeItemAtURL:dataStoreURL error:error]) {
        return NO;
    }
    
    if (![[NSFileManager defaultManager] moveItemAtURL:destinationURL toURL:dataStoreURL error:error]) {
        return NO;
    }
    
    return [self performMigrationFromDataStoreAtURL:dataStoreURL
                                 toDestinationModel:destinationModel
                                              error:error];
}

@end

#ifdef DEBUG
@implementation NSManagedObject (CoreDataStackCoreDataThreadDebugging)

+ (void)load {
    class_swizzleSelector(self, @selector(willChangeValueForKey:), @selector(_CoreDataStackCoreDataThreadDebuggingWillChangeValueForKey:));
    class_swizzleSelector(self, @selector(willAccessValueForKey:), @selector(_CoreDataStackCoreDataThreadDebuggingWillAccessValueForKey:));
}

- (void)_CoreDataStackCoreDataThreadDebuggingWillAccessValueForKey:(NSString *)key {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSManagedObjectContext *context = self.managedObjectContext;

    if (context && context.concurrencyType != NSConfinementConcurrencyType) {
        __block dispatch_queue_t queue = NULL;
        [context performBlockAndWait:^{
            queue = dispatch_get_current_queue();
        }];

        NSAssert(queue == dispatch_get_current_queue(), @"Wrong queue, perform a block...");
    }

#pragma clang diagnostic pop

    [self _CoreDataStackCoreDataThreadDebuggingWillAccessValueForKey:key];
}

- (void)_CoreDataStackCoreDataThreadDebuggingWillChangeValueForKey:(NSString *)key
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSManagedObjectContext *context = self.managedObjectContext;

    if (context) {
        __block dispatch_queue_t queue = NULL;
        [context performBlockAndWait:^{
            queue = dispatch_get_current_queue();
        }];

        NSAssert(queue == dispatch_get_current_queue(), @"Wrong queue, perform a block...");
    }

#pragma clang diagnostic pop

    [self _CoreDataStackCoreDataThreadDebuggingWillChangeValueForKey:key];
}

@end
#endif
