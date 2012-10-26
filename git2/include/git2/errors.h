/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_errors_h__
#define INCLUDE_git_errors_h__

#include "common.h"

/**
 * @file git2/errors.h
 * @brief Git error handling routines and variables
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/** Generic return codes */
enum {
	GIT_OK = 0,
	GIT_ERROR = -1,
	GIT_ENOTFOUND = -3,
	GIT_EEXISTS = -4,
	GIT_EAMBIGUOUS = -5,
	GIT_EBUFS = -6,
	GIT_EUSER = -7,
	GIT_EBAREREPO = -8,
	GIT_EORPHANEDHEAD = -9,
	GIT_EUNMERGED = -10,

	GIT_PASSTHROUGH = -30,
	GIT_ITEROVER = -31,
};

typedef struct {
	char *message;
	int klass;
} git_error;

/** Error classes */
typedef enum {
	GITERR_NOMEMORY,
	GITERR_OS,
	GITERR_INVALID,
	GITERR_REFERENCE,
	GITERR_ZLIB,
	GITERR_REPOSITORY,
	GITERR_CONFIG,
	GITERR_REGEX,
	GITERR_ODB,
	GITERR_INDEX,
	GITERR_OBJECT,
	GITERR_NET,
	GITERR_TAG,
	GITERR_TREE,
	GITERR_INDEXER,
	GITERR_SSL,
	GITERR_SUBMODULE,
	GITERR_THREAD,
} git_error_t;

/**
 * Return the last `git_error` object that was generated for the
 * current thread or NULL if no error has occurred.
 *
 * @return A git_error object.
 */
GIT_EXTERN(const git_error *) giterr_last(void);

/**
 * Clear the last library error that occurred for this thread.
 */
GIT_EXTERN(void) giterr_clear(void);

/**
 * Set the error message string for this thread.
 *
 * This function is public so that custom ODB backends and the like can
 * relay an error message through libgit2.  Most regular users of libgit2
 * will never need to call this function -- actually, calling it in most
 * circumstances (for example, calling from within a callback function)
 * will just end up having the value overwritten by libgit2 internals.
 *
 * This error message is stored in thread-local storage and only applies
 * to the particular thread that this libgit2 call is made from.
 *
 * NOTE: Passing the `error_class` as GITERR_OS has a special behavior: we
 * attempt to append the system default error message for the last OS error
 * that occurred and then clear the last error.  The specific implementation
 * of looking up and clearing this last OS error will vary by platform.
 *
 * @param error_class One of the `git_error_t` enum above describing the
 *                    general subsystem that is responsible for the error.
 * @param message The formatted error message to keep
 */
GIT_EXTERN(void) giterr_set_str(int error_class, const char *string);

/**
 * Set the error message to a special value for memory allocation failure.
 *
 * The normal `giterr_set_str()` function attempts to `strdup()` the string
 * that is passed in.  This is not a good idea when the error in question
 * is a memory allocation failure.  That circumstance has a special setter
 * function that sets the error string to a known and statically allocated
 * internal value.
 */
GIT_EXTERN(void) giterr_set_oom(void);

/** @} */
GIT_END_DECL
#endif
