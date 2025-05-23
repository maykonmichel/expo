// Copyright 2015-present 650 Industries. All rights reserved.

#import "EXAppState.h"
#import "EXAppViewController.h"
#import "EXBuildConstants.h"
#import "EXKernel.h"
#import "EXAbstractLoader.h"
#import "EXKernelAppRecord.h"
#import "EXKernelLinkingManager.h"
#import "EXLinkingManager.h"
#import "EXVersions.h"
#import "EXHomeModule.h"

#import <EXConstants/EXConstantsService.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTModuleData.h>
#import <React/RCTUtils.h>

// Kernel is DevMenu's delegate only in non-detached builds.
#import "EXDevMenuManager.h"
#import "EXDevMenuDelegateProtocol.h"

@interface EXKernel () <EXDevMenuDelegateProtocol>
@end

NS_ASSUME_NONNULL_BEGIN

NSString *kEXKernelErrorDomain = @"EXKernelErrorDomain";
NSString *kEXKernelShouldForegroundTaskEvent = @"foregroundTask";
NSString * const kEXKernelClearJSCacheUserDefaultsKey = @"EXKernelClearJSCacheUserDefaultsKey";
NSString * const kEXReloadActiveAppRequest = @"EXReloadActiveAppRequest";

// Protocol that should be implemented by all versions of EXAppState class.
@protocol EXAppStateProtocol

@property (nonatomic, strong, readonly) NSString *lastKnownState;

- (void)setState:(NSString *)state;

@end

@implementation EXKernel

+ (instancetype)sharedInstance
{
  static EXKernel *theKernel;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    if (!theKernel) {
      theKernel = [[EXKernel alloc] init];
    }
  });
  return theKernel;
}

- (instancetype)init
{
  if (self = [super init]) {
    // init app registry: keep track of RN Hosts we are running
    _appRegistry = [[EXKernelAppRegistry alloc] init];

    // init service registry: classes which manage shared resources among all hosts
    _serviceRegistry = [[EXKernelServiceRegistry alloc] init];

    // Set the delegate of dev menu manager. Maybe it should be a separate class? Will see later once the delegate protocol gets too big.
    [[EXDevMenuManager sharedInstance] setDelegate:self];

    // register for notifications to request reloading the visible app
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_handleRequestReloadVisibleApp:)
                                                 name:kEXReloadActiveAppRequest
                                               object:nil];

    for (NSString *name in @[UIApplicationDidBecomeActiveNotification,
                             UIApplicationDidEnterBackgroundNotification,
                             UIApplicationDidFinishLaunchingNotification,
                             UIApplicationWillResignActiveNotification,
                             UIApplicationWillEnterForegroundNotification]) {
      
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(_handleAppStateDidChange:)
                                                   name:name
                                                 object:nil];
    }
    NSLog(@"Expo iOS Runtime Version %@", [EXBuildConstants sharedInstance].expoRuntimeVersion);
  }
  return self;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Interfacing with JS

- (void)sendUrl:(NSString *)urlString toAppRecord:(EXKernelAppRecord *)app
{
  EXReactAppManager *appManager = app.appManager;
  id linkingModule = [self nativeModuleForAppManager:appManager named:@"LinkingManager"];
  if (!linkingModule) {
    DDLogError(@"Could not find the Linking module to open URL (%@)", urlString);
  } else if ([linkingModule respondsToSelector:@selector(dispatchOpenUrlEvent:)]) {
    [linkingModule dispatchOpenUrlEvent:[NSURL URLWithString:urlString]];
  } else {
    DDLogError(@"Linking module doesn't support the API we use to open URL (%@)", urlString);
  }
  [self _moveAppToVisible:app];
}

- (id)nativeModuleForAppManager:(EXReactAppManager *)appManager named:(NSString *)moduleName
{
  id host = appManager.reactHost;
  
  if (host) {
    id module = [[host moduleRegistry] moduleForName:[moduleName UTF8String]];
    if (module) {
      return module;
    }
  } else {
    // Host can be null if the record is in an error state and never created a host.
    if (host) {
      DDLogError(@"Host does not support the API");
    }
  }
  
  return nil;
}

- (void)_postNotificationName: (NSNotificationName)name
{
  [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil];
}

#pragma mark - App props

- (nullable NSDictionary *)initialAppPropsFromLaunchOptions:(NSDictionary *)launchOptions
{
  return nil;
}

#pragma mark - App State

- (EXKernelAppRecord *)createNewAppWithUrl:(NSURL *)url initialProps:(nullable NSDictionary *)initialProps
{
  NSString *recordId = [_appRegistry registerAppWithManifestUrl:url initialProps:initialProps];
  EXKernelAppRecord *record = [_appRegistry recordForId:recordId];
  [self _moveAppToVisible:record];
  return record;
}


- (void)reloadVisibleApp
{
  if (_browserController) {
    [EXUtil performSynchronouslyOnMainThread:^{
      [self->_browserController reloadVisibleApp];
    }];
  }
}

