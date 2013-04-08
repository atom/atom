/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Kent Sutherland
 *
 * Copyright (c) 2011 Andreas Linde & Kent Sutherland.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>

typedef enum CrashAlertType {
  CrashAlertTypeSend = 0,
  CrashAlertTypeFeedback = 1,
} CrashAlertType;

typedef enum CrashReportStatus {
  // This app version is set to discontinued, no new crash reports accepted by the server
  CrashReportStatusFailureVersionDiscontinued = -30,
    
  // XML: Sender ersion string contains not allowed characters, only alphanumberical including space and . are allowed
  CrashReportStatusFailureXMLSenderVersionNotAllowed = -21,
    
  // XML: Version string contains not allowed characters, only alphanumberical including space and . are allowed
  CrashReportStatusFailureXMLVersionNotAllowed = -20,
    
  // SQL for adding a symoblicate todo entry in the database failed
  CrashReportStatusFailureSQLAddSymbolicateTodo = -18,
    
  // SQL for adding crash log in the database failed
  CrashReportStatusFailureSQLAddCrashlog = -17,
    
  // SQL for adding a new version in the database failed
  CrashReportStatusFailureSQLAddVersion = -16,
  
  // SQL for checking if the version is already added in the database failed
  CrashReportStatusFailureSQLCheckVersionExists = -15,
  
  // SQL for creating a new pattern for this bug and set amount of occurrances to 1 in the database failed
  CrashReportStatusFailureSQLAddPattern = -14,
  
  // SQL for checking the status of the bugfix version in the database failed
  CrashReportStatusFailureSQLCheckBugfixStatus = -13,
  
  // SQL for updating the occurances of this pattern in the database failed
  CrashReportStatusFailureSQLUpdatePatternOccurances = -12,
  
  // SQL for getting all the known bug patterns for the current app version in the database failed
  CrashReportStatusFailureSQLFindKnownPatterns = -11,
  
  // SQL for finding the bundle identifier in the database failed
  CrashReportStatusFailureSQLSearchAppName = -10,
  
  // the post request didn't contain valid data
  CrashReportStatusFailureInvalidPostData = -3,
  
  // incoming data may not be added, because e.g. bundle identifier wasn't found
  CrashReportStatusFailureInvalidIncomingData = -2,
  
  // database cannot be accessed, check hostname, username, password and database name settings in config.php
  CrashReportStatusFailureDatabaseNotAvailable = -1,
  
  CrashReportStatusUnknown = 0,
  
  CrashReportStatusAssigned = 1,
  
  CrashReportStatusSubmitted = 2,
  
  CrashReportStatusAvailable = 3,
} CrashReportStatus;


@class BWQuincyUI;

@protocol BWQuincyManagerDelegate <NSObject>

@required

// Invoked once the modal sheets are gone
- (void) showMainApplicationWindow;

@optional

// Return the description the crashreport should contain, empty by default. The string will automatically be wrapped into <[DATA[ ]]>, so make sure you don't do that in your string.
-(NSString *) crashReportDescription;

// Return the userid the crashreport should contain, empty by default
-(NSString *) crashReportUserID;

// Return the contact value (e.g. email) the crashreport should contain, empty by default
-(NSString *) crashReportContact;
@end


@interface BWQuincyManager : NSObject 
#if defined(MAC_OS_X_VERSION_10_6) && (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6) 
 <NSXMLParserDelegate> 
#endif
{
  CrashReportStatus _serverResult;
  NSInteger         _statusCode;
    
  NSMutableString   *_contentOfProperty;

  id<BWQuincyManagerDelegate> _delegate;

  NSString   *_submissionURL;
  NSString   *_companyName;
  NSString   *_appIdentifier;
  BOOL       _autoSubmitCrashReport;

  NSString   *_crashFile;
  
  BWQuincyUI *_quincyUI;
}

- (NSString*) modelVersion;

+ (BWQuincyManager *)sharedQuincyManager;

// submission URL defines where to send the crash reports to (required)
@property (nonatomic, retain) NSString *submissionURL;

// defines the company name to be shown in the crash reporting dialog
@property (nonatomic, retain) NSString *companyName;

// delegate is required
@property (nonatomic, assign) id <BWQuincyManagerDelegate> delegate;

// if YES, the crash report will be submitted without asking the user
// if NO, the user will be asked if the crash report can be submitted (default)
@property (nonatomic, assign, getter=isAutoSubmitCrashReport) BOOL autoSubmitCrashReport;

///////////////////////////////////////////////////////////////////////////////////////////////////
// settings

// If you want to use HockeyApp instead of your own server, this is required
@property (nonatomic, retain) NSString *appIdentifier;


- (void) cancelReport;
- (void) sendReportCrash:(NSString*)crashContent
             description:(NSString*)description;

- (NSString *) applicationName;
- (NSString *) applicationVersionString;
- (NSString *) applicationVersion;

@end
