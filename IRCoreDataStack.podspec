Pod::Spec.new do |spec|
  spec.name          = "IRCoreDataStack"
  spec.version       = "1.0.4"
  spec.summary       = "CoreDataStack with two independent NSManagedObjectContext instances"
  spec.homepage      = "https://github.com/iruleonu/IRCoreDataStack"
  spec.license       = { :type => "MIT", :file => "LICENSE.md" }
  spec.author        = { "Nuno Salvador" => "nuno@salvador.com" }
  spec.source        = { :git => "https://github.com/iruleonu/IRCoreDataStack.git", :tag => spec.version.to_s }
  spec.requires_arc  = true
  spec.frameworks    = "Foundation", "CoreData"
  spec.ios.deployment_target = "8.0"
  spec.tvos.deployment_target = "9.0"
  spec.watchos.deployment_target = "2.0"
  spec.osx.deployment_target = "10.10"
  
  spec.subspec "IOS_TVOS_WATCHOS" do |sub|
    sub.source_files  = "IRCoreDataStack"
    sub.ios.deployment_target = "8.0"
    sub.tvos.deployment_target = "9.0"
    sub.watchos.deployment_target = "2.0"
  end

  spec.subspec "OSX" do |sub|
    sub.source_files  = ["IRCoreDataStack"]
    sub.exclude_files = ["IRCoreDataStack/IRCoreDataStack+NSFecthedResultsController.{h,m}"]
    sub.platform = :osx, "10.10"
  end
end