- (void)switchTasks
{
  if (!_browserController) {
    return;
  }
  
  if (_visibleApp != _appRegistry.homeAppRecord) {
    [EXUtil performSynchronouslyOnMainThread:^{
      [[EXDevMenuManager sharedInstance] toggle];
    }];
  } else {
    EXKernelAppRegistry *appRegistry = [EXKernel sharedInstance].appRegistry;
    for (NSString *recordId in appRegistry.appEnumerator) {
      EXKernelAppRecord *record = [appRegistry recordForId:recordId];
      // foreground the first thing we find
      [self _moveAppToVisible:record];
    }
  }
}

- (void)reloadAppWithScopeKey:(NSString *)scopeKey
{
  EXKernelAppRecord *appRecord = [_appRegistry newestRecordWithScopeKey:scopeKey];
  if (_browserController) {
    [self createNewAppWithUrl:appRecord.appLoader.manifestUrl initialProps:nil];
  }
}

- (void)reloadAppFromCacheWithScopeKey:(NSString *)scopeKey
{
  EXKernelAppRecord *appRecord = [_appRegistry newestRecordWithScopeKey:scopeKey];
  [appRecord.viewController reloadFromCache];
}

- (void)viewController:(__unused EXViewController *)vc didNavigateAppToVisible:(EXKernelAppRecord *)appRecord
{
  EXKernelAppRecord *appRecordPreviouslyVisible = _visibleApp;
  if (appRecord != appRecordPreviouslyVisible) {
    if (appRecordPreviouslyVisible) {
      [appRecordPreviouslyVisible.viewController appStateDidBecomeInactive];
      [self _postNotificationName:kEXKernelBridgeDidBackgroundNotification];
      id<EXAppStateProtocol> appStateModule = [self nativeModuleForAppManager:appRecordPreviouslyVisible.appManager named:@"AppState"];
      if (appStateModule != nil) {
        [appStateModule setState:@"background"];
      }
    }
    if (appRecord) {
      [appRecord.viewController appStateDidBecomeActive];
      [self _postNotificationName:kEXKernelBridgeDidForegroundNotification];
      id<EXAppStateProtocol> appStateModule = [self nativeModuleForAppManager:appRecord.appManager named:@"AppState"];
      if (appStateModule != nil) {
        [appStateModule setState:@"active"];
      }
      _visibleApp = appRecord;
    } else {
      _visibleApp = nil;
    }
    
    if (_visibleApp && _visibleApp != _appRegistry.homeAppRecord) {
      [self _unregisterUnusedAppRecords];
    }
  }
}

- (void)_unregisterUnusedAppRecords
{
  for (NSString *recordId in _appRegistry.appEnumerator) {
    EXKernelAppRecord *record = [_appRegistry recordForId:recordId];
    if (record && record != _visibleApp) {
      [_appRegistry unregisterAppWithRecordId:recordId];
      break;
    }
  }
}

- (void)_handleAppStateDidChange:(NSNotification *)notification
{
  NSString *newState;
  
  if ([notification.name isEqualToString:UIApplicationWillResignActiveNotification]) {
    newState = @"inactive";
  } else if ([notification.name isEqualToString:UIApplicationWillEnterForegroundNotification]) {
    newState = @"background";
  } else {
    switch (RCTSharedApplication().applicationState) {
      case UIApplicationStateActive:
        newState = @"active";
        break;
      case UIApplicationStateBackground: {
        newState = @"background";
        break;
      }
      default: {
        newState = @"unknown";
        break;
      }
    }
  }
  
  if (_visibleApp) {
    EXReactAppManager *appManager = _visibleApp.appManager;
    id<EXAppStateProtocol> appStateModule = [self nativeModuleForAppManager:appManager named:@"AppState"];
    NSString *lastKnownState;
    if (appStateModule != nil) {
      lastKnownState = [appStateModule lastKnownState];
      [appStateModule setState:newState];
    }
    if (!lastKnownState || ![newState isEqualToString:lastKnownState]) {
      if ([newState isEqualToString:@"active"]) {
        [_visibleApp.viewController appStateDidBecomeActive];
        [self _postNotificationName:kEXKernelBridgeDidForegroundNotification];
      } else if ([newState isEqualToString:@"background"]) {
        [_visibleApp.viewController appStateDidBecomeInactive];
        [self _postNotificationName:kEXKernelBridgeDidBackgroundNotification];
      }
    }
  }
}


- (void)_handleRequestReloadVisibleApp:(NSNotification *)notification
{
  [self reloadVisibleApp];
}

- (void)_moveAppToVisible:(EXKernelAppRecord *)appRecord
{
  if (_browserController) {
    [EXUtil performSynchronouslyOnMainThread:^{
      [self->_browserController moveAppToVisible:appRecord];
    }];
  }
}

#pragma mark - EXDevMenuDelegateProtocol

- (RCTHost *)mainHostForDevMenuManager:(EXDevMenuManager *)manager {
  return _appRegistry.homeAppRecord.appManager.reactHost;
}

- (nullable RCTReactNativeFactory *)appDelegateForDevMenuManager:(EXDevMenuManager *)manager {
  return _appRegistry.homeAppRecord.appManager.expoAppInstance.reactNativeFactory;
}

- (BOOL)devMenuManager:(EXDevMenuManager *)manager canChangeVisibility:(BOOL)visibility
{
  return !visibility || _visibleApp != _appRegistry.homeAppRecord;
}

@end

NS_ASSUME_NONNULL_END
