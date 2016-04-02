# IRCoreDataStack

[![Version](https://img.shields.io/cocoapods/v/IRCoreDataStack.svg?style=flat-square)](http://cocoapods.org/pods/IRCoreDataStack)
[![License](https://img.shields.io/cocoapods/l/IRCoreDataStack.svg?style=flat-square)](http://cocoapods.org/pods/IRCoreDataStack)
[![Platform](https://img.shields.io/cocoapods/p/IRCoreDataStack.svg?style=flat-square)](http://cocoapods.org/pods/IRCoreDataStack)

Stack with two independent NSManagedObjectContext instances, based on the performance analisys of [this blog article](http://floriankugler.com/blog/2013/4/29/concurrent-core-data-stack-performance-shootout).
Automatically sync of changes by automatically merging changes between the background context and the main context.
Supports automatic database migration.

##  Under the hood:
* CRUD operations goes in the `IRCoreDataStack.backgroundManagedObjectContext`, calling contextSave automatically sends a NSManagedObjectContextDidSaveNotification.
* Changes are merged into the `IRCoreDataStack.managedObjectContext`, by listening for the NSManagedObjectContextDidSaveNotification followed by a mergeChangesFromContextDidSaveNotification.
* Fetches should be done on the main `IRCoreDataStack.managedObjectContext`...

## Installation

#### Podfile

```ruby
platform :ios, '8.0'
pod 'IRCoreDataStack', '~> 1.0'
```

Then, run the following command:

```bash
$ pod install
```

## Getting started
You've got the main IRCoreDataStack to setup the stack and an included category to help in operations.

#### Init stack
```objc
IRCoreDataStack *coreDataStack = [[IRCoreDataStack alloc] initWithType:NSSQLiteStoreType
														 modelFilename:@"nameOfTheModelFile"
															  inBundle:[NSBundle mainBundle]];
```

#### Insert
You can make use of the method included category to create an entity on the correct context.
```objc
NSManagedObject *managedObject = [coreDataStack createEntityWithClassName:classNameString
                                                     attributesDictionary:attributesDictionary];
```

#### Fetch
You can make use of the methods included category and you'll get the results in the completion block.
This is the simple one:

```objc
NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uuid == %@", [obj uuid]];
[self.coreDataStack fetchEntriesForClassName:className
                               withPredicate:predicate
                             sortDescriptors:nil
                             completionBlock:^(NSArray *results) {
                                 // Your completion block
                             }];
```

#### Save
After operations, you should save your changes, on the backgroundManagedObjectContext, using the helper method saveIntoBackgroundContextUsingBlock:

```objc

[self.coreDataStack saveIntoBackgroundContextUsingBlock:^(BOOL saved, NSError *error) {
    // Your completion block
}];

```

#### Delete
Trivial as the previous ones. We've got other methods available too...

```objc

NSManagedObjectContext *bmoc = self.coreDataStack.backgroundManagedObjectContext;

[self.coreDataStack deleteAllFromEntity:nameEntity inManagedObjectContext:bmoc];

// Despite this method is called save, actually, from the previous operations, is going to delete the objects
[self.coreDataStack saveIntoContext:bmoc usingBlock:^(BOOL saved, NSError *error) {
    // You should call processPendingChanges before inspecting deletedObjects of NSManagedObjectContext. 
    // At least if some relationships have deleteRule set to NSCascadeDeleteRule.
    // http://stackoverflow.com/questions/5709302/when-and-how-often-to-call-processpendingchanges-to-ensure-graph-integrity
    // if(saved) [bmoc processPendingChanges];
}];

```

## License

MIT
