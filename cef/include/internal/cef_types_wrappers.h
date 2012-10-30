// Copyright (c) 2012 Marshall A. Greenblatt. All rights reserved.
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

#ifndef CEF_INCLUDE_INTERNAL_CEF_TYPES_WRAPPERS_H_
#define CEF_INCLUDE_INTERNAL_CEF_TYPES_WRAPPERS_H_
#pragma once

#include "include/internal/cef_string.h"
#include "include/internal/cef_string_list.h"
#include "include/internal/cef_types.h"

///
// Template class that provides common functionality for CEF structure wrapping.
///
template <class traits>
class CefStructBase : public traits::struct_type {
 public:
  typedef typename traits::struct_type struct_type;

  CefStructBase() : attached_to_(NULL) {
    Init();
  }
  virtual ~CefStructBase() {
    // Only clear this object's data if it isn't currently attached to a
    // structure.
    if (!attached_to_)
      Clear(this);
  }

  CefStructBase(const CefStructBase& r) {
    Init();
    *this = r;
  }
  CefStructBase(const struct_type& r) {  // NOLINT(runtime/explicit)
    Init();
    *this = r;
  }

  ///
  // Clear this object's values.
  ///
  void Reset() {
    Clear(this);
    Init();
  }

  ///
  // Attach to the source structure's existing values. DetachTo() can be called
  // to insert the values back into the existing structure.
  ///
  void AttachTo(struct_type& source) {
    // Only clear this object's data if it isn't currently attached to a
    // structure.
    if (!attached_to_)
      Clear(this);

    // This object is now attached to the new structure.
    attached_to_ = &source;

    // Transfer ownership of the values from the source structure.
    memcpy(static_cast<struct_type*>(this), &source, sizeof(struct_type));
  }

  ///
  // Relinquish ownership of values to the target structure.
  ///
  void DetachTo(struct_type& target) {
    if (attached_to_ != &target) {
      // Clear the target structure's values only if we are not currently
      // attached to that structure.
      Clear(&target);
    }

    // Transfer ownership of the values to the target structure.
    memcpy(&target, static_cast<struct_type*>(this), sizeof(struct_type));

    // Remove the references from this object.
    Init();
  }

  ///
  // Set this object's values. If |copy| is true the source structure's values
  // will be copied instead of referenced.
  ///
  void Set(const struct_type& source, bool copy) {
    traits::set(&source, this, copy);
  }

  CefStructBase& operator=(const CefStructBase& s) {
    return operator=(static_cast<const struct_type&>(s));
  }

  CefStructBase& operator=(const struct_type& s) {
    Set(s, true);
    return *this;
  }

 protected:
  void Init() {
    memset(static_cast<struct_type*>(this), 0, sizeof(struct_type));
    attached_to_ = NULL;
    traits::init(this);
  }

  static void Clear(struct_type* s) { traits::clear(s); }

  struct_type* attached_to_;
};


struct CefRectTraits {
  typedef cef_rect_t struct_type;

  static inline void init(struct_type* s) {}
  static inline void clear(struct_type* s) {}

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    *target = *src;
  }
};

///
// Class representing a rectangle.
///
class CefRect : public CefStructBase<CefRectTraits> {
 public:
  typedef CefStructBase<CefRectTraits> parent;

  CefRect() : parent() {}
  CefRect(const cef_rect_t& r) : parent(r) {}  // NOLINT(runtime/explicit)
  CefRect(const CefRect& r) : parent(r) {}  // NOLINT(runtime/explicit)
  CefRect(int x, int y, int width, int height) : parent() {
    Set(x, y, width, height);
  }

  bool IsEmpty() const { return width <= 0 || height <= 0; }
  void Set(int x, int y, int width, int height) {
    this->x = x, this->y = y, this->width = width, this->height = height;
  }
};

inline bool operator==(const CefRect& a, const CefRect& b) {
  return a.x == b.x && a.y == b.y && a.width == b.width && a.height == b.height;
}

inline bool operator!=(const CefRect& a, const CefRect& b) {
  return !(a == b);
}

struct CefKeyEventTraits {
  typedef cef_key_event_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {}

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    target->type = src->type;
    target->modifiers = src->modifiers;
    target->windows_key_code = src->windows_key_code;
    target->native_key_code = src->native_key_code;
    target->is_system_key = src->is_system_key;
    target->character = src->character;
    target->unmodified_character = src->unmodified_character;
    target->focus_on_editable_field = src->focus_on_editable_field;
  }
};

///
// Class representing a a keyboard event.
///
typedef CefStructBase<CefKeyEventTraits> CefKeyEvent;


struct CefPopupFeaturesTraits {
  typedef cef_popup_features_t struct_type;

