// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/browser_host_impl.h"

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

#include "base/file_util.h"
#include "base/mac/mac_util.h"
#include "base/string_util.h"
#include "base/sys_string_conversions.h"
#include "base/threading/thread_restrictions.h"
#include "content/public/browser/native_web_keyboard_event.h"
#include "content/public/browser/web_contents.h"
#include "content/public/browser/web_contents_view.h"
#include "content/public/common/file_chooser_params.h"
#import  "ui/base/cocoa/underlay_opengl_hosting_window.h"
#include "ui/gfx/rect.h"


// Wrapper NSView for the native view. Necessary to destroy the browser when
// the view is deleted.
@interface CefBrowserHostView : NSView {
 @private
  CefBrowserHostImpl* browser_;  // weak
  bool is_in_onsetfocus_;
}

@property (nonatomic, assign) CefBrowserHostImpl* browser;

@end

@implementation CefBrowserHostView

@synthesize browser = browser_;

- (void) dealloc {
  if (browser_) {
    browser_->DestroyBrowser();
    browser_->Release();
  }

  [super dealloc];
}

- (BOOL)acceptsFirstResponder {
  return browser_ && browser_->GetWebContents();
}

- (BOOL)becomeFirstResponder {
  if (browser_ && browser_->GetWebContents()) {
    // Avoid re-entering OnSetFocus.
    if (!is_in_onsetfocus_) {
      is_in_onsetfocus_ = true;
      browser_->OnSetFocus(FOCUS_SOURCE_SYSTEM);
      is_in_onsetfocus_ = false;
    }
  }

  return YES;
}

@end

namespace {

// Accept-types to file-types helper.
NSMutableArray* GetFileTypesFromAcceptTypes(
    const std::vector<string16>& accept_types) {
  NSMutableArray* acceptArray = [[NSMutableArray alloc] init];
  for (size_t i=0; i<accept_types.size(); i++) {
    std::string ascii_type = UTF16ToASCII(accept_types[i]);
    if (ascii_type.length()) {
      // Just treat as extension if contains '.' as the first character.
      if (ascii_type[0] == '.') {
        [acceptArray addObject:base::SysUTF8ToNSString(ascii_type)];
      } else {
        // Otherwise convert mime to UTI.
        NSString* mimeType = base::SysUTF8ToNSString(ascii_type);
        NSString* UTI = [NSMakeCollectable(
            UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                (CFStringRef) mimeType, NULL)) autorelease];
        [acceptArray addObject:UTI];
      }
    }
  }
  return acceptArray;
}

}  // namespace

bool CefBrowserHostImpl::PlatformViewText(const std::string& text) {
  NOTIMPLEMENTED();
  return false;
}

bool CefBrowserHostImpl::PlatformCreateWindow() {
  NSWindow* newWnd = nil;

  NSView* parentView = window_info_.parent_view;
  NSRect contentRect = {{window_info_.x, window_info_.y},
                        {window_info_.width, window_info_.height}};
  if (parentView == nil) {
    // Create a new window.
    NSRect screen_rect = [[NSScreen mainScreen] visibleFrame];
    NSRect window_rect = {{window_info_.x,
                           screen_rect.size.height - window_info_.y},
                          {window_info_.width, window_info_.height}};
    if (window_rect.size.width == 0)
      window_rect.size.width = 750;
    if (window_rect.size.height == 0)
      window_rect.size.height = 750;

    contentRect.origin.x = 0;
    contentRect.origin.y = 0;
    contentRect.size.width = window_rect.size.width;
    contentRect.size.height = window_rect.size.height;

    newWnd = [[UnderlayOpenGLHostingWindow alloc]
              initWithContentRect:window_rect
              styleMask:(NSTitledWindowMask |
                         NSClosableWindowMask |
                         NSMiniaturizableWindowMask |
                         NSResizableWindowMask |
                         NSUnifiedTitleAndToolbarWindowMask )
              backing:NSBackingStoreBuffered
              defer:NO];
    parentView = [newWnd contentView];
    window_info_.parent_view = parentView;
  }

  // Add a reference that will be released in the dealloc handler.
  AddRef();

  // Create the browser view.
  CefBrowserHostView* browser_view =
      [[CefBrowserHostView alloc] initWithFrame:contentRect];
  browser_view.browser = this;
  [parentView addSubview:browser_view];
  [browser_view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [browser_view setNeedsDisplay:YES];
  [browser_view release];

  // Parent the TabContents to the browser view.
  const NSRect bounds = [browser_view bounds];
  NSView* native_view = web_contents_->GetView()->GetNativeView();
  [browser_view addSubview:native_view];
  [native_view setFrame:bounds];
  [native_view setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
  [native_view setNeedsDisplay:YES];

  window_info_.view = browser_view;

  if (newWnd != nil && !window_info_.hidden) {
    // Show the window.
    [newWnd makeKeyAndOrderFront: nil];
  }

  return true;
}

void CefBrowserHostImpl::PlatformCloseWindow() {
  if (window_info_.view != nil) {
    [[window_info_.view window] performSelector:@selector(performClose:)
                                     withObject:nil
                                     afterDelay:0];
  }
}

void CefBrowserHostImpl::PlatformSizeTo(int width, int height) {
  // Not needed; subviews are bound.
}

CefWindowHandle CefBrowserHostImpl::PlatformGetWindowHandle() {
  return window_info_.view;
}

void CefBrowserHostImpl::PlatformHandleKeyboardEvent(
    const content::NativeWebKeyboardEvent& event) {
  // Give the top level menu equivalents a chance to handle the event.
  if ([event.os_event type] == NSKeyDown)
    [[NSApp mainMenu] performKeyEquivalent:event.os_event];
}

void CefBrowserHostImpl::PlatformRunFileChooser(
    content::WebContents* contents,
    const content::FileChooserParams& params,
    std::vector<FilePath>& files) {
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  if (!params.title.empty())
    [openPanel setTitle:base::SysUTF16ToNSString(params.title)];

  // Consider default file name if any.
  FilePath default_file_name(params.default_file_name);

  if (!default_file_name.empty()) {
    if (!default_file_name.BaseName().empty()) {
      NSString* defaultName = base::SysUTF8ToNSString(
          default_file_name.BaseName().value());
      [openPanel setNameFieldStringValue:defaultName];
    }

    if (!default_file_name.DirName().empty()) {
      NSString* defaultDir = base::SysUTF8ToNSString(
          default_file_name.DirName().value());
      [openPanel setDirectoryURL:[NSURL fileURLWithPath:defaultDir]];
    }
  }

  // Consider supported file types
  if (!params.accept_types.empty()) {
    [openPanel setAllowedFileTypes:GetFileTypesFromAcceptTypes(
        params.accept_types)];
  }

  // Further panel configuration.
  [openPanel setAllowsOtherFileTypes:YES];
  [openPanel setAllowsMultipleSelection:
      (params.mode == content::FileChooserParams::OpenMultiple)];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanChooseDirectories:NO];

  // Show panel.
  NSView* view = contents->GetNativeView();
  [openPanel beginSheetModalForWindow:[view window] completionHandler:nil];
  if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
    NSArray *urls = [openPanel URLs];
    int i, count = [urls count];
    for (i=0; i<count; i++) {
      NSURL* url = [urls objectAtIndex:i];
      if ([url isFileURL])
        files.push_back(FilePath(base::SysNSStringToUTF8([url path])));
    }
  }
  [NSApp endSheet:openPanel];
}

void CefBrowserHostImpl::PlatformHandleExternalProtocol(const GURL& url) {
}
