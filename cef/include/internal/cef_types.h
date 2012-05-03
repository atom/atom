// Copyright (c) 2010 Marshall A. Greenblatt. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the name Chromium Embedded
// Framework nor the names of its contributors may be used to endorse
// or promote products derived from this software without specific prior
// written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#ifndef CEF_INCLUDE_INTERNAL_CEF_TYPES_H_
#define CEF_INCLUDE_INTERNAL_CEF_TYPES_H_
#pragma once

#include "include/internal/cef_build.h"
#include "include/internal/cef_string.h"
#include "include/internal/cef_string_list.h"
#include "include/internal/cef_time.h"

// Bring in platform-specific definitions.
#if defined(OS_WIN)
#include "include/internal/cef_types_win.h"
#elif defined(OS_MACOSX)
#include "include/internal/cef_types_mac.h"
#elif defined(OS_LINUX)
#include "include/internal/cef_types_linux.h"
#endif

#include <stddef.h>         // For size_t

// The NSPR system headers define 64-bit as |long| when possible, except on
// Mac OS X.  In order to not have typedef mismatches, we do the same on LP64.
//
// On Mac OS X, |long long| is used for 64-bit types for compatibility with
// <inttypes.h> format macros even in the LP64 model.
#if defined(__LP64__) && !defined(OS_MACOSX) && !defined(OS_OPENBSD)
typedef long                int64;  // NOLINT(runtime/int)
typedef unsigned long       uint64;  // NOLINT(runtime/int)
#else
typedef long long           int64;  // NOLINT(runtime/int)
typedef unsigned long long  uint64;  // NOLINT(runtime/int)
#endif