  static inline void init(struct_type* s) {
    s->menuBarVisible = true;
    s->statusBarVisible = true;
    s->toolBarVisible = true;
    s->locationBarVisible = true;
    s->scrollbarsVisible = true;
    s->resizable = true;
  }

  static inline void clear(struct_type* s) {
    if (s->additionalFeatures)
      cef_string_list_free(s->additionalFeatures);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    if (target->additionalFeatures)
      cef_string_list_free(target->additionalFeatures);
    target->additionalFeatures = src->additionalFeatures ?
        cef_string_list_copy(src->additionalFeatures) : NULL;

    target->x = src->x;
    target->xSet = src->xSet;
    target->y = src->y;
    target->ySet = src->ySet;
    target->width = src->width;
    target->widthSet = src->widthSet;
    target->height = src->height;
    target->heightSet = src->heightSet;
    target->menuBarVisible = src->menuBarVisible;
    target->statusBarVisible = src->statusBarVisible;
    target->toolBarVisible = src->toolBarVisible;
    target->locationBarVisible = src->locationBarVisible;
    target->scrollbarsVisible = src->scrollbarsVisible;
    target->resizable = src->resizable;
    target->fullscreen = src->fullscreen;
    target->dialog = src->dialog;
  }
};

///
// Class representing popup window features.
///
typedef CefStructBase<CefPopupFeaturesTraits> CefPopupFeatures;


struct CefSettingsTraits {
  typedef cef_settings_t struct_type;

  static inline void init(struct_type* s) {
    s->size = sizeof(struct_type);
  }

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->browser_subprocess_path);
    cef_string_clear(&s->cache_path);
    cef_string_clear(&s->user_agent);
    cef_string_clear(&s->product_version);
    cef_string_clear(&s->locale);
    cef_string_clear(&s->log_file);
    cef_string_clear(&s->javascript_flags);
    cef_string_clear(&s->resources_dir_path);
    cef_string_clear(&s->locales_dir_path);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    target->single_process = src->single_process;
    cef_string_set(src->browser_subprocess_path.str,
        src->browser_subprocess_path.length,
        &target->browser_subprocess_path, copy);
    target->multi_threaded_message_loop = src->multi_threaded_message_loop;
    target->command_line_args_disabled = src->command_line_args_disabled;

    cef_string_set(src->cache_path.str, src->cache_path.length,
        &target->cache_path, copy);
    cef_string_set(src->user_agent.str, src->user_agent.length,
        &target->user_agent, copy);
    cef_string_set(src->product_version.str, src->product_version.length,
        &target->product_version, copy);
    cef_string_set(src->locale.str, src->locale.length, &target->locale, copy);

    cef_string_set(src->log_file.str, src->log_file.length, &target->log_file,
        copy);
    target->log_severity = src->log_severity;
    cef_string_set(src->javascript_flags.str, src->javascript_flags.length,
        &target->javascript_flags, copy);

    target->auto_detect_proxy_settings_enabled =
        src->auto_detect_proxy_settings_enabled;

    cef_string_set(src->resources_dir_path.str, src->resources_dir_path.length,
        &target->resources_dir_path, copy);
    cef_string_set(src->locales_dir_path.str, src->locales_dir_path.length,
        &target->locales_dir_path, copy);
    target->pack_loading_disabled = src->pack_loading_disabled;
    target->remote_debugging_port = src->remote_debugging_port;
  }
};

///
// Class representing initialization settings.
///
typedef CefStructBase<CefSettingsTraits> CefSettings;


struct CefBrowserSettingsTraits {
  typedef cef_browser_settings_t struct_type;

