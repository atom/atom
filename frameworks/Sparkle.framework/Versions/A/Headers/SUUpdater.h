//
//  SUUpdater.h
//  Sparkle
//
//  Created by Andy Matuschak on 1/4/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SUUPDATER_H
#define SUUPDATER_H

#import "SUVersionComparisonProtocol.h"
#import "SUVersionDisplayProtocol.h"

@class SUUpdateDriver, SUAppcastItem, SUHost, SUAppcast;

@interface SUUpdater : NSObject
{
@private
	NSTimer *checkTimer;
	SUUpdateDriver *driver;

	NSString *customUserAgentString;
	SUHost *host;
	IBOutlet id delegate;
}

+ (SUUpdater *)sharedUpdater;
+ (SUUpdater *)updaterForBundle:(NSBundle *)bundle;
- initForBundle:(NSBundle *)bundle;

- (NSBundle *)hostBundle;

- (void)setDelegate:(id)delegate;
- delegate;

- (void)setAutomaticallyChecksForUpdates:(BOOL)automaticallyChecks;
- (BOOL)automaticallyChecksForUpdates;

- (void)setUpdateCheckInterval:(NSTimeInterval)interval;
- (NSTimeInterval)updateCheckInterval;

- (void)setFeedURL:(NSURL *)feedURL;
- (NSURL *)feedURL;	// *** MUST BE CALLED ON MAIN THREAD ***

- (void)setUserAgentString:(NSString *)userAgent;
- (NSString *)userAgentString;

- (void)setSendsSystemProfile:(BOOL)sendsSystemProfile;
- (BOOL)sendsSystemProfile;

- (void)setAutomaticallyDownloadsUpdates:(BOOL)automaticallyDownloadsUpdates;
- (BOOL)automaticallyDownloadsUpdates;

// This IBAction is meant for a main menu item. Hook up any menu item to this action,
// and Sparkle will check for updates and report back its findings verbosely.
- (IBAction)checkForUpdates:(id)sender;

// This kicks off an update meant to be programmatically initiated. That is, it will display no UI unless it actually finds an update,
// in which case it proceeds as usual. If the fully automated updating is turned on, however, this will invoke that behavior, and if an
// update is found, it will be downloaded and prepped for installation.
- (void)checkForUpdatesInBackground;

// Date of last update check. Returns nil if no check has been performed.
- (NSDate*)lastUpdateCheckDate;

// This begins a "probing" check for updates which will not actually offer to update to that version. The delegate methods, though,
// (up to updater:didFindValidUpdate: and updaterDidNotFindUpdate:), are called, so you can use that information in your UI.
- (void)checkForUpdateInformation;

// Call this to appropriately schedule or cancel the update checking timer according to the preferences for time interval and automatic checks. This call does not change the date of the next check, but only the internal NSTimer.
- (void)resetUpdateCycle;

- (BOOL)updateInProgress;

@end


// -----------------------------------------------------------------------------
//	SUUpdater Delegate:
// -----------------------------------------------------------------------------

@interface NSObject (SUUpdaterDelegateInformalProtocol)

// Use this to keep Sparkle from popping up e.g. while your setup assistant is showing:
- (BOOL)updaterMayCheckForUpdates:(SUUpdater *)bundle;

// This method allows you to add extra parameters to the appcast URL, potentially based on whether or not Sparkle will also be sending along the system profile. This method should return an array of dictionaries with keys: "key", "value", "displayKey", "displayValue", the latter two being specifically for display to the user.
- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile;

// Override this to dynamically specify the entire URL.
- (NSString*)feedURLStringForUpdater:(SUUpdater*)updater;

// Use this to override the default behavior for Sparkle prompting the user about automatic update checks.
- (BOOL)updaterShouldPromptForPermissionToCheckForUpdates:(SUUpdater *)bundle;

// Implement this if you want to do some special handling with the appcast once it finishes loading.
- (void)updater:(SUUpdater *)updater didFinishLoadingAppcast:(SUAppcast *)appcast;

// If you're using special logic or extensions in your appcast, implement this to use your own logic for finding
// a valid update, if any, in the given appcast.
- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)appcast forUpdater:(SUUpdater *)bundle;

// Sent when a valid update is found by the update driver.
- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update;

// Sent when a valid update is not found.
- (void)updaterDidNotFindUpdate:(SUUpdater *)update;

// Sent immediately before installing the specified update.
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update;

// Return YES to delay the relaunch until you do some processing; invoke the given NSInvocation to continue.
//	This is not called if the user didn't relaunch on the previous update, in that case it will immediately
//	restart.
- (BOOL)updater:(SUUpdater *)updater shouldPostponeRelaunchForUpdate:(SUAppcastItem *)update untilInvoking:(NSInvocation *)invocation;

// Some apps *can not* be relaunched in certain circumstances. They can use this method
//	to prevent a relaunch "hard":
- (BOOL)updaterShouldRelaunchApplication:(SUUpdater *)updater;

// Called immediately before relaunching.
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater;

// This method allows you to provide a custom version comparator.
// If you don't implement this method or return nil, the standard version comparator will be used.
- (id <SUVersionComparison>)versionComparatorForUpdater:(SUUpdater *)updater;

// This method allows you to provide a custom version comparator.
// If you don't implement this method or return nil, the standard version displayer will be used.
- (id <SUVersionDisplay>)versionDisplayerForUpdater:(SUUpdater *)updater;

// Returns the path which is used to relaunch the client after the update is installed. By default, the path of the host bundle.
- (NSString *)pathToRelaunchForUpdater:(SUUpdater *)updater;

// Called before and after, respectively, an updater shows a modal alert window, to give the host
//	the opportunity to hide attached windows etc. that may get in the way:
-(void)	updaterWillShowModalAlert:(SUUpdater *)updater;
-(void)	updaterDidShowModalAlert:(SUUpdater *)updater;

@end


// -----------------------------------------------------------------------------
//	Constants:
// -----------------------------------------------------------------------------

// Define some minimum intervals to avoid DOS-like checking attacks. These are in seconds.
#if defined(DEBUG) && DEBUG && 0
#define SU_MIN_CHECK_INTERVAL 60
#else
#define SU_MIN_CHECK_INTERVAL 60*60
#endif

#if defined(DEBUG) && DEBUG && 0
#define SU_DEFAULT_CHECK_INTERVAL 60
#else
#define SU_DEFAULT_CHECK_INTERVAL 60*60*24
#endif

#endif
