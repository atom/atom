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


#ifndef _CEF_MAC_H
#define _CEF_MAC_H

#if defined(OS_MACOSX)
#include <pthread.h>
#include "cef_types_mac.h"
#include "cef_types_wrappers.h"

// Atomic increment and decrement.
inline long CefAtomicIncrement(long volatile *pDest)
{
  return __sync_add_and_fetch(pDest, 1);
}
inline long CefAtomicDecrement(long volatile *pDest)
{
  return __sync_sub_and_fetch(pDest, 1);
}

// Handle types.
#define CefWindowHandle cef_window_handle_t
#define CefCursorHandle cef_cursor_handle_t

// Critical section wrapper.
class CefCriticalSection
{
public:
  CefCriticalSection()
  {
    pthread_mutexattr_init(&attr_);
    pthread_mutexattr_settype(&attr_, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&lock_, &attr_);
  }
  virtual ~CefCriticalSection()
  {
    pthread_mutex_destroy(&lock_);
    pthread_mutexattr_destroy(&attr_);
  }
  void Lock()
  {
    pthread_mutex_lock(&lock_);
  }
  void Unlock()
  {
    pthread_mutex_unlock(&lock_);
  }

  pthread_mutex_t lock_;
  pthread_mutexattr_t attr_;
};

struct CefWindowInfoTraits {
  typedef cef_window_info_t struct_type;

  static inline void init(struct_type* s) {}

  static inline void clear(struct_type* s)
  {
    cef_string_clear(&s->m_windowName);
  }

  static inline void set(const struct_type* src, struct_type* target, bool copy)
  {
    target->m_View = src->m_View;
    target->m_ParentView = src->m_ParentView;
    cef_string_set(src->m_windowName.str, src->m_windowName.length,
        &target->m_windowName, copy);
    target->m_x = src->m_x;
    target->m_y = src->m_y;
    target->m_nWidth = src->m_nWidth;
    target->m_nHeight = src->m_nHeight;
    target->m_bHidden = src->m_bHidden;
  }
};

// Class representing window information.
class CefWindowInfo : public CefStructBase<CefWindowInfoTraits>
{
public:
  typedef CefStructBase<CefWindowInfoTraits> parent;

  CefWindowInfo() : parent() {}
  CefWindowInfo(const cef_window_info_t& r) : parent(r) {}
  CefWindowInfo(const CefWindowInfo& r) : parent(r) {}
  
  void SetAsChild(CefWindowHandle ParentView, int x, int y, int width,
                  int height)
  {
    m_ParentView = ParentView;
    m_x = x;
    m_y = y;
    m_nWidth = width;
    m_nHeight = height;
    m_bHidden = false;
  }
};

struct CefPrintInfoTraits {
  typedef cef_print_info_t struct_type;

  static inline void init(struct_type* s) {}
  static inline void clear(struct_type* s) {}

  static inline void set(const struct_type* src, struct_type* target, bool copy)
  {
    target->m_Scale = src->m_Scale;
  }
};

// Class representing print context information.
typedef CefStructBase<CefPrintInfoTraits> CefPrintInfo;

#endif // OS_MACOSX

#endif // _CEF_MAC_H