  static inline void init(struct_type* s) {
    s->size = sizeof(struct_type);
  }

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->standard_font_family);
    cef_string_clear(&s->fixed_font_family);
    cef_string_clear(&s->serif_font_family);
    cef_string_clear(&s->sans_serif_font_family);
    cef_string_clear(&s->cursive_font_family);
    cef_string_clear(&s->fantasy_font_family);
    cef_string_clear(&s->default_encoding);
    cef_string_clear(&s->user_style_sheet_location);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    cef_string_set(src->standard_font_family.str,
        src->standard_font_family.length, &target->standard_font_family, copy);
    cef_string_set(src->fixed_font_family.str, src->fixed_font_family.length,
        &target->fixed_font_family, copy);
    cef_string_set(src->serif_font_family.str, src->serif_font_family.length,
        &target->serif_font_family, copy);
    cef_string_set(src->sans_serif_font_family.str,
        src->sans_serif_font_family.length, &target->sans_serif_font_family,
        copy);
    cef_string_set(src->cursive_font_family.str,
        src->cursive_font_family.length, &target->cursive_font_family, copy);
    cef_string_set(src->fantasy_font_family.str,
        src->fantasy_font_family.length, &target->fantasy_font_family, copy);

    target->default_font_size = src->default_font_size;
    target->default_fixed_font_size = src->default_fixed_font_size;
    target->minimum_font_size = src->minimum_font_size;
    target->minimum_logical_font_size = src->minimum_logical_font_size;
    target->remote_fonts_disabled = src->remote_fonts_disabled;

    cef_string_set(src->default_encoding.str, src->default_encoding.length,
        &target->default_encoding, copy);

    target->encoding_detector_enabled = src->encoding_detector_enabled;
    target->javascript_disabled = src->javascript_disabled;
    target->javascript_open_windows_disallowed =
        src->javascript_open_windows_disallowed;
    target->javascript_close_windows_disallowed =
        src->javascript_close_windows_disallowed;
    target->javascript_access_clipboard_disallowed =
        src->javascript_access_clipboard_disallowed;
    target->dom_paste_disabled = src->dom_paste_disabled;
    target->caret_browsing_enabled = src->caret_browsing_enabled;
    target->java_disabled = src->java_disabled;
    target->plugins_disabled = src->plugins_disabled;
    target->universal_access_from_file_urls_allowed =
        src->universal_access_from_file_urls_allowed;
    target->file_access_from_file_urls_allowed =
        src->file_access_from_file_urls_allowed;
    target->web_security_disabled = src->web_security_disabled;
    target->xss_auditor_enabled = src->xss_auditor_enabled;
    target->image_load_disabled = src->image_load_disabled;
    target->shrink_standalone_images_to_fit =
        src->shrink_standalone_images_to_fit;
    target->site_specific_quirks_disabled = src->site_specific_quirks_disabled;
    target->text_area_resize_disabled = src->text_area_resize_disabled;
    target->page_cache_disabled = src->page_cache_disabled;
    target->tab_to_links_disabled = src->tab_to_links_disabled;
    target->hyperlink_auditing_disabled = src->hyperlink_auditing_disabled;
    target->user_style_sheet_enabled = src->user_style_sheet_enabled;

    cef_string_set(src->user_style_sheet_location.str,
        src->user_style_sheet_location.length,
        &target->user_style_sheet_location, copy);

    target->author_and_user_styles_disabled =
        src->author_and_user_styles_disabled;
    target->local_storage_disabled = src->local_storage_disabled;
    target->databases_disabled = src->databases_disabled;
    target->application_cache_disabled = src->application_cache_disabled;
    target->webgl_disabled = src->webgl_disabled;
    target->accelerated_compositing_disabled =
        src->accelerated_compositing_disabled;
    target->accelerated_layers_disabled = src->accelerated_layers_disabled;
    target->accelerated_video_disabled = src->accelerated_video_disabled;
    target->accelerated_2d_canvas_disabled =
        src->accelerated_2d_canvas_disabled;
    target->accelerated_painting_enabled = src->accelerated_painting_enabled;
    target->accelerated_filters_enabled = src->accelerated_filters_enabled;
    target->accelerated_plugins_disabled = src->accelerated_plugins_disabled;
    target->developer_tools_disabled = src->developer_tools_disabled;
    target->fullscreen_enabled = src->fullscreen_enabled;
  }
};

///
// Class representing browser initialization settings.
///
typedef CefStructBase<CefBrowserSettingsTraits> CefBrowserSettings;


struct CefURLPartsTraits {
  typedef cef_urlparts_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->spec);
    cef_string_clear(&s->scheme);
    cef_string_clear(&s->username);
    cef_string_clear(&s->password);
    cef_string_clear(&s->host);
    cef_string_clear(&s->port);
    cef_string_clear(&s->path);
    cef_string_clear(&s->query);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    cef_string_set(src->spec.str, src->spec.length, &target->spec, copy);
    cef_string_set(src->scheme.str, src->scheme.length, &target->scheme, copy);
    cef_string_set(src->username.str, src->username.length, &target->username,
        copy);
    cef_string_set(src->password.str, src->password.length, &target->password,
        copy);
    cef_string_set(src->host.str, src->host.length, &target->host, copy);
    cef_string_set(src->port.str, src->port.length, &target->port, copy);
    cef_string_set(src->path.str, src->path.length, &target->path, copy);
    cef_string_set(src->query.str, src->query.length, &target->query, copy);
  }
};

///
// Class representing a URL's component parts.
///
typedef CefStructBase<CefURLPartsTraits> CefURLParts;


struct CefTimeTraits {
  typedef cef_time_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {}

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    *target = *src;
  }
};

