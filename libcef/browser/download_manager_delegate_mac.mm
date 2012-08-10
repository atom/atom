// Copyright (c) 2012 The Chromium Embedded Framework Authors.
// Portions copyright (c) 2011 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "libcef/browser/download_manager_delegate.h"

#import <Cocoa/Cocoa.h>

#include "base/sys_string_conversions.h"
#include "content/public/browser/web_contents.h"

FilePath CefDownloadManagerDelegate::PlatformChooseDownloadPath(
    content::WebContents* web_contents,
    const FilePath& suggested_path) {
  FilePath result;
  NSSavePanel* savePanel = [NSSavePanel savePanel];

  if (!suggested_path.BaseName().empty()) {
    NSString* defaultName = base::SysUTF8ToNSString(
        suggested_path.BaseName().value());
    [savePanel setNameFieldStringValue:defaultName];
  }

  if (!suggested_path.DirName().empty()) {
    NSString* defaultDir = base::SysUTF8ToNSString(
        suggested_path.DirName().value());
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:defaultDir]];
  }

  NSView* view = web_contents->GetNativeView();
  [savePanel beginSheetModalForWindow:[view window] completionHandler:nil];
  if ([savePanel runModal] == NSFileHandlingPanelOKButton) {
    NSURL * url = [savePanel URL];
    NSString* path = [url path];
    result = FilePath([path UTF8String]);
  }
  [NSApp endSheet:savePanel];

  return result;
}
