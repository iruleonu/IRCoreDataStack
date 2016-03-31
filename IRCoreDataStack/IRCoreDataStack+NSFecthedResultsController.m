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

#import "IRCoreDataStack+NSFecthedResultsController.h"

@implementation IRCoreDataStack (NSFecthedResultsController)

- (BOOL)uniqueAttributeForClassName:(NSString *)className attributeName:(NSString *)attributeName attributeValue:(id)attributeValue {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K like %@", attributeName, attributeValue];
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:attributeName ascending:YES]];
    
    NSFetchedResultsController *fetchedResultsController = [self fetchEntitiesWithClassName:className
                                                                                  predicate:predicate
                                                                            sortDescriptors:sortDescriptors
                                                                                  batchSize:0
                                                                         sectionNameKeyPath:nil
                                                                                  cacheName:nil];
    return fetchedResultsController.fetchedObjects.count == 0;
}

- (NSFetchedResultsController *)controllerWithEntitiesName:(NSString *)className
                                                 predicate:(NSPredicate *)predicate
                                           sortDescriptors:(NSArray *)sortDescriptors
                                                 batchSize:(NSUInteger)batchSize
                                        sectionNameKeyPath:(NSString *)sectionNameKeypath
                                                 cacheName:(NSString *)cacheName {
    NSFetchedResultsController *fetchedResultsController;
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:className inManagedObjectContext:self.managedObjectContext];
    fetchRequest.entity = entity;
    fetchRequest.sortDescriptors = sortDescriptors;
    fetchRequest.predicate = predicate;
    fetchRequest.shouldRefreshRefetchedObjects = YES;
    fetchRequest.fetchBatchSize = batchSize;
    //fetchRequest.fetchLimit = fetchLimit;
    
    fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                   managedObjectContext:self.managedObjectContext
                                                                     sectionNameKeyPath:sectionNameKeypath
                                                                              cacheName:cacheName];
    
    return fetchedResultsController;
}

- (NSFetchedResultsController *)fetchEntitiesWithClassName:(NSString *)className
                                                 predicate:(NSPredicate *)predicate
                                           sortDescriptors:(NSArray *)sortDescriptors
                                                 batchSize:(NSUInteger)batchSize
                                        sectionNameKeyPath:(NSString *)sectionNameKeypath
                                                 cacheName:(NSString *)cacheName {
    NSFetchedResultsController *fetchedResultsController = [self controllerWithEntitiesName:className
                                                                                  predicate:predicate
                                                                            sortDescriptors:sortDescriptors
                                                                                  batchSize:batchSize
                                                                         sectionNameKeyPath:sectionNameKeypath
                                                                                  cacheName:cacheName];
    NSError *error = nil;
    BOOL success = [fetchedResultsController performFetch:&error];
    
    if (!success) {
        NSLog(@"fetchManagedObjectsWithClassName error -> %@", error.description);
    }
    
    return fetchedResultsController;
}

@end
