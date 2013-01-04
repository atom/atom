/*
 * Copyright (C) 2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_checkout_h__
#define INCLUDE_git_checkout_h__

#include "common.h"
#include "types.h"
#include "indexer.h"
#include "strarray.h"

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
 * These flags control what checkout does with files.  Pass in a
 * combination of these values OR'ed together.  If you just pass zero
 * (i.e. no flags), then you are effectively doing a "dry run" where no
 * files will be modified.
 *
 * Checkout groups the working directory content into 3 classes of files:
 * (1) files that don't need a change, and files that do need a change
 * that either (2) we are allowed to modifed or (3) we are not.  The flags
 * you pass in will decide which files we are allowed to modify.
 *
 * By default, checkout is not allowed to modify any files.  Anything
 * needing a change would be considered a conflict.
 *
 * GIT_CHECKOUT_UPDATE_UNMODIFIED means that checkout is allowed to update
 * any file where the working directory content matches the HEAD
 * (e.g. either the files match or the file is absent in both places).
 *
 * GIT_CHECKOUT_UPDATE_MISSING means checkout can create a missing file
 * that exists in the index and does not exist in the working directory.
 * This is usually desirable for initial checkout, etc.  Technically, the
 * missing file differs from the HEAD, which is why this is separate.
 *
 * GIT_CHECKOUT_UPDATE_MODIFIED means checkout is allowed to update files
 * where the working directory does not match the HEAD so long as the file
 * actually exists in the HEAD.  This option implies UPDATE_UNMODIFIED.
 *
 * GIT_CHECKOUT_UPDATE_UNTRACKED means checkout is allowed to update files
 * even if there is a working directory version that does not exist in the
 * HEAD (i.e. the file was independently created in the workdir).  This
 * implies UPDATE_UNMODIFIED | UPDATE_MISSING (but *not* UPDATE_MODIFIED).
 *
 *
 * On top of these three basic strategies, there are some modifiers
 * options that can be applied:
 *
 * If any files need update but are disallowed by the strategy, normally
 * checkout calls the conflict callback (if given) and then aborts.
 * GIT_CHECKOUT_ALLOW_CONFLICTS means it is okay to update the files that
 * are allowed by the strategy even if there are conflicts.  The conflict
 * callbacks are still made, but non-conflicting files will be updated.
 *
 * Any unmerged entries in the index are automatically considered conflicts.
 * If you want to proceed anyhow and just skip unmerged entries, you can use
 * GIT_CHECKOUT_SKIP_UNMERGED which is less dangerous than just allowing all
 * conflicts.  Alternatively, use GIT_CHECKOUT_USE_OURS to proceed and
 * checkout the stage 2 ("ours") version.  GIT_CHECKOUT_USE_THEIRS means to
 * proceed and use the stage 3 ("theirs") version.
 *
 * GIT_CHECKOUT_UPDATE_ONLY means that update is not allowed to create new
 * files or delete old ones, only update existing content.  With this
 * flag, files that needs to be created or deleted are not conflicts -
 * they are just skipped.  This also skips typechanges to existing files
 * (because the old would have to be removed).
 *
 * GIT_CHECKOUT_REMOVE_UNTRACKED means that files in the working directory
 * that are untracked (and not ignored) will be removed altogether.  These
 * untracked files (that do not shadow index entries) are not considered
 * conflicts and would normally be ignored.
 *
 *
 * Checkout is "semi-atomic" as in it will go through the work to be done
 * before making any changes and if may decide to abort if there are
 * conflicts, or you can use the conflict callback to explicitly abort the
 * action before any updates are made.  Despite this, if a second process
 * is modifying the filesystem while checkout is running, it can't
 * guarantee that the choices is makes while initially examining the
 * filesystem are still going to be correct as it applies them.
 */
typedef enum {
	GIT_CHECKOUT_DEFAULT = 0, /** default is a dry run, no actual updates */

	/** Allow update of entries where working dir matches HEAD. */
	GIT_CHECKOUT_UPDATE_UNMODIFIED = (1u << 0),

	/** Allow update of entries where working dir does not have file. */
	GIT_CHECKOUT_UPDATE_MISSING = (1u << 1),

	/** Allow safe updates that cannot overwrite uncommited data */
	GIT_CHECKOUT_SAFE =
		(GIT_CHECKOUT_UPDATE_UNMODIFIED | GIT_CHECKOUT_UPDATE_MISSING),

	/** Allow update of entries in working dir that are modified from HEAD. */
	GIT_CHECKOUT_UPDATE_MODIFIED = (1u << 2),

	/** Update existing untracked files that are now present in the index. */
	GIT_CHECKOUT_UPDATE_UNTRACKED = (1u << 3),

	/** Allow all updates to force working directory to look like index */
	GIT_CHECKOUT_FORCE =
		(GIT_CHECKOUT_SAFE | GIT_CHECKOUT_UPDATE_MODIFIED | GIT_CHECKOUT_UPDATE_UNTRACKED),

	/** Allow checkout to make updates even if conflicts are found */
	GIT_CHECKOUT_ALLOW_CONFLICTS = (1u << 4),

	/** Remove untracked files not in index (that are not ignored) */
	GIT_CHECKOUT_REMOVE_UNTRACKED = (1u << 5),

	/** Only update existing files, don't create new ones */
	GIT_CHECKOUT_UPDATE_ONLY = (1u << 6),

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
 * Checkout options structure
 *
 * Use zeros to indicate default settings.
 * This needs to be initialized with the `GIT_CHECKOUT_OPTS_INIT` macro:
 *
 *		git_checkout_opts opts = GIT_CHECKOUT_OPTS_INIT;
 */
typedef struct git_checkout_opts {
	unsigned int version;
	unsigned int checkout_strategy; /** default will be a dry run */

	int disable_filters; /** don't apply filters like CRLF conversion */
	int dir_mode;		 /** default is 0755 */
	int file_mode;		 /** default is 0644 or 0755 as dictated by blob */
	int file_open_flags; /** default is O_CREAT | O_TRUNC | O_WRONLY */

	/** Optional callback made on files where the index differs from the
	 *  working directory but the rules do not allow update.  Return a
	 *  non-zero value to abort the checkout.  All such callbacks will be
	 *  made before any changes are made to the working directory.
	 */
	int (*conflict_cb)(
		const char *conflicting_path,
		const git_oid *index_oid,
		unsigned int index_mode,
		unsigned int wd_mode,
		void *payload);
	void *conflict_payload;

	/* Optional callback to notify the consumer of checkout progress. */
	void (*progress_cb)(
		const char *path,
		size_t completed_steps,
		size_t total_steps,
		void *payload);
	void *progress_payload;

	/** When not zeroed out, array of fnmatch patterns specifying which
	 *  paths should be taken into account, otherwise all files.
	 */
	git_strarray paths;
} git_checkout_opts;

#define GIT_CHECKOUT_OPTS_VERSION 1
#define GIT_CHECKOUT_OPTS_INIT {GIT_CHECKOUT_OPTS_VERSION}

/**
 * Updates files in the index and the working tree to match the content of the
 * commit pointed at by HEAD.
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
