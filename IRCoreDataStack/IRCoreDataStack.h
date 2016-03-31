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

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

extern NSString *const IRCoreDataStackErrorDomain;

enum {
    IRCoreDataStackMappingModelNotFound = 1,
    IRCoreDataStackManagedObjectModelNotFound
};

/**
 *  Merge and notification behaviour Core Data Stack
 *  -CRUD operations goes in the backgroundManagedObjectContext, after operations, contextSave automatically sends a NSManagedObjectContextDidSaveNotification
 *  -Listening for the updated changes is performed on the managedObjectContext, by listening for the NSManagedObjectContextDidSaveNotification
 *  followed by a mergeChangesFromContextDidSaveNotification
 *  -Fetches uses the main managedObjectContext...
 */
@interface IRCoreDataStack : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectContext *backgroundManagedObjectContext;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (instancetype)init NS_DESIGNATED_INITIALIZER NS_UNAVAILABLE;
- (instancetype)initWithType:(NSString *)storeType storeUrl:(NSURL *)storeUrl modelUrl:(NSURL *)modelURL inBundle:(NSBundle *)bundle NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithType:(NSString *)storeType modelFilename:(NSString *)modelFilename inBundle:(NSBundle *)bundle;

@end

@interface IRCoreDataStack (Migration)

@property (nonatomic, readonly) BOOL requiresMigration;

- (BOOL)migrateDataStore:(NSError **)error;

@end
