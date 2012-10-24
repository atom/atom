/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_windows_h__
#define INCLUDE_git_windows_h__

#include "common.h"

/**
 * @file git2/windows.h
 * @brief Windows-specific functions
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Set the active codepage for Windows syscalls
 *
 * All syscalls performed by the library will assume
 * this codepage when converting paths and strings
 * to use by the Windows kernel.
 *
 * The default value of UTF-8 will work automatically
 * with most Git repositories created on Unix systems.
 *
 * This settings needs only be changed when working
 * with repositories that contain paths in specific,
 * non-UTF codepages.
 *
 * A full list of all available codepage identifiers may
 * be found at:
 *
 * http://msdn.microsoft.com/en-us/library/windows/desktop/dd317756(v=vs.85).aspx
 *
 * @param codepage numeric codepage identifier
 */
GIT_EXTERN(void) gitwin_set_codepage(unsigned int codepage);

/**
 * Return the active codepage for Windows syscalls
 *
 * @return numeric codepage identifier
 */
GIT_EXTERN(unsigned int) gitwin_get_codepage(void);

/**
 * Set the active Windows codepage to UTF-8 (this is
 * the default value)
 */
GIT_EXTERN(void) gitwin_set_utf8(void);

/** @} */
GIT_END_DECL
#endif

