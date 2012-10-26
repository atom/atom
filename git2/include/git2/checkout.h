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
 * combination of these values OR'ed together.
 */
typedef enum {
	/** Checkout does not update any files in the working directory. */
	GIT_CHECKOUT_DEFAULT            = (1 << 0),

	/** When a file exists and is modified, replace it with new version. */
	GIT_CHECKOUT_OVERWRITE_MODIFIED = (1 << 1),

	/** When a file does not exist in the working directory, create it. */
	GIT_CHECKOUT_CREATE_MISSING     = (1 << 2),

	/** If an untracked file in found in the working dir, delete it. */
	GIT_CHECKOUT_REMOVE_UNTRACKED   = (1 << 3),
} git_checkout_strategy_t;

/**
 * Checkout options structure
 *
 * Use zeros to indicate default settings.
 */
typedef struct git_checkout_opts {
	unsigned int checkout_strategy; /** default: GIT_CHECKOUT_DEFAULT */
	int disable_filters; /** don't apply filters like CRLF conversion */
	int dir_mode;		 /** default is 0755 */
	int file_mode;		 /** default is 0644 or 0755 as dictated by blob */
	int file_open_flags; /** default is O_CREAT | O_TRUNC | O_WRONLY */

	/** Optional callback to notify the consumer of files that
	 * haven't be checked out because a modified version of them
	 * exist in the working directory.
	 *
	 * When provided, this callback will be invoked when the flag
	 * GIT_CHECKOUT_OVERWRITE_MODIFIED isn't part of the checkout strategy.
	 */
	int (* skipped_notify_cb)(
		const char *skipped_file,
		const git_oid *blob_oid,
		int file_mode,
		void *payload);
	void *notify_payload;

	/* Optional callback to notify the consumer of checkout progress. */
	void (* progress_cb)(
			const char *path,
			size_t completed_steps,
			size_t total_steps,
			void *payload);
	void *progress_payload;

	/** When not NULL, array of fnmatch patterns specifying
	 * which paths should be taken into account
	 */
	git_strarray paths; 
} git_checkout_opts;

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
 * @param repo repository to check out (must be non-bare)
 * @param opts specifies checkout options (may be NULL)
 * @return 0 on success, GIT_ERROR otherwise (use giterr_last for information
 * about the error)
 */
GIT_EXTERN(int) git_checkout_index(
	git_repository *repo,
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
	git_object *treeish,
	git_checkout_opts *opts);

/** @} */
GIT_END_DECL
#endif
