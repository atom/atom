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
#include "strarray.h"

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
 * @param repo the associated repository
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
 * Get the remote's url for pushing
 *
 * @param remote the remote
 * @return a pointer to the url or NULL if no special url for pushing is set
 */
GIT_EXTERN(const char *) git_remote_pushurl(git_remote *remote);

/**
 * Set the remote's url
 *
 * Existing connections will not be updated.
 *
 * @param remote the remote
 * @param url the url to set
 * @return 0 or an error value
 */
GIT_EXTERN(int) git_remote_set_url(git_remote *remote, const char* url);

/**
 * Set the remote's url for pushing
 *
 * Existing connections will not be updated.
 *
 * @param remote the remote
 * @param url the url to set or NULL to clear the pushurl
 * @return 0 or an error value
 */
GIT_EXTERN(int) git_remote_set_pushurl(git_remote *remote, const char* url);

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
 * @param spec the new push refspec
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
 * If you a return a non-zero value from the callback, this will stop
 * looping over the refs.
 *
 * @param refs where to store the refs
 * @param remote the remote
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
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
 * @param progress_cb function to call with progress information.  Be aware that
 * this is called inline with network and indexing operations, so performance
 * may be affected.
 * @param progress_payload payload for the progress callback
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_download(
		git_remote *remote,
		git_transfer_progress_callback progress_cb,
		void *progress_payload);

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
 * Cancel the operation
 *
 * At certain points in its operation, the network code checks whether
 * the operation has been cancelled and if so stops the operation.
 */
GIT_EXTERN(void) git_remote_stop(git_remote *remote);

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
GIT_EXTERN(int) git_remote_update_tips(git_remote *remote);

/**
 * Return whether a string is a valid remote URL
 *
 * @param url the url to check
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

/**
 * Choose whether to check the server's certificate (applies to HTTPS only)
 *
 * @param remote the remote to configure
 * @param check whether to check the server's certificate (defaults to yes)
 */

GIT_EXTERN(void) git_remote_check_cert(git_remote *remote, int check);

/**
 * Argument to the completion callback which tells it which operation
 * finished.
 */
typedef enum git_remote_completion_type {
	GIT_REMOTE_COMPLETION_DOWNLOAD,
	GIT_REMOTE_COMPLETION_INDEXING,
	GIT_REMOTE_COMPLETION_ERROR,
} git_remote_completion_type;

/**
 * The callback settings structure
 *
 * Set the calbacks to be called by the remote.
 */
struct git_remote_callbacks {
	void (*progress)(const char *str, int len, void *data);
	int (*completion)(git_remote_completion_type type, void *data);
	int (*update_tips)(const char *refname, const git_oid *a, const git_oid *b, void *data);
	void *data;
};

/**
 * Set the callbacks for a remote
 *
 * Note that the remote keeps its own copy of the data and you need to
 * call this function again if you want to change the callbacks.
 *
 * @param remote the remote to configure
 * @param callbacks a pointer to the user's callback settings
 */
GIT_EXTERN(void) git_remote_set_callbacks(git_remote *remote, git_remote_callbacks *callbacks);

/**
 * Get the statistics structure that is filled in by the fetch operation.
 */
GIT_EXTERN(const git_transfer_progress *) git_remote_stats(git_remote *remote);

enum {
	GIT_REMOTE_DOWNLOAD_TAGS_UNSET,
	GIT_REMOTE_DOWNLOAD_TAGS_NONE,
	GIT_REMOTE_DOWNLOAD_TAGS_AUTO,
	GIT_REMOTE_DOWNLOAD_TAGS_ALL
};

/**
 * Retrieve the tag auto-follow setting
 *
 * @param remote the remote to query
 * @return the auto-follow setting
 */
GIT_EXTERN(int) git_remote_autotag(git_remote *remote);

/**
 * Set the tag auto-follow setting
 *
 * @param remote the remote to configure
 * @param value a GIT_REMOTE_DOWNLOAD_TAGS value
 */
GIT_EXTERN(void) git_remote_set_autotag(git_remote *remote, int value);

/**
 * Give the remote a new name
 *
 * All remote-tracking branches and configuration settings
 * for the remote are updated.
 *
 * @param remote the remote to rename
 * @param new_name the new name the remote should bear
 * @param callback Optional callback to notify the consumer of fetch refspecs
 * that haven't been automatically updated and need potential manual tweaking.
 * @param payload Additional data to pass to the callback
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_rename(
	git_remote *remote,
	const char *new_name,
	int (*callback)(const char *problematic_refspec, void *payload),
	void *payload);

/** @} */
GIT_END_DECL
#endif
