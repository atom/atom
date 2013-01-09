/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
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

/**
 * Status flags for a single file.
 *
 * A combination of these values will be returned to indicate the status of
 * a file.  Status compares the working directory, the index, and the
 * current HEAD of the repository.  The `GIT_STATUS_INDEX` set of flags
 * represents the status of file in the index relative to the HEAD, and the
 * `GIT_STATUS_WT` set of flags represent the status of the file in the
 * working directory relative to the index.
 */
typedef enum {
	GIT_STATUS_CURRENT = 0,

	GIT_STATUS_INDEX_NEW        = (1u << 0),
	GIT_STATUS_INDEX_MODIFIED   = (1u << 1),
	GIT_STATUS_INDEX_DELETED    = (1u << 2),
	GIT_STATUS_INDEX_RENAMED    = (1u << 3),
	GIT_STATUS_INDEX_TYPECHANGE = (1u << 4),

	GIT_STATUS_WT_NEW           = (1u << 7),
	GIT_STATUS_WT_MODIFIED      = (1u << 8),
	GIT_STATUS_WT_DELETED       = (1u << 9),
	GIT_STATUS_WT_TYPECHANGE    = (1u << 10),

	GIT_STATUS_IGNORED          = (1u << 14),
} git_status_t;

/**
 * Function pointer to receive status on individual files
 *
 * `path` is the relative path to the file from the root of the repository.
 *
 * `status_flags` is a combination of `git_status_t` values that apply.
 *
 * `payload` is the value you passed to the foreach function as payload.
 */
typedef int (*git_status_cb)(
	const char *path, unsigned int status_flags, void *payload);

/**
 * Gather file statuses and run a callback for each one.
 *
 * The callback is passed the path of the file, the status (a combination of
 * the `git_status_t` values above) and the `payload` data pointer passed
 * into this function.
 *
 * If the callback returns a non-zero value, this function will stop looping
 * and return GIT_EUSER.
 *
 * @param repo A repository object
 * @param callback The function to call on each file
 * @param payload Pointer to pass through to callback function
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_status_foreach(
	git_repository *repo,
	git_status_cb callback,
	void *payload);

/**
 * For extended status, select the files on which to report status.
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
 * - GIT_STATUS_OPT_INCLUDE_UNTRACKED says that callbacks should be made
 *   on untracked files.  These will only be made if the workdir files are
 *   included in the status "show" option.
 * - GIT_STATUS_OPT_INCLUDE_IGNORED says that ignored files should get
 *   callbacks.  Again, these callbacks will only be made if the workdir
 *   files are included in the status "show" option.  Right now, there is
 *   no option to include all files in directories that are ignored
 *   completely.
 * - GIT_STATUS_OPT_INCLUDE_UNMODIFIED indicates that callback should be
 *   made even on unmodified files.
 * - GIT_STATUS_OPT_EXCLUDE_SUBMODULES indicates that directories which
 *   appear to be submodules should just be skipped over.
 * - GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS indicates that the contents of
 *   untracked directories should be included in the status.  Normally if
 *   an entire directory is new, then just the top-level directory will be
 *   included (with a trailing slash on the entry name).  Given this flag,
 *   the directory itself will not be included, but all the files in it
 *   will.
 * - GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH indicates that the given path
 *   will be treated as a literal path, and not as a pathspec.
 *
 * Calling `git_status_foreach()` is like calling the extended version
 * with: GIT_STATUS_OPT_INCLUDE_IGNORED, GIT_STATUS_OPT_INCLUDE_UNTRACKED,
 * and GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS.
 */
typedef enum {
	GIT_STATUS_OPT_INCLUDE_UNTRACKED = (1 << 0),
	GIT_STATUS_OPT_INCLUDE_IGNORED = (1 << 1),
	GIT_STATUS_OPT_INCLUDE_UNMODIFIED = (1 << 2),
	GIT_STATUS_OPT_EXCLUDE_SUBMODULES = (1 << 3),
	GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS = (1 << 4),
	GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH = (1 << 5),
} git_status_opt_t;

/**
 * Options to control how `git_status_foreach_ext()` will issue callbacks.
 *
 * This structure is set so that zeroing it out will give you relatively
 * sane defaults.
 *
 * The `show` value is one of the `git_status_show_t` constants that
 * control which files to scan and in what order.
 *
 * The `flags` value is an OR'ed combination of the `git_status_opt_t`
 * values above.
 *
 * The `pathspec` is an array of path patterns to match (using
 * fnmatch-style matching), or just an array of paths to match exactly if
 * `GIT_STATUS_OPT_DISABLE_PATHSPEC_MATCH` is specified in the flags.
 */
typedef struct {
	unsigned int      version;
	git_status_show_t show;
	unsigned int      flags;
	git_strarray      pathspec;
} git_status_options;

#define GIT_STATUS_OPTIONS_VERSION 1
#define GIT_STATUS_OPTIONS_INIT {GIT_STATUS_OPTIONS_VERSION}

/**
 * Gather file status information and run callbacks as requested.
 *
 * This is an extended version of the `git_status_foreach()` API that
 * allows for more granular control over which paths will be processed and
 * in what order.  See the `git_status_options` structure for details
 * about the additional controls that this makes available.
 *
 * @param repo Repository object
 * @param opts Status options structure
 * @param callback The function to call on each file
 * @param payload Pointer to pass through to callback function
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_status_foreach_ext(
	git_repository *repo,
	const git_status_options *opts,
	git_status_cb callback,
	void *payload);

/**
 * Get file status for a single file.
 *
 * This is not quite the same as calling `git_status_foreach_ext()` with
 * the pathspec set to the specified path.
 *
 * @param status_flags The status value for the file
 * @param repo A repository object
 * @param path The file to retrieve status for, rooted at the repo's workdir
 * @return 0 on success, GIT_ENOTFOUND if the file is not found in the HEAD,
 *      index, and work tree, GIT_EINVALIDPATH if `path` points at a folder,
 *      GIT_EAMBIGUOUS if "path" matches multiple files, -1 on other error.
 */
GIT_EXTERN(int) git_status_file(
	unsigned int *status_flags,
	git_repository *repo,
	const char *path);

/**
 * Test if the ignore rules apply to a given file.
 *
 * This function checks the ignore rules to see if they would apply to the
 * given file.  This indicates if the file would be ignored regardless of
 * whether the file is already in the index or committed to the repository.
 *
 * One way to think of this is if you were to do "git add ." on the
 * directory containing the file, would it be added or not?
 *
 * @param ignored Boolean returning 0 if the file is not ignored, 1 if it is
 * @param repo A repository object
 * @param path The file to check ignores for, rooted at the repo's workdir.
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