///
// Class representing a time.
///
class CefTime : public CefStructBase<CefTimeTraits> {
 public:
  typedef CefStructBase<CefTimeTraits> parent;

  CefTime() : parent() {}
  CefTime(const cef_time_t& r) : parent(r) {}  // NOLINT(runtime/explicit)
  CefTime(const CefTime& r) : parent(r) {}  // NOLINT(runtime/explicit)
  explicit CefTime(time_t r) : parent() { SetTimeT(r); }
  explicit CefTime(double r) : parent() { SetDoubleT(r); }

  // Converts to/from time_t.
  void SetTimeT(time_t r) {
    cef_time_from_timet(r, this);
  }
  time_t GetTimeT() const {
    time_t time = 0;
    cef_time_to_timet(this, &time);
    return time;
  }

  // Converts to/from a double which is the number of seconds since epoch
  // (Jan 1, 1970). Webkit uses this format to represent time. A value of 0
  // means "not initialized".
  void SetDoubleT(double r) {
    cef_time_from_doublet(r, this);
  }
  double GetDoubleT() const {
    double time = 0;
    cef_time_to_doublet(this, &time);
    return time;
  }
};


struct CefCookieTraits {
  typedef cef_cookie_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->name);
    cef_string_clear(&s->value);
    cef_string_clear(&s->domain);
    cef_string_clear(&s->path);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    cef_string_set(src->name.str, src->name.length, &target->name, copy);
    cef_string_set(src->value.str, src->value.length, &target->value, copy);
    cef_string_set(src->domain.str, src->domain.length, &target->domain, copy);
    cef_string_set(src->path.str, src->path.length, &target->path, copy);
    target->secure = src->secure;
    target->httponly = src->httponly;
    target->creation = src->creation;
    target->last_access = src->last_access;
    target->has_expires = src->has_expires;
    target->expires = src->expires;
  }
};

///
// Class representing a cookie.
///
typedef CefStructBase<CefCookieTraits> CefCookie;


struct CefProxyInfoTraits {
  typedef cef_proxy_info_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->proxyList);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    target->proxyType = src->proxyType;
    cef_string_set(src->proxyList.str, src->proxyList.length,
        &target->proxyList, copy);
  }
};

///
// Class representing the results of proxy resolution.
///
class CefProxyInfo : public CefStructBase<CefProxyInfoTraits> {
 public:
  ///
  // Use a direction connection instead of a proxy.
  ///
  void UseDirect() {
    proxyType = CEF_PROXY_TYPE_DIRECT;
  }

  ///
  // Use one or more named proxy servers specified in WinHTTP format. Each proxy
  // server is of the form:
  //
  // [<scheme>"://"]<server>[":"<port>]
  //
  // Multiple values may be separated by semicolons or whitespace. For example,
  // "foo1:80;foo2:80".
  ///
  void UseNamedProxy(const CefString& proxy_uri_list) {
    proxyType = CEF_PROXY_TYPE_NAMED;
    (CefString(&proxyList)) = proxy_uri_list;
  }

  ///
  // Use one or more named proxy servers specified in PAC script format. For
  // example, "PROXY foobar:99; SOCKS fml:2; DIRECT".
  ///
  void UsePacString(const CefString& pac_string) {
    proxyType = CEF_PROXY_TYPE_PAC_STRING;
    (CefString(&proxyList)) = pac_string;
  }

  bool IsDirect() const { return proxyType == CEF_PROXY_TYPE_DIRECT; }
  bool IsNamedProxy() const { return proxyType == CEF_PROXY_TYPE_NAMED; }
  bool IsPacString() const { return proxyType == CEF_PROXY_TYPE_PAC_STRING; }

  CefString ProxyList() const { return CefString(&proxyList); }
};

struct CefGeopositionTraits {
  typedef cef_geoposition_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s) {
    cef_string_clear(&s->error_message);
  }

  static inline void set(const struct_type* src, struct_type* target,
      bool copy) {
    target->latitude = src->latitude;
    target->longitude = src->longitude;
    target->altitude = src->altitude;
    target->accuracy = src->accuracy;
    target->altitude_accuracy = src->altitude_accuracy;
    target->heading = src->heading;
    target->speed = src->speed;
    target->timestamp = src->timestamp;
    target->error_code = src->error_code;
    cef_string_set(src->error_message.str, src->error_message.length,
        &target->error_message, copy);
  }
};

///
// Class representing a geoposition.
///
typedef CefStructBase<CefGeopositionTraits> CefGeoposition;

#endif  // CEF_INCLUDE_INTERNAL_CEF_TYPES_WRAPPERS_H_
