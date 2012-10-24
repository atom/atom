/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_remote_h__
#define INCLUDE_git_remote_h__

#include "common.h"
#include "repository.h"
#include "refspec.h"
#include "net.h"
#include "indexer.h"

/**
 * @file git2/remote.h
 * @brief Git remote management functions
 * @defgroup git_remote remote management functions
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/*
 * TODO: This functions still need to be implemented:
 * - _listcb/_foreach
 * - _add
 * - _rename
 * - _del (needs support from config)
 */

/**
 * Create a remote in memory
 *
 * Create a remote with the default refspecs in memory. You can use
 * this when you have a URL instead of a remote's name.
 *
 * @param out pointer to the new remote object
 * @param repo the associtated repository
 * @param name the remote's name
 * @param url the remote repository's URL
 * @param fetch the fetch refspec to use for this remote
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_new(git_remote **out, git_repository *repo, const char *name, const char *url, const char *fetch);

/**
 * Get the information for a particular remote
 *
 * @param out pointer to the new remote object
 * @param cfg the repository's configuration
 * @param name the remote's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_load(git_remote **out, git_repository *repo, const char *name);

/**
 * Save a remote to its repository's configuration
 *
 * @param remote the remote to save to config
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_save(const git_remote *remote);

/**
 * Get the remote's name
 *
 * @param remote the remote
 * @return a pointer to the name
 */
GIT_EXTERN(const char *) git_remote_name(git_remote *remote);

/**
 * Get the remote's url
 *
 * @param remote the remote
 * @return a pointer to the url
 */
GIT_EXTERN(const char *) git_remote_url(git_remote *remote);

/**
 * Set the remote's fetch refspec
 *
 * @param remote the remote
 * @apram spec the new fetch refspec
 * @return 0 or an error value
 */
GIT_EXTERN(int) git_remote_set_fetchspec(git_remote *remote, const char *spec);

/**
 * Get the fetch refspec
 *
 * @param remote the remote
 * @return a pointer to the fetch refspec or NULL if it doesn't exist
 */
GIT_EXTERN(const git_refspec *) git_remote_fetchspec(git_remote *remote);

/**
 * Set the remote's push refspec
 *
 * @param remote the remote
 * @apram spec the new push refspec
 * @return 0 or an error value
 */
GIT_EXTERN(int) git_remote_set_pushspec(git_remote *remote, const char *spec);

/**
 * Get the push refspec
 *
 * @param remote the remote
 * @return a pointer to the push refspec or NULL if it doesn't exist
 */

GIT_EXTERN(const git_refspec *) git_remote_pushspec(git_remote *remote);

/**
 * Open a connection to a remote
 *
 * The transport is selected based on the URL. The direction argument
 * is due to a limitation of the git protocol (over TCP or SSH) which
 * starts up a specific binary which can only do the one or the other.
 *
 * @param remote the remote to connect to
 * @param direction whether you want to receive or send data
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_connect(git_remote *remote, int direction);

/**
 * Get a list of refs at the remote
 *
 * The remote (or more exactly its transport) must be connected. The
 * memory belongs to the remote.
 *
 * @param refs where to store the refs
 * @param remote the remote
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_ls(git_remote *remote, git_headlist_cb list_cb, void *payload);

/**
 * Download the packfile
 *
 * Negotiate what objects should be downloaded and download the
 * packfile with those objects. The packfile is downloaded with a
 * temporary filename, as it's final name is not known yet. If there
 * was no packfile needed (all the objects were available locally),
 * filename will be NULL and the function will return success.
 *
 * @param remote the remote to download from
 * @param filename where to store the temproray filename
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_download(git_remote *remote, git_off_t *bytes, git_indexer_stats *stats);

/**
 * Check whether the remote is connected
 *
 * Check whether the remote's underlying transport is connected to the
 * remote host.
 *
 * @return 1 if it's connected, 0 otherwise.
 */
GIT_EXTERN(int) git_remote_connected(git_remote *remote);

/**
 * Disconnect from the remote
 *
 * Close the connection to the remote and free the underlying
 * transport.
 *
 * @param remote the remote to disconnect from
 */
GIT_EXTERN(void) git_remote_disconnect(git_remote *remote);

/**
 * Free the memory associated with a remote
 *
 * This also disconnects from the remote, if the connection
 * has not been closed yet (using git_remote_disconnect).
 *
 * @param remote the remote to free
 */
GIT_EXTERN(void) git_remote_free(git_remote *remote);

/**
 * Update the tips to the new state
 *
 * @param remote the remote to update
 * @param cb callback to run on each ref update. 'a' is the old value, 'b' is then new value
 */
GIT_EXTERN(int) git_remote_update_tips(git_remote *remote, int (*cb)(const char *refname, const git_oid *a, const git_oid *b));

/**
 * Return whether a string is a valid remote URL
 *
 * @param tranport the url to check
 * @param 1 if the url is valid, 0 otherwise
 */
GIT_EXTERN(int) git_remote_valid_url(const char *url);

/**
 * Return whether the passed URL is supported by this version of the library.
 *
 * @param url the url to check
 * @return 1 if the url is supported, 0 otherwise
*/
GIT_EXTERN(int) git_remote_supported_url(const char* url);

/**
 * Get a list of the configured remotes for a repo
 *
 * The string array must be freed by the user.
 *
 * @param remotes_list a string array with the names of the remotes
 * @param repo the repository to query
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_list(git_strarray *remotes_list, git_repository *repo);

/**
 * Add a remote with the default fetch refspec to the repository's configuration
 *
 * @param out the resulting remote
 * @param repo the repository in which to create the remote
 * @param name the remote's name
 * @param url the remote's url
 */
GIT_EXTERN(int) git_remote_add(git_remote **out, git_repository *repo, const char *name, const char *url);

/** @} */
GIT_END_DECL
#endif
