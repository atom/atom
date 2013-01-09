/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_checkout_h__
#define INCLUDE_git_checkout_h__

#include "common.h"
#include "types.h"
#include "diff.h"

/**
 * @file git2/checkout.h
 * @brief Git checkout routines
 * @defgroup git_checkout Git checkout routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Checkout behavior flags
 *
 * In libgit2, checkout is used to update the working directory and index
 * to match a target tree.  Unlike git checkout, it does not move the HEAD
 * commit for you - use `git_repository_set_head` or the like to do that.
 *
 * Checkout looks at (up to) four things: the "target" tree you want to
 * check out, the "baseline" tree of what was checked out previously, the
 * working directory for actual files, and the index for staged changes.
 *
 * You give checkout one of four strategies for update:
 *
 * - `GIT_CHECKOUT_NONE` is a dry-run strategy that checks for conflicts,
 *   etc., but doesn't make any actual changes.
 *
 * - `GIT_CHECKOUT_FORCE` is at the opposite extreme, taking any action to
 *   make the working directory match the target (including potentially
 *   discarding modified files).
 *
 * In between those are `GIT_CHECKOUT_SAFE` and `GIT_CHECKOUT_SAFE_CREATE`
 * both of which only make modifications that will not lose changes.
 *
 *                      |  target == baseline   |  target != baseline  |
 * ---------------------|-----------------------|----------------------|
 *  workdir == baseline |       no action       |  create, update, or  |
 *                      |                       |     delete file      |
 * ---------------------|-----------------------|----------------------|
 *  workdir exists and  |       no action       |   conflict (notify   |
 *    is != baseline    | notify dirty MODIFIED | and cancel checkout) |
 * ---------------------|-----------------------|----------------------|
 *   workdir missing,   | create if SAFE_CREATE |     create file      |
 *   baseline present   | notify dirty DELETED  |                      |
 * ---------------------|-----------------------|----------------------|
 *
 * The only difference between SAFE and SAFE_CREATE is that SAFE_CREATE
 * will cause a file to be checked out if it is missing from the working
 * directory even if it is not modified between the target and baseline.
 *
 *
 * To emulate `git checkout`, use `GIT_CHECKOUT_SAFE` with a checkout
 * notification callback (see below) that displays information about dirty
 * files.  The default behavior will cancel checkout on conflicts.
 *
 * To emulate `git checkout-index`, use `GIT_CHECKOUT_SAFE_CREATE` with a
 * notification callback that cancels the operation if a dirty-but-existing
 * file is found in the working directory.  This core git command isn't
 * quite "force" but is sensitive about some types of changes.
 *
 * To emulate `git checkout -f`, use `GIT_CHECKOUT_FORCE`.
 *
 * To emulate `git clone` use `GIT_CHECKOUT_SAFE_CREATE` in the options.
 *
 *
 * There are some additional flags to modified the behavior of checkout:
 *
 * - GIT_CHECKOUT_ALLOW_CONFLICTS makes SAFE mode apply safe file updates
 *   even if there are conflicts (instead of cancelling the checkout).
 *
 * - GIT_CHECKOUT_REMOVE_UNTRACKED means remove untracked files (i.e. not
 *   in target, baseline, or index, and not ignored) from the working dir.
 *
 * - GIT_CHECKOUT_REMOVE_IGNORED means remove ignored files (that are also
 *   untracked) from the working directory as well.
 *
 * - GIT_CHECKOUT_UPDATE_ONLY means to only update the content of files that
 *   already exist.  Files will not be created nor deleted.  This just skips
 *   applying adds, deletes, and typechanges.
 *
 * - GIT_CHECKOUT_DONT_UPDATE_INDEX prevents checkout from writing the
 *   updated files' information to the index.
 *
 * - Normally, checkout will reload the index and git attributes from disk
 *   before any operations.  GIT_CHECKOUT_NO_REFRESH prevents this reload.
 *
 * - Unmerged index entries are conflicts.  GIT_CHECKOUT_SKIP_UNMERGED skips
 *   files with unmerged index entries instead.  GIT_CHECKOUT_USE_OURS and
 *   GIT_CHECKOUT_USE_THEIRS to proceed with the checkout using either the
 *   stage 2 ("ours") or stage 3 ("theirs") version of files in the index.
 */
typedef enum {
	GIT_CHECKOUT_NONE = 0, /** default is a dry run, no actual updates */

	/** Allow safe updates that cannot overwrite uncommitted data */
	GIT_CHECKOUT_SAFE = (1u << 0),

	/** Allow safe updates plus creation of missing files */
	GIT_CHECKOUT_SAFE_CREATE = (1u << 1),

	/** Allow all updates to force working directory to look like index */
	GIT_CHECKOUT_FORCE = (1u << 2),


	/** Allow checkout to make safe updates even if conflicts are found */
	GIT_CHECKOUT_ALLOW_CONFLICTS = (1u << 4),

	/** Remove untracked files not in index (that are not ignored) */
	GIT_CHECKOUT_REMOVE_UNTRACKED = (1u << 5),

	/** Remove ignored files not in index */
	GIT_CHECKOUT_REMOVE_IGNORED = (1u << 6),

	/** Only update existing files, don't create new ones */
	GIT_CHECKOUT_UPDATE_ONLY = (1u << 7),

	/** Normally checkout updates index entries as it goes; this stops that */
	GIT_CHECKOUT_DONT_UPDATE_INDEX = (1u << 8),

	/** Don't refresh index/config/etc before doing checkout */
	GIT_CHECKOUT_NO_REFRESH = (1u << 9),

	/**
	 * THE FOLLOWING OPTIONS ARE NOT YET IMPLEMENTED
	 */

	/** Allow checkout to skip unmerged files (NOT IMPLEMENTED) */
	GIT_CHECKOUT_SKIP_UNMERGED = (1u << 10),
	/** For unmerged files, checkout stage 2 from index (NOT IMPLEMENTED) */
	GIT_CHECKOUT_USE_OURS = (1u << 11),
	/** For unmerged files, checkout stage 3 from index (NOT IMPLEMENTED) */
	GIT_CHECKOUT_USE_THEIRS = (1u << 12),

	/** Recursively checkout submodules with same options (NOT IMPLEMENTED) */
	GIT_CHECKOUT_UPDATE_SUBMODULES = (1u << 16),
	/** Recursively checkout submodules if HEAD moved in super repo (NOT IMPLEMENTED) */
	GIT_CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED = (1u << 17),

} git_checkout_strategy_t;

