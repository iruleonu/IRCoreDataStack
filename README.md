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
NSManagedObject *managedObject = [coreDataStack createEntityWithClassName:className
													 attributesDictionary:attributesDictionary];
```

#### Fetch
You can make use of the method included category and you'll get the results in the completion block.
```objc
[coreDataStack fetchEntriesForClassName:className
						  withPredicate:predicate
						sortDescriptors:sortDescriptors
						completionBlock:completionBlock];
```

#### Deleting and saving
Trivial has the previous ones.

For deleting you've got deleteEntity: or deleteAllFromEntity:

For saving you've got saveIntoMainContext or saveIntoMainContextUsingBlock: 

## License

MIT
