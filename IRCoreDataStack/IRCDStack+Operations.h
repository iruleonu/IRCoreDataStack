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

#import <IRCoreDataStack/IRCDStack.h>

typedef void(^IRCDStackSaveCompletion)(BOOL saved, NSError *error);
typedef void(^IRCDStackFetchCompletionBlock)(NSArray *results);

@interface IRCDStack (Operations)

// Saving
- (BOOL)saveIntoBackgroundContext;
- (BOOL)saveIntoContext:(NSManagedObjectContext*)context;
- (void)saveIntoBackgroundContextUsingBlock:(IRCDStackSaveCompletion)savedBlock;
- (void)saveIntoContext:(NSManagedObjectContext*)context usingBlock:(IRCDStackSaveCompletion)savedBlock;

// CRUD
- (id)createEntityWithClassName:(NSString *)className
           attributesDictionary:(NSDictionary *)attributesDictionary;
- (id)createEntityWithClassName:(NSString *)className
           attributesDictionary:(NSDictionary *)attributesDictionary
         inManagedObjectContext:(NSManagedObjectContext *)context;
- (void)deleteEntity:(NSManagedObject *)entityMO;
- (void)deleteAllFromEntity:(NSString *)entityName NS_AVAILABLE_IOS(9_0);
- (void)deleteEntity:(NSManagedObject *)entityMO inManagedObjectContext:(NSManagedObjectContext *)context;
- (void)deleteAllFromEntity:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context NS_AVAILABLE_IOS(9_0);

// FETCHING
- (void)fetchEntriesForClassName:(NSString *)className
                   withPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
                 completionBlock:(IRCDStackFetchCompletionBlock)completionBlock;
- (void)fetchEntriesForClassName:(NSString *)className
                   withPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
            managedObjectContext:(NSManagedObjectContext *)context
                 completionBlock:(IRCDStackFetchCompletionBlock)completionBlock;
- (void)fetchEntriesForClassName:(NSString *)className
                   withPredicate:(NSPredicate *)predicate
                 sortDescriptors:(NSArray *)sortDescriptors
            managedObjectContext:(NSManagedObjectContext *)context
                    asynchronous:(BOOL)asynchronous
                 completionBlock:(IRCDStackFetchCompletionBlock)completionBlock;

@end