/**
 * Checkout notification flags
 *
 * Checkout will invoke an options notification callback (`notify_cb`) for
 * certain cases - you pick which ones via `notify_flags`:
 *
 * - GIT_CHECKOUT_NOTIFY_CONFLICT invokes checkout on conflicting paths.
 *
 * - GIT_CHECKOUT_NOTIFY_DIRTY notifies about "dirty" files, i.e. those that
 *   do not need an update but no longer match the baseline.  Core git
 *   displays these files when checkout runs, but won't stop the checkout.
 *
 * - GIT_CHECKOUT_NOTIFY_UPDATED sends notification for any file changed.
 *
 * - GIT_CHECKOUT_NOTIFY_UNTRACKED notifies about untracked files.
 *
 * - GIT_CHECKOUT_NOTIFY_IGNORED notifies about ignored files.
 *
 * Returning a non-zero value from this callback will cancel the checkout.
 * Notification callbacks are made prior to modifying any files on disk.
 */
typedef enum {
	GIT_CHECKOUT_NOTIFY_NONE      = 0,
	GIT_CHECKOUT_NOTIFY_CONFLICT  = (1u << 0),
	GIT_CHECKOUT_NOTIFY_DIRTY     = (1u << 1),
	GIT_CHECKOUT_NOTIFY_UPDATED   = (1u << 2),
	GIT_CHECKOUT_NOTIFY_UNTRACKED = (1u << 3),
	GIT_CHECKOUT_NOTIFY_IGNORED   = (1u << 4),
} git_checkout_notify_t;

/** Checkout notification callback function */
typedef int (*git_checkout_notify_cb)(
	git_checkout_notify_t why,
	const char *path,
	const git_diff_file *baseline,
	const git_diff_file *target,
	const git_diff_file *workdir,
	void *payload);

/** Checkout progress notification function */
typedef void (*git_checkout_progress_cb)(
	const char *path,
	size_t completed_steps,
	size_t total_steps,
	void *payload);

/**
 * Checkout options structure
 *
 * Zero out for defaults.  Initialize with `GIT_CHECKOUT_OPTS_INIT` macro to
 * correctly set the `version` field.  E.g.
 *
 *		git_checkout_opts opts = GIT_CHECKOUT_OPTS_INIT;
 */
typedef struct git_checkout_opts {
	unsigned int version;

	unsigned int checkout_strategy; /** default will be a dry run */

	int disable_filters;    /** don't apply filters like CRLF conversion */
	unsigned int dir_mode;  /** default is 0755 */
	unsigned int file_mode; /** default is 0644 or 0755 as dictated by blob */
	int file_open_flags;    /** default is O_CREAT | O_TRUNC | O_WRONLY */

	unsigned int notify_flags; /** see `git_checkout_notify_t` above */
	git_checkout_notify_cb notify_cb;
	void *notify_payload;

	/* Optional callback to notify the consumer of checkout progress. */
	git_checkout_progress_cb progress_cb;
	void *progress_payload;

	/** When not zeroed out, array of fnmatch patterns specifying which
	 *  paths should be taken into account, otherwise all files.
	 */
	git_strarray paths;

	git_tree *baseline; /** expected content of workdir, defaults to HEAD */
} git_checkout_opts;

#define GIT_CHECKOUT_OPTS_VERSION 1
#define GIT_CHECKOUT_OPTS_INIT {GIT_CHECKOUT_OPTS_VERSION}

/**
 * Updates files in the index and the working tree to match the content of
 * the commit pointed at by HEAD.
 *
 * @param repo repository to check out (must be non-bare)
 * @param opts specifies checkout options (may be NULL)
 * @return 0 on success, GIT_EORPHANEDHEAD when HEAD points to a non existing
 * branch, GIT_ERROR otherwise (use giterr_last for information
 * about the error)
 */
GIT_EXTERN(int) git_checkout_head(
	git_repository *repo,
	git_checkout_opts *opts);

/**
 * Updates files in the working tree to match the content of the index.
 *
 * @param repo repository into which to check out (must be non-bare)
 * @param index index to be checked out (or NULL to use repository index)
 * @param opts specifies checkout options (may be NULL)
 * @return 0 on success, GIT_ERROR otherwise (use giterr_last for information
 * about the error)
 */
GIT_EXTERN(int) git_checkout_index(
	git_repository *repo,
	git_index *index,
	git_checkout_opts *opts);

/**
 * Updates files in the index and working tree to match the content of the
 * tree pointed at by the treeish.
 *
 * @param repo repository to check out (must be non-bare)
 * @param treeish a commit, tag or tree which content will be used to update
 * the working directory
 * @param opts specifies checkout options (may be NULL)
 * @return 0 on success, GIT_ERROR otherwise (use giterr_last for information
 * about the error)
 */
GIT_EXTERN(int) git_checkout_tree(
	git_repository *repo,
	const git_object *treeish,
	git_checkout_opts *opts);

/** @} */
GIT_END_DECL
#endif