#ifdef __cplusplus
extern "C" {
#endif

///
// Log severity levels.
///
enum cef_log_severity_t {
  LOGSEVERITY_VERBOSE = -1,
  LOGSEVERITY_INFO,
  LOGSEVERITY_WARNING,
  LOGSEVERITY_ERROR,
  LOGSEVERITY_ERROR_REPORT,
  // Disables logging completely.
  LOGSEVERITY_DISABLE = 99
};

///
// Initialization settings. Specify NULL or 0 to get the recommended default
// values.
///
typedef struct _cef_settings_t {
  ///
  // Size of this structure.
  ///
  size_t size;

  ///
  // Set to true (1) to have the message loop run in a separate thread. If
  // false (0) than the CefDoMessageLoopWork() function must be called from
  // your application message loop.
  ///
  bool multi_threaded_message_loop;

  ///
  // The location where cache data will be stored on disk. If empty an
  // in-memory cache will be used. HTML5 databases such as localStorage will
  // only persist across sessions if a cache path is specified.
  ///
  cef_string_t cache_path;

  ///
  // Value that will be returned as the User-Agent HTTP header. If empty the
  // default User-Agent string will be used.
  ///
  cef_string_t user_agent;

  ///
  // Value that will be inserted as the product portion of the default
  // User-Agent string. If empty the Chromium product version will be used. If
  // |userAgent| is specified this value will be ignored.
  ///
  cef_string_t product_version;

  ///
  // The locale string that will be passed to WebKit. If empty the default
  // locale of "en-US" will be used. This value is ignored on Linux where locale
  // is determined using environment variable parsing with the precedence order:
  // LANGUAGE, LC_ALL, LC_MESSAGES and LANG.
  ///
  cef_string_t locale;

  ///
  // List of fully qualified paths to plugins (including plugin name) that will
  // be loaded in addition to any plugins found in the default search paths.
  ///
  cef_string_list_t extra_plugin_paths;

  ///
  // The directory and file name to use for the debug log. If empty, the
  // default name of "debug.log" will be used and the file will be written
  // to the application directory.
  ///
  cef_string_t log_file;

  ///
  // The log severity. Only messages of this severity level or higher will be
  // logged.
  ///
  cef_log_severity_t log_severity;

  ///
  // The graphics implementation that CEF will use for rendering GPU accelerated
  // content like WebGL, accelerated layers and 3D CSS.
  ///
  cef_graphics_implementation_t graphics_implementation;

  ///
  // Quota limit for localStorage data across all origins. Default size is 5MB.
  ///
  unsigned int local_storage_quota;

  ///
  // Quota limit for sessionStorage data per namespace. Default size is 5MB.
  ///
  unsigned int session_storage_quota;

  ///
  // Custom flags that will be used when initializing the V8 JavaScript engine.
  // The consequences of using custom flags may not be well tested.
  ///
  cef_string_t javascript_flags;

#if defined(OS_WIN)
  ///
  // Set to true (1) to use the system proxy resolver on Windows when
  // "Automatically detect settings" is checked. This setting is disabled
  // by default for performance reasons.
  ///
  bool auto_detect_proxy_settings_enabled;
#endif

  ///
  // The fully qualified path for the cef.pak file. If this value is empty
  // the cef.pak file must be located in the module directory. This value is
  // ignored on Mac OS X where pack files are always loaded from the app bundle
  // resource directory.
  ///
  cef_string_t pack_file_path;

  ///
  // The fully qualified path for the locales directory. If this value is empty
  // the locales directory must be located in the module directory. This value
  // is ignored on Mac OS X where pack files are always loaded from the app
  // bundle resource directory.
  ///
  cef_string_t locales_dir_path;

  ///
  // Set to true (1) to disable loading of pack files for resources and locales.
  // A resource bundle handler must be provided for the browser and renderer
  // processes via CefApp::GetResourceBundleHandler() if loading of pack files
  // is disabled.
  ///
  bool pack_loading_disabled;
} cef_settings_t;

///
// Browser initialization settings. Specify NULL or 0 to get the recommended
// default values. The consequences of using custom values may not be well
// tested.
///
typedef struct _cef_browser_settings_t {
  ///
  // Size of this structure.
  ///
  size_t size;

  ///
  // Disable drag & drop of URLs from other windows.
  ///
  bool drag_drop_disabled;

  ///
  // Disable default navigation resulting from drag & drop of URLs.
  ///
  bool load_drops_disabled;

  ///
  // Disable history back/forward navigation.
  ///
  bool history_disabled;

  // The below values map to WebPreferences settings.

  ///
  // Font settings.
  ///
  cef_string_t standard_font_family;
  cef_string_t fixed_font_family;
  cef_string_t serif_font_family;
  cef_string_t sans_serif_font_family;
  cef_string_t cursive_font_family;
  cef_string_t fantasy_font_family;
  int default_font_size;
  int default_fixed_font_size;
  int minimum_font_size;
  int minimum_logical_font_size;

  ///
  // Set to true (1) to disable loading of fonts from remote sources.
  ///
  bool remote_fonts_disabled;

  ///
  // Default encoding for Web content. If empty "ISO-8859-1" will be used.
  ///
  cef_string_t default_encoding;

  ///
  // Set to true (1) to attempt automatic detection of content encoding.
  ///
  bool encoding_detector_enabled;

  ///
  // Set to true (1) to disable JavaScript.
  ///
  bool javascript_disabled;

  ///
  // Set to true (1) to disallow JavaScript from opening windows.
  ///
  bool javascript_open_windows_disallowed;

  ///
  // Set to true (1) to disallow JavaScript from closing windows.
  ///
  bool javascript_close_windows_disallowed;

  ///
  // Set to true (1) to disallow JavaScript from accessing the clipboard.
  ///
  bool javascript_access_clipboard_disallowed;

  ///
  // Set to true (1) to disable DOM pasting in the editor. DOM pasting also
  // depends on |javascript_cannot_access_clipboard| being false (0).
  ///
  bool dom_paste_disabled;

  ///
  // Set to true (1) to enable drawing of the caret position.
  ///
  bool caret_browsing_enabled;

  ///
  // Set to true (1) to disable Java.
  ///
  bool java_disabled;

  ///
  // Set to true (1) to disable plugins.
  ///
  bool plugins_disabled;

  ///
  // Set to true (1) to allow access to all URLs from file URLs.
  ///
  bool universal_access_from_file_urls_allowed;

  ///
  // Set to true (1) to allow access to file URLs from other file URLs.
  ///
  bool file_access_from_file_urls_allowed;

  ///
  // Set to true (1) to allow risky security behavior such as cross-site
  // scripting (XSS). Use with extreme care.
  ///
  bool web_security_disabled;

  ///
  // Set to true (1) to enable console warnings about XSS attempts.
  ///
  bool xss_auditor_enabled;

  ///
  // Set to true (1) to suppress the network load of image URLs.  A cached
  // image will still be rendered if requested.
  ///
  bool image_load_disabled;

  ///
  // Set to true (1) to shrink standalone images to fit the page.
  ///
  bool shrink_standalone_images_to_fit;

  ///
  // Set to true (1) to disable browser backwards compatibility features.
  ///
  bool site_specific_quirks_disabled;

  ///
  // Set to true (1) to disable resize of text areas.
  ///
  bool text_area_resize_disabled;

  ///
  // Set to true (1) to disable use of the page cache.
  ///
  bool page_cache_disabled;

  ///
  // Set to true (1) to not have the tab key advance focus to links.
  ///
  bool tab_to_links_disabled;

  ///
  // Set to true (1) to disable hyperlink pings (<a ping> and window.sendPing).
  ///
  bool hyperlink_auditing_disabled;

  ///
  // Set to true (1) to enable the user style sheet for all pages.
  ///
  bool user_style_sheet_enabled;

  ///
  // Location of the user style sheet. This must be a data URL of the form
  // "data:text/css;charset=utf-8;base64,csscontent" where "csscontent" is the
  // base64 encoded contents of the CSS file.
  ///
  cef_string_t user_style_sheet_location;

  ///
  // Set to true (1) to disable style sheets.
  ///
  bool author_and_user_styles_disabled;

  ///
  // Set to true (1) to disable local storage.
  ///
  bool local_storage_disabled;

  ///
  // Set to true (1) to disable databases.
  ///
  bool databases_disabled;

  ///
  // Set to true (1) to disable application cache.
  ///
  bool application_cache_disabled;

  ///
  // Set to true (1) to disable WebGL.
  ///
  bool webgl_disabled;

  ///
  // Set to true (1) to enable accelerated compositing. This is turned off by
  // default because the current in-process GPU implementation does not
  // support it correctly.
  ///
  bool accelerated_compositing_enabled;

  ///
  // Set to true (1) to enable threaded compositing. This is currently only
  // supported by the command buffer graphics implementation.
  ///
  bool threaded_compositing_enabled;

  ///
  // Set to true (1) to disable accelerated layers. This affects features like
  // 3D CSS transforms.
  ///
  bool accelerated_layers_disabled;

  ///
  // Set to true (1) to disable accelerated video.
  ///
  bool accelerated_video_disabled;

  ///
  // Set to true (1) to disable accelerated 2d canvas.
  ///
  bool accelerated_2d_canvas_disabled;

  ///
  // Set to true (1) to disable accelerated painting.
  ///
  bool accelerated_painting_disabled;

  ///
  // Set to true (1) to disable accelerated filters.
  ///
  bool accelerated_filters_disabled;

  ///
  // Set to true (1) to disable accelerated plugins.
  ///
  bool accelerated_plugins_disabled;

  ///
  // Set to true (1) to disable developer tools (WebKit inspector).
  ///
  bool developer_tools_disabled;

  ///
  // Set to true (1) to enable fullscreen mode.
  ///
  bool fullscreen_enabled;
} cef_browser_settings_t;

///
// URL component parts.
///
typedef struct _cef_urlparts_t {
  ///
  // The complete URL specification.
  ///
  cef_string_t spec;

  ///
  // Scheme component not including the colon (e.g., "http").
  ///
  cef_string_t scheme;

  ///
  // User name component.
  ///
  cef_string_t username;

  ///
  // Password component.
  ///
  cef_string_t password;

  ///
  // Host component. This may be a hostname, an IPv4 address or an IPv6 literal
  // surrounded by square brackets (e.g., "[2001:db8::1]").
  ///
  cef_string_t host;

  ///
  // Port number component.
  ///
  cef_string_t port;

  ///
  // Path component including the first slash following the host.
  ///
  cef_string_t path;

  ///
  // Query string component (i.e., everything following the '?').
  ///
  cef_string_t query;
} cef_urlparts_t;

///
// Cookie information.
///
typedef struct _cef_cookie_t {
  ///
  // The cookie name.
  ///
  cef_string_t name;

  ///
  // The cookie value.
  ///
  cef_string_t value;

  ///
  // If |domain| is empty a host cookie will be created instead of a domain
  // cookie. Domain cookies are stored with a leading "." and are visible to
  // sub-domains whereas host cookies are not.
  ///
  cef_string_t domain;

  ///
  // If |path| is non-empty only URLs at or below the path will get the cookie
  // value.
  ///
  cef_string_t path;

  ///
  // If |secure| is true the cookie will only be sent for HTTPS requests.
  ///
  bool secure;

  ///
  // If |httponly| is true the cookie will only be sent for HTTP requests.
  ///
  bool httponly;

  ///
  // The cookie creation date. This is automatically populated by the system on
  // cookie creation.
  ///
  cef_time_t creation;

  ///
  // The cookie last access date. This is automatically populated by the system
  // on access.
  ///
  cef_time_t last_access;

  ///
  // The cookie expiration date is only valid if |has_expires| is true.
  ///
  bool has_expires;
  cef_time_t expires;
} cef_cookie_t;

///
// Storage types.
///
enum cef_storage_type_t {
  ST_LOCALSTORAGE = 0,
  ST_SESSIONSTORAGE,
};

///
// Mouse button types.
///
enum cef_mouse_button_type_t {
  MBT_LEFT   = 0,
  MBT_MIDDLE,
  MBT_RIGHT,
};

///
// Key types.
///
enum cef_key_type_t {
  KT_KEYUP    = 0,
  KT_KEYDOWN,
  KT_CHAR,
};

///
// Various browser navigation types supported by chrome.
///
enum cef_handler_navtype_t {
  NAVTYPE_LINKCLICKED = 0,
  NAVTYPE_FORMSUBMITTED,
  NAVTYPE_BACKFORWARD,
  NAVTYPE_RELOAD,
  NAVTYPE_FORMRESUBMITTED,
  NAVTYPE_OTHER,
  NAVTYPE_LINKDROPPED,
};

///
// Supported error code values. See net\base\net_error_list.h for complete
// descriptions of the error codes.
///
enum cef_handler_errorcode_t {
  ERR_FAILED = -2,
  ERR_ABORTED = -3,
  ERR_INVALID_ARGUMENT = -4,
  ERR_INVALID_HANDLE = -5,
  ERR_FILE_NOT_FOUND = -6,
  ERR_TIMED_OUT = -7,
  ERR_FILE_TOO_BIG = -8,
  ERR_UNEXPECTED = -9,
  ERR_ACCESS_DENIED = -10,
  ERR_NOT_IMPLEMENTED = -11,
  ERR_CONNECTION_CLOSED = -100,
  ERR_CONNECTION_RESET = -101,
  ERR_CONNECTION_REFUSED = -102,
  ERR_CONNECTION_ABORTED = -103,
  ERR_CONNECTION_FAILED = -104,
  ERR_NAME_NOT_RESOLVED = -105,
  ERR_INTERNET_DISCONNECTED = -106,
  ERR_SSL_PROTOCOL_ERROR = -107,
  ERR_ADDRESS_INVALID = -108,
  ERR_ADDRESS_UNREACHABLE = -109,
  ERR_SSL_CLIENT_AUTH_CERT_NEEDED = -110,
  ERR_TUNNEL_CONNECTION_FAILED = -111,
  ERR_NO_SSL_VERSIONS_ENABLED = -112,
  ERR_SSL_VERSION_OR_CIPHER_MISMATCH = -113,
  ERR_SSL_RENEGOTIATION_REQUESTED = -114,
  ERR_CERT_COMMON_NAME_INVALID = -200,
  ERR_CERT_DATE_INVALID = -201,
  ERR_CERT_AUTHORITY_INVALID = -202,
  ERR_CERT_CONTAINS_ERRORS = -203,
  ERR_CERT_NO_REVOCATION_MECHANISM = -204,
  ERR_CERT_UNABLE_TO_CHECK_REVOCATION = -205,
  ERR_CERT_REVOKED = -206,
  ERR_CERT_INVALID = -207,
  ERR_CERT_END = -208,
  ERR_INVALID_URL = -300,
  ERR_DISALLOWED_URL_SCHEME = -301,
  ERR_UNKNOWN_URL_SCHEME = -302,
  ERR_TOO_MANY_REDIRECTS = -310,
  ERR_UNSAFE_REDIRECT = -311,
  ERR_UNSAFE_PORT = -312,
  ERR_INVALID_RESPONSE = -320,
  ERR_INVALID_CHUNKED_ENCODING = -321,
  ERR_METHOD_NOT_SUPPORTED = -322,
  ERR_UNEXPECTED_PROXY_AUTH = -323,
  ERR_EMPTY_RESPONSE = -324,
  ERR_RESPONSE_HEADERS_TOO_BIG = -325,
  ERR_CACHE_MISS = -400,
  ERR_INSECURE_RESPONSE = -501,
};

///
// "Verb" of a drag-and-drop operation as negotiated between the source and
// destination. These constants match their equivalents in WebCore's
// DragActions.h and should not be renumbered.
///
enum cef_drag_operations_mask_t {
    DRAG_OPERATION_NONE    = 0,
    DRAG_OPERATION_COPY    = 1,
    DRAG_OPERATION_LINK    = 2,
    DRAG_OPERATION_GENERIC = 4,
    DRAG_OPERATION_PRIVATE = 8,
    DRAG_OPERATION_MOVE    = 16,
    DRAG_OPERATION_DELETE  = 32,
    DRAG_OPERATION_EVERY   = UINT_MAX
};

///
// V8 access control values.
///
enum cef_v8_accesscontrol_t {
  V8_ACCESS_CONTROL_DEFAULT               = 0,
  V8_ACCESS_CONTROL_ALL_CAN_READ          = 1,
  V8_ACCESS_CONTROL_ALL_CAN_WRITE         = 1 << 1,
  V8_ACCESS_CONTROL_PROHIBITS_OVERWRITING = 1 << 2
};

///
// V8 property attribute values.
///
enum cef_v8_propertyattribute_t {
  V8_PROPERTY_ATTRIBUTE_NONE       = 0,       // Writeable, Enumerable,
                                              //   Configurable
  V8_PROPERTY_ATTRIBUTE_READONLY   = 1 << 0,  // Not writeable
  V8_PROPERTY_ATTRIBUTE_DONTENUM   = 1 << 1,  // Not enumerable
  V8_PROPERTY_ATTRIBUTE_DONTDELETE = 1 << 2   // Not configurable
};

///
// Structure representing menu information.
///
typedef struct _cef_menu_info_t {
  ///
  // Values from the cef_handler_menutypebits_t enumeration.
  ///
  int typeFlags;

  ///
  // If window rendering is enabled |x| and |y| will be in screen coordinates.
  // Otherwise, |x| and |y| will be in view coordinates.
  ///
  int x;
  int y;

  cef_string_t linkUrl;
  cef_string_t imageUrl;
  cef_string_t pageUrl;
  cef_string_t frameUrl;
  cef_string_t selectionText;
  cef_string_t misspelledWord;

  ///
  // Values from the cef_handler_menucapabilitybits_t enumeration.
  ///
  int editFlags;

  cef_string_t securityInfo;
} cef_menu_info_t;

///
// The cef_menu_info_t typeFlags value will be a combination of the
// following values.
///
enum cef_menu_typebits_t {
  ///
  // No node is selected
  ///
  MENUTYPE_NONE = 0x0,
  ///
  // The top page is selected
  ///
  MENUTYPE_PAGE = 0x1,
  ///
  // A subframe page is selected
  ///
  MENUTYPE_FRAME = 0x2,
  ///
  // A link is selected
  ///
  MENUTYPE_LINK = 0x4,
  ///
  // An image is selected
  ///
  MENUTYPE_IMAGE = 0x8,
  ///
  // There is a textual or mixed selection that is selected
  ///
  MENUTYPE_SELECTION = 0x10,
  ///
  // An editable element is selected
  ///
  MENUTYPE_EDITABLE = 0x20,
  ///
  // A misspelled word is selected
  ///
  MENUTYPE_MISSPELLED_WORD = 0x40,
  ///
  // A video node is selected
  ///
  MENUTYPE_VIDEO = 0x80,
  ///
  // A video node is selected
  ///
  MENUTYPE_AUDIO = 0x100,
};

///
// The cef_menu_info_t editFlags value will be a combination of the
// following values.
///
enum cef_menu_capabilitybits_t {
  // Values from WebContextMenuData::EditFlags in WebContextMenuData.h
  MENU_CAN_DO_NONE = 0x0,
  MENU_CAN_UNDO = 0x1,
  MENU_CAN_REDO = 0x2,
  MENU_CAN_CUT = 0x4,
  MENU_CAN_COPY = 0x8,
  MENU_CAN_PASTE = 0x10,
  MENU_CAN_DELETE = 0x20,
  MENU_CAN_SELECT_ALL = 0x40,
  MENU_CAN_TRANSLATE = 0x80,
  // Values unique to CEF
  MENU_CAN_GO_FORWARD = 0x10000000,
  MENU_CAN_GO_BACK = 0x20000000,
};

///
// Supported menu ID values.
///
enum cef_menu_id_t {
  MENU_ID_NAV_BACK = 10,
  MENU_ID_NAV_FORWARD = 11,
  MENU_ID_NAV_RELOAD = 12,
  MENU_ID_NAV_RELOAD_NOCACHE = 13,
  MENU_ID_NAV_STOP = 14,
  MENU_ID_UNDO = 20,
  MENU_ID_REDO = 21,
  MENU_ID_CUT = 22,
  MENU_ID_COPY = 23,
  MENU_ID_PASTE = 24,
  MENU_ID_DELETE = 25,
  MENU_ID_SELECTALL = 26,
  MENU_ID_PRINT = 30,
  MENU_ID_VIEWSOURCE = 31,
};

enum cef_paint_element_type_t {
  PET_VIEW  = 0,
  PET_POPUP,
};

///
// Post data elements may represent either bytes or files.
///
enum cef_postdataelement_type_t {
  PDE_TYPE_EMPTY  = 0,
  PDE_TYPE_BYTES,
  PDE_TYPE_FILE,
};

enum cef_weburlrequest_flags_t {
  WUR_FLAG_NONE = 0,
  WUR_FLAG_SKIP_CACHE = 0x1,
  WUR_FLAG_ALLOW_CACHED_CREDENTIALS = 0x2,
  WUR_FLAG_ALLOW_COOKIES = 0x4,
  WUR_FLAG_REPORT_UPLOAD_PROGRESS = 0x8,
  WUR_FLAG_REPORT_LOAD_TIMING = 0x10,
  WUR_FLAG_REPORT_RAW_HEADERS = 0x20
};

enum cef_weburlrequest_state_t {
  WUR_STATE_UNSENT = 0,
  WUR_STATE_STARTED = 1,
  WUR_STATE_HEADERS_RECEIVED = 2,
  WUR_STATE_LOADING = 3,
  WUR_STATE_DONE = 4,
  WUR_STATE_ERROR = 5,
  WUR_STATE_ABORT = 6,
};

///
// Focus sources.
///
enum cef_handler_focus_source_t {
  ///
  // The source is explicit navigation via the API (LoadURL(), etc).
  ///
  FOCUS_SOURCE_NAVIGATION = 0,
  ///
  // The source is a system-generated focus event.
  ///
  FOCUS_SOURCE_SYSTEM,
  ///
  // The source is a child widget of the browser window requesting focus.
  ///
  FOCUS_SOURCE_WIDGET,
};

///
// Key event types.
///
enum cef_handler_keyevent_type_t {
  KEYEVENT_RAWKEYDOWN = 0,
  KEYEVENT_KEYDOWN,
  KEYEVENT_KEYUP,
  KEYEVENT_CHAR
};

///
// Key event modifiers.
///
enum cef_handler_keyevent_modifiers_t {
  KEY_SHIFT = 1 << 0,
  KEY_CTRL  = 1 << 1,
  KEY_ALT   = 1 << 2,
  KEY_META  = 1 << 3
};

///
// Structure representing a rectangle.
///
typedef struct _cef_rect_t {
  int x;
  int y;
  int width;
  int height;
} cef_rect_t;

///
// Existing thread IDs.
///
enum cef_thread_id_t {
  TID_UI      = 0,
  TID_IO      = 1,
  TID_FILE    = 2,
};

///
// Paper type for printing.
///
enum cef_paper_type_t {
  PT_LETTER = 0,
  PT_LEGAL,
  PT_EXECUTIVE,
  PT_A3,
  PT_A4,
  PT_CUSTOM
};

///
// Paper metric information for printing.
///
struct cef_paper_metrics {
  enum cef_paper_type_t paper_type;
  // Length and width needed if paper_type is custom_size
  // Units are in inches.
  double length;
  double width;
};

///
// Paper print margins.
///
struct cef_print_margins {
  // Margin size in inches for left/right/top/bottom (this is content margins).
  double left;
  double right;
  double top;
  double bottom;
  // Margin size (top/bottom) in inches for header/footer.
  double header;
  double footer;
};

///
// Page orientation for printing.
///
enum cef_page_orientation {
  PORTRAIT = 0,
  LANDSCAPE
};

///
// Printing options.
///
typedef struct _cef_print_options_t {
  enum cef_page_orientation page_orientation;
  struct cef_paper_metrics paper_metrics;
  struct cef_print_margins paper_margins;
} cef_print_options_t;

///
// Supported XML encoding types. The parser supports ASCII, ISO-8859-1, and
// UTF16 (LE and BE) by default. All other types must be translated to UTF8
// before being passed to the parser. If a BOM is detected and the correct
// decoder is available then that decoder will be used automatically.
///
enum cef_xml_encoding_type_t {
  XML_ENCODING_NONE = 0,
  XML_ENCODING_UTF8,
  XML_ENCODING_UTF16LE,
  XML_ENCODING_UTF16BE,
  XML_ENCODING_ASCII,
};

///
// XML node types.
///
enum cef_xml_node_type_t {
  XML_NODE_UNSUPPORTED = 0,
  XML_NODE_PROCESSING_INSTRUCTION,
  XML_NODE_DOCUMENT_TYPE,
  XML_NODE_ELEMENT_START,
  XML_NODE_ELEMENT_END,
  XML_NODE_ATTRIBUTE,
  XML_NODE_TEXT,
  XML_NODE_CDATA,
  XML_NODE_ENTITY_REFERENCE,
  XML_NODE_WHITESPACE,
  XML_NODE_COMMENT,
};

///
// Status message types.
///
enum cef_handler_statustype_t {
  STATUSTYPE_TEXT = 0,
  STATUSTYPE_MOUSEOVER_URL,
  STATUSTYPE_KEYBOARD_FOCUS_URL,
};

///
// Popup window features.
///
typedef struct _cef_popup_features_t {
  int x;
  bool xSet;
  int y;
  bool ySet;
  int width;
  bool widthSet;
  int height;
  bool heightSet;

  bool menuBarVisible;
  bool statusBarVisible;
  bool toolBarVisible;
  bool locationBarVisible;
  bool scrollbarsVisible;
  bool resizable;

  bool fullscreen;
  bool dialog;
  cef_string_list_t additionalFeatures;
} cef_popup_features_t;

///
// DOM document types.
///
enum cef_dom_document_type_t {
  DOM_DOCUMENT_TYPE_UNKNOWN = 0,
  DOM_DOCUMENT_TYPE_HTML,
  DOM_DOCUMENT_TYPE_XHTML,
  DOM_DOCUMENT_TYPE_PLUGIN,
};

///
// DOM event category flags.
///
enum cef_dom_event_category_t {
  DOM_EVENT_CATEGORY_UNKNOWN = 0x0,
  DOM_EVENT_CATEGORY_UI = 0x1,
  DOM_EVENT_CATEGORY_MOUSE = 0x2,
  DOM_EVENT_CATEGORY_MUTATION = 0x4,
  DOM_EVENT_CATEGORY_KEYBOARD = 0x8,
  DOM_EVENT_CATEGORY_TEXT = 0x10,
  DOM_EVENT_CATEGORY_COMPOSITION = 0x20,
  DOM_EVENT_CATEGORY_DRAG = 0x40,
  DOM_EVENT_CATEGORY_CLIPBOARD = 0x80,
  DOM_EVENT_CATEGORY_MESSAGE = 0x100,
  DOM_EVENT_CATEGORY_WHEEL = 0x200,
  DOM_EVENT_CATEGORY_BEFORE_TEXT_INSERTED = 0x400,
  DOM_EVENT_CATEGORY_OVERFLOW = 0x800,
  DOM_EVENT_CATEGORY_PAGE_TRANSITION = 0x1000,
  DOM_EVENT_CATEGORY_POPSTATE = 0x2000,
  DOM_EVENT_CATEGORY_PROGRESS = 0x4000,
  DOM_EVENT_CATEGORY_XMLHTTPREQUEST_PROGRESS = 0x8000,
  DOM_EVENT_CATEGORY_WEBKIT_ANIMATION = 0x10000,
  DOM_EVENT_CATEGORY_WEBKIT_TRANSITION = 0x20000,
  DOM_EVENT_CATEGORY_BEFORE_LOAD = 0x40000,
};

///
// DOM event processing phases.
///
enum cef_dom_event_phase_t {
  DOM_EVENT_PHASE_UNKNOWN = 0,
  DOM_EVENT_PHASE_CAPTURING,
  DOM_EVENT_PHASE_AT_TARGET,
  DOM_EVENT_PHASE_BUBBLING,
};

///
// DOM node types.
///
enum cef_dom_node_type_t {
  DOM_NODE_TYPE_UNSUPPORTED = 0,
  DOM_NODE_TYPE_ELEMENT,
  DOM_NODE_TYPE_ATTRIBUTE,
  DOM_NODE_TYPE_TEXT,
  DOM_NODE_TYPE_CDATA_SECTION,
  DOM_NODE_TYPE_ENTITY_REFERENCE,
  DOM_NODE_TYPE_ENTITY,
  DOM_NODE_TYPE_PROCESSING_INSTRUCTIONS,
  DOM_NODE_TYPE_COMMENT,
  DOM_NODE_TYPE_DOCUMENT,
  DOM_NODE_TYPE_DOCUMENT_TYPE,
  DOM_NODE_TYPE_DOCUMENT_FRAGMENT,
  DOM_NODE_TYPE_NOTATION,
  DOM_NODE_TYPE_XPATH_NAMESPACE,
};

///
// Proxy types.
///
enum cef_proxy_type_t {
  PROXY_TYPE_DIRECT = 0,
  PROXY_TYPE_NAMED,
  PROXY_TYPE_PAC_STRING,
};

///
// Proxy information.
///
typedef struct _cef_proxy_info_t {
  enum cef_proxy_type_t proxyType;
  cef_string_t proxyList;
} cef_proxy_info_t;

#ifdef __cplusplus
}
#endif

#endif  // CEF_INCLUDE_INTERNAL_CEF_TYPES_H_
