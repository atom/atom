/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_status_h__
#define INCLUDE_git_status_h__

#include "common.h"
#include "types.h"

/**
 * @file git2/status.h
 * @brief Git file status routines
 * @defgroup git_status Git file status routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

enum {
	GIT_STATUS_CURRENT	= 0,

	GIT_STATUS_INDEX_NEW = (1 << 0),
	GIT_STATUS_INDEX_MODIFIED = (1 << 1),
	GIT_STATUS_INDEX_DELETED = (1 << 2),

	GIT_STATUS_WT_NEW = (1 << 3),
	GIT_STATUS_WT_MODIFIED = (1 << 4),
	GIT_STATUS_WT_DELETED = (1 << 5),

	GIT_STATUS_IGNORED = (1 << 6),
};

/**
 * Gather file statuses and run a callback for each one.
 *
 * The callback is passed the path of the file, the status and the data
 * pointer passed to this function. If the callback returns something other
 * than 0, this function will return that value.
 *
 * @param repo a repository object
 * @param callback the function to call on each file
 * @return 0 on success or the return value of the callback that was non-zero
 */
GIT_EXTERN(int) git_status_foreach(
	git_repository *repo,
	int (*callback)(const char *, unsigned int, void *),
	void *payload);

/**
 * Select the files on which to report status.
 *
 * - GIT_STATUS_SHOW_INDEX_AND_WORKDIR is the default.  This is the
 *   rough equivalent of `git status --porcelain` where each file
 *   will receive a callback indicating its status in the index and
 *   in the workdir.
 * - GIT_STATUS_SHOW_INDEX_ONLY will only make callbacks for index
 *   side of status.  The status of the index contents relative to
 *   the HEAD will be given.
 * - GIT_STATUS_SHOW_WORKDIR_ONLY will only make callbacks for the
 *   workdir side of status, reporting the status of workdir content
 *   relative to the index.
 * - GIT_STATUS_SHOW_INDEX_THEN_WORKDIR behaves like index-only
 *   followed by workdir-only, causing two callbacks to be issued
 *   per file (first index then workdir).  This is slightly more
 *   efficient than making separate calls.  This makes it easier to
 *   emulate the output of a plain `git status`.
 */
typedef enum {
	GIT_STATUS_SHOW_INDEX_AND_WORKDIR = 0,
	GIT_STATUS_SHOW_INDEX_ONLY = 1,
	GIT_STATUS_SHOW_WORKDIR_ONLY = 2,
	GIT_STATUS_SHOW_INDEX_THEN_WORKDIR = 3,
} git_status_show_t;

/**
 * Flags to control status callbacks
 *
 * - GIT_STATUS_OPT_INCLUDE_UNTRACKED says that callbacks should
 *   be made on untracked files.  These will only be made if the
 *   workdir files are included in the status "show" option.
 * - GIT_STATUS_OPT_INCLUDE_IGNORED says that ignored files should
 *   get callbacks.  Again, these callbacks will only be made if
 *   the workdir files are included in the status "show" option.
 *   Right now, there is no option to include all files in
 *   directories that are ignored completely.
 * - GIT_STATUS_OPT_INCLUDE_UNMODIFIED indicates that callback
 *   should be made even on unmodified files.
 * - GIT_STATUS_OPT_EXCLUDE_SUBMODULES indicates that directories
 *   which appear to be submodules should just be skipped over.
 * - GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS indicates that the
 *   contents of untracked directories should be included in the
 *   status.  Normally if an entire directory is new, then just
 *   the top-level directory will be included (with a trailing
 *   slash on the entry name).  Given this flag, the directory
 *   itself will not be included, but all the files in it will.
 */

enum {
	GIT_STATUS_OPT_INCLUDE_UNTRACKED = (1 << 0),
	GIT_STATUS_OPT_INCLUDE_IGNORED = (1 << 1),
	GIT_STATUS_OPT_INCLUDE_UNMODIFIED = (1 << 2),
	GIT_STATUS_OPT_EXCLUDE_SUBMODULED = (1 << 3),
	GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS = (1 << 4),
};

/**
 * Options to control how callbacks will be made by
 * `git_status_foreach_ext()`.
 */
typedef struct {
	git_status_show_t show;
	unsigned int flags;
	git_strarray pathspec;
} git_status_options;

/**
 * Gather file status information and run callbacks as requested.
 */
GIT_EXTERN(int) git_status_foreach_ext(
	git_repository *repo,
	const git_status_options *opts,
	int (*callback)(const char *, unsigned int, void *),
	void *payload);

/**
 * Get file status for a single file
 *
 * @param status_flags the status value
 * @param repo a repository object
 * @param path the file to retrieve status for, rooted at the repo's workdir
 * @return GIT_EINVALIDPATH when `path` points at a folder, GIT_ENOTFOUND when
 *		the file doesn't exist in any of HEAD, the index or the worktree,
 *		0 otherwise
 */
GIT_EXTERN(int) git_status_file(
	unsigned int *status_flags,
	git_repository *repo,
	const char *path);

/**
 * Test if the ignore rules apply to a given file.
 *
 * This function simply checks the ignore rules to see if they would apply
 * to the given file.  Unlike git_status_file(), this indicates if the file
 * would be ignored regardless of whether the file is already in the index
 * or in the repository.
 *
 * @param ignored boolean returning 0 if the file is not ignored, 1 if it is
 * @param repo a repository object
 * @param path the file to check ignores for, rooted at the repo's workdir.
 * @return 0 if ignore rules could be processed for the file (regardless
 *         of whether it exists or not), or an error < 0 if they could not.
 */
GIT_EXTERN(int) git_status_should_ignore(
	int *ignored,
	git_repository *repo,
	const char *path);

/** @} */
GIT_END_DECL
#endif
