/*
 * Copyright (C) 2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_clone_h__
#define INCLUDE_git_clone_h__

#include "common.h"
#include "types.h"
#include "indexer.h"
#include "checkout.h"
#include "remote.h"


/**
 * @file git2/clone.h
 * @brief Git cloning routines
 * @defgroup git_clone Git cloning routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Clone options structure
 *
 * Use zeros to indicate default settings.  It's easiest to use the
 * `GIT_CLONE_OPTIONS_INIT` macro:
 *
 *		git_clone_options opts = GIT_CLONE_OPTIONS_INIT;
 *
 * - `checkout_opts` is options for the checkout step.  To disable checkout,
 *   set the `checkout_strategy` to GIT_CHECKOUT_DEFAULT.
 * - `bare` should be set to zero to create a standard repo, non-zero for
 *   a bare repo
 * - `fetch_progress_cb` is optional callback for fetch progress. Be aware that
 *   this is called inline with network and indexing operations, so performance
 *   may be affected.
 * - `fetch_progress_payload` is payload for fetch_progress_cb
 *
 *   ** "origin" remote options: **
 * - `remote_name` is the name given to the "origin" remote.  The default is
 *   "origin".
 * - `pushurl` is a URL to be used for pushing.  NULL means use the fetch url.
 * - `fetch_spec` is the fetch specification to be used for fetching.  NULL
 *   results in the same behavior as GIT_REMOTE_DEFAULT_FETCH.
 * - `push_spec` is the fetch specification to be used for pushing.  NULL means
 *   use the same spec as for fetching.
 * - `cred_acquire_cb` is a callback to be used if credentials are required
 *   during the initial fetch.
 * - `cred_acquire_payload` is the payload for the above callback.
 * - `transport` is a custom transport to be used for the initial fetch.  NULL
 *   means use the transport autodetected from the URL.
 * - `remote_callbacks` may be used to specify custom progress callbacks for
 *   the origin remote before the fetch is initiated.
 * - `remote_autotag` may be used to specify the autotag setting before the
 *   initial fetch.
 */

typedef struct git_clone_options {
	unsigned int version;

	git_checkout_opts checkout_opts;
	int bare;
	git_transfer_progress_callback fetch_progress_cb;
	void *fetch_progress_payload;

	const char *remote_name;
	const char *pushurl;
	const char *fetch_spec;
	const char *push_spec;
	git_cred_acquire_cb cred_acquire_cb;
	void *cred_acquire_payload;
	git_transport *transport;
	git_remote_callbacks *remote_callbacks;
	git_remote_autotag_option_t remote_autotag;
} git_clone_options;

#define GIT_CLONE_OPTIONS_VERSION 1
#define GIT_CLONE_OPTIONS_INIT {GIT_CLONE_OPTIONS_VERSION, {GIT_CHECKOUT_OPTS_VERSION, GIT_CHECKOUT_SAFE}}

/**
 * Clone a remote repository, and checkout the branch pointed to by the remote
 * HEAD.
 *
 * @param out pointer that will receive the resulting repository object
 * @param origin_remote a remote which will act as the initial fetch source
 * @param local_path local directory to clone to
 * @param options configuration options for the clone.  If NULL, the function
 * works as though GIT_OPTIONS_INIT were passed.
 * @return 0 on success, GIT_ERROR otherwise (use giterr_last for information
 * about the error)
 */
GIT_EXTERN(int) git_clone(
		git_repository **out,
		const char *url,
		const char *local_path,
		const git_clone_options *options);

/** @} */
GIT_END_DECL
#endif
