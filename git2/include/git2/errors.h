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

#ifdef GIT_OLD_ERRORS
enum {
	GIT_SUCCESS = 0,
	GIT_ENOTOID = -2,
	GIT_ENOTFOUND = -3,
	GIT_ENOMEM = -4,
	GIT_EOSERR = -5,
	GIT_EOBJTYPE = -6,
	GIT_ENOTAREPO = -7,
	GIT_EINVALIDTYPE = -8,
	GIT_EMISSINGOBJDATA = -9,
	GIT_EPACKCORRUPTED = -10,
	GIT_EFLOCKFAIL = -11,
	GIT_EZLIB = -12,
	GIT_EBUSY = -13,
	GIT_EBAREINDEX = -14,
	GIT_EINVALIDREFNAME = -15,
	GIT_EREFCORRUPTED = -16,
	GIT_ETOONESTEDSYMREF = -17,
	GIT_EPACKEDREFSCORRUPTED = -18,
	GIT_EINVALIDPATH = -19,
	GIT_EREVWALKOVER = -20,
	GIT_EINVALIDREFSTATE = -21,
	GIT_ENOTIMPLEMENTED = -22,
	GIT_EEXISTS = -23,
	GIT_EOVERFLOW = -24,
	GIT_ENOTNUM = -25,
	GIT_ESTREAM = -26,
	GIT_EINVALIDARGS = -27,
	GIT_EOBJCORRUPTED = -28,
	GIT_EAMBIGUOUS = -29,
	GIT_EPASSTHROUGH = -30,
	GIT_ENOMATCH = -31,
	GIT_ESHORTBUFFER = -32,
};
#endif

/** Generic return codes */
enum {
	GIT_OK = 0,
	GIT_ERROR = -1,
	GIT_ENOTFOUND = -3,
	GIT_EEXISTS = -4,
	GIT_EAMBIGUOUS = -5,
	GIT_EBUFS = -6,

	GIT_PASSTHROUGH = -30,
	GIT_REVWALKOVER = -31,
};

typedef struct {
	char *message;
	int klass;
} git_error;

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

/** @} */
GIT_END_DECL
#endif
