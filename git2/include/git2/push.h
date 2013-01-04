/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_push_h__
#define INCLUDE_git_push_h__

#include "common.h"

/**
 * @file git2/push.h
 * @brief Git push management functions
 * @defgroup git_push push management functions
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Create a new push object
 *
 * @param out New push object
 * @param remote Remote instance
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_push_new(git_push **out, git_remote *remote);

/**
 * Add a refspec to be pushed
 *
 * @param push The push object
 * @param refspec Refspec string
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_push_add_refspec(git_push *push, const char *refspec);

/**
 * Actually push all given refspecs
 *
 * @param push The push object
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_push_finish(git_push *push);

/**
 * Check if remote side successfully unpacked
 *
 * @param push The push object
 *
 * @return true if equal, false otherwise
 */
GIT_EXTERN(int) git_push_unpack_ok(git_push *push);

/**
 * Call callback `cb' on each status
 *
 * @param push The push object
 * @param cb The callback to call on each object
 *
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_push_status_foreach(git_push *push,
			int (*cb)(const char *ref, const char *msg, void *data),
			void *data);

/**
 * Free the given push object
 *
 * @param push The push object
 */
GIT_EXTERN(void) git_push_free(git_push *push);

/** @} */
GIT_END_DECL
#endif
