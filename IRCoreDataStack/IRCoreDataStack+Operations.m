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
    
    NSManagedObjectContext *moc = (context == nil) ? self.backgroundManagedObjectContext : context;
    if (moc != nil) {
        NSError *error = nil;
        if ([moc hasChanges] && ![moc save:&error]) {
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
    NSManagedObjectContext *moc = (context == nil) ? self.backgroundManagedObjectContext : context;
    __block BOOL saved = NO;
    
    if ([moc hasChanges]) {
        [moc performBlockAndWait:^{
            saved = [moc save:&saveError];
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
    NSManagedObjectContext *moc = (context == nil) ? self.backgroundManagedObjectContext : context;
    NSManagedObject *entity = [NSEntityDescription insertNewObjectForEntityForName:className
                                                            inManagedObjectContext:moc];
    
    for (NSString *key in attributesDictionary.allKeys) {
        NSObject *obj = attributesDictionary[key];
        if (![obj isEqual:[NSNull null]]) {
            // Ensure same thread
            [moc performBlockAndWait:^{
                [entity setValue:obj forKey:key];
            }];
        }
    }
    
    return entity;
}

- (void)deleteEntity:(NSManagedObject *)entityMO {
    [self deleteEntity:entityMO inManagedObjectContext:self.backgroundManagedObjectContext];
}

- (void)deleteAllFromEntity:(NSString *)entityName {
    [self deleteAllFromEntity:entityName inManagedObjectContext:self.backgroundManagedObjectContext];
}

- (void)deleteEntity:(NSManagedObject *)entityMO inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObjectContext *moc = (context == nil) ? self.backgroundManagedObjectContext : context;
    [moc deleteObject:entityMO];
}

- (void)deleteAllFromEntity:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context {
    NSManagedObjectContext *moc = (context == nil) ? self.backgroundManagedObjectContext : context;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:entityName];
    NSBatchDeleteRequest *delete = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
    NSError *deleteError = nil;
    [moc executeRequest:delete error:&deleteError];
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
    NSManagedObjectContext *moc = (context == nil) ? self.managedObjectContext : context;
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.predicate = predicate;
    fetchRequest.sortDescriptors = sortDescriptors;
    fetchRequest.entity = [NSEntityDescription entityForName:className inManagedObjectContext:moc];
    
    if (asynchronous) {
        [moc performBlock:^{
            NSArray *results = [moc executeFetchRequest:fetchRequest error:NULL];
            if (completionBlock) {
                completionBlock(results);
            }
        }];
    }
    else {
        [moc performBlockAndWait:^{
            NSArray *results = [moc executeFetchRequest:fetchRequest error:NULL];
            if (completionBlock) {
                completionBlock(results);
            }
        }];
    }
}

@end
