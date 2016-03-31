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

#import "IRCoreDataStack+Operations.h"

@implementation IRCoreDataStack (Operations)

- (BOOL)saveIntoBackgroundContext { 
    return [self saveIntoContext:self.backgroundManagedObjectContext];
}

- (BOOL)saveIntoContext:(NSManagedObjectContext*)context {
    BOOL check = NO;
    
    NSManagedObjectContext *managedObjectContext = (context == nil) ? self.backgroundManagedObjectContext : context;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate.
            // You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            //abort();
        }
        else check = YES;
    }
    
    return check;
}

- (void)saveIntoBackgroundContextUsingBlock:(IRCoreDataStackSaveCompletion)savedBlock {
    [self saveIntoContext:self.backgroundManagedObjectContext usingBlock:savedBlock];
}

- (void)saveIntoContext:(NSManagedObjectContext*)context usingBlock:(IRCoreDataStackSaveCompletion)savedBlock {
    __block NSError *saveError = nil;
    NSManagedObjectContext *managedObjectContext = (context == nil) ? self.backgroundManagedObjectContext : context;
    __block BOOL saved = NO;
    
    if ([managedObjectContext hasChanges]) {
        [managedObjectContext performBlockAndWait:^{
            saved = [managedObjectContext save:&saveError];
        }];
    }
    
    if (savedBlock) {
        savedBlock(saved, saveError);
    }
}

- (id)createEntityWithClassName:(NSString *)className attributesDictionary:(NSDictionary *)attributesDictionary {
    return [self createEntityWithClassName:className attributesDictionary:attributesDictionary inManagedObjectContext:self.backgroundManagedObjectContext];
}

- (id)createEntityWithClassName:(NSString *)className
           attributesDictionary:(NSDictionary *)attributesDictionary
         inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObject *entity = [NSEntityDescription insertNewObjectForEntityForName:className
                                                            inManagedObjectContext:context];
    
    for (NSString *key in attributesDictionary.allKeys) {
        NSObject *obj = attributesDictionary[key];
        if (![obj isEqual:[NSNull null]]) {
            // Ensure same thread
            [context performBlock:^{
                [entity setValue:obj forKey:key];
            }];
        }
    }
    
    return entity;
}

- (void)deleteEntity:(NSManagedObject *)entity {
    [self.backgroundManagedObjectContext deleteObject:entity];
}

- (void)deleteAllFromEntity:(NSString *)entityName {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entityName];
    NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    NSError *deleteError = nil;
    [self.backgroundManagedObjectContext executeRequest:delete error:&deleteError];
}

- (void)deleteEntity:(NSManagedObject *)entity inManagedObjectContext:(NSManagedObjectContext *)context {
    [context deleteObject:entity];
}

- (void)deleteAllFromEntity:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entityName];
    NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    NSError *deleteError = nil;
    [context executeRequest:delete error:&deleteError];
}

- (void)fetchEntriesForClassName:(NSString *)className
                   withPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
                 completionBlock:(IRCoreDataStackFetchCompletionBlock)completionBlock {
    [self fetchEntriesForClassName:className
                     withPredicate:predicate
                   sortDescriptors:sortDescriptors
              managedObjectContext:self.managedObjectContext
                   completionBlock:completionBlock];
}

- (void)fetchEntriesForClassName:(NSString *)className
                   withPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
            managedObjectContext:(NSManagedObjectContext *)context
                 completionBlock:(IRCoreDataStackFetchCompletionBlock)completionBlock {
    [self fetchEntriesForClassName:className
                     withPredicate:predicate
                   sortDescriptors:sortDescriptors
              managedObjectContext:context
                      asynchronous:YES
                   completionBlock:completionBlock];
}

- (void)fetchEntriesForClassName:(NSString *)className
                   withPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
            managedObjectContext:(NSManagedObjectContext *)context
                    asynchronous:(BOOL)asynchronous
                 completionBlock:(IRCoreDataStackFetchCompletionBlock)completionBlock {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = sortDescriptors;
    if (!context) {
        context = self.managedObjectContext;
    }
    fetchRequest.entity = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    
    if (asynchronous) {
        [context performBlock:^{
            NSArray *results = [context executeFetchRequest:fetchRequest error:NULL];
            if (completionBlock) {
                completionBlock(results);
            }
        }];
    }
    else {
        [context performBlockAndWait:^{
            NSArray *results = [context executeFetchRequest:fetchRequest error:NULL];
            if (completionBlock) {
                completionBlock(results);
            }
        }];
    }
}

@end
