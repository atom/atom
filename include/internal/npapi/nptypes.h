/* -*- Mode: C; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * mozilla.org.
 * Portions created by the Initial Developer are Copyright (C) 2004
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Johnny Stenback <jst@mozilla.org> (Original author)
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#ifndef nptypes_h_
#define nptypes_h_

/*
 * Header file for ensuring that C99 types ([u]int32_t, [u]int64_t and bool) and
 * true/false macros are available.
 */

#if defined(WIN32) || defined(OS2)
  /*
   * Win32 and OS/2 don't know C99, so define [u]int_16/32/64 here. The bool
   * is predefined tho, both in C and C++.
   */
  typedef short int16_t;
  typedef unsigned short uint16_t;
  typedef int int32_t;
  typedef unsigned int uint32_t;
  typedef long long int64_t;
  typedef unsigned long long uint64_t;
#elif defined(_AIX) || defined(__sun) || defined(__osf__) || defined(IRIX) || defined(HPUX)
  /*
   * AIX and SunOS ship a inttypes.h header that defines [u]int32_t,
   * but not bool for C.
   */
  #include <inttypes.h>

  #ifndef __cplusplus
    typedef int bool;
    #define true   1
    #define false  0
  #endif
#elif defined(bsdi) || defined(FREEBSD) || defined(OPENBSD)
  /*
   * BSD/OS, FreeBSD, and OpenBSD ship sys/types.h that define int32_t and 
   * u_int32_t.
   */
  #include <sys/types.h>

  /*
   * BSD/OS ships no header that defines uint32_t, nor bool (for C)
   */
  #if defined(bsdi)
  typedef u_int32_t uint32_t;
  typedef u_int64_t uint64_t;

  #if !defined(__cplusplus)
    typedef int bool;
    #define true   1
    #define false  0
  #endif
  #else
  /*
   * FreeBSD and OpenBSD define uint32_t and bool.
   */
    #include <inttypes.h>
    #include <stdbool.h>
  #endif
#elif defined(BEOS)
  #include <inttypes.h>
#else
  /*
   * For those that ship a standard C99 stdint.h header file, include
   * it. Can't do the same for stdbool.h tho, since some systems ship
   * with a stdbool.h file that doesn't compile!
   */
  #include <stdint.h>

  #ifndef __cplusplus
    #if !defined(__GNUC__) || (__GNUC__ > 2 || __GNUC_MINOR__ > 95)
      #include <stdbool.h>
    #else
      /*
       * GCC 2.91 can't deal with a typedef for bool, but a #define
       * works.
       */
      #define bool int
      #define true   1
      #define false  0
    #endif
  #endif
#endif

#endif /* nptypes_h_ */
