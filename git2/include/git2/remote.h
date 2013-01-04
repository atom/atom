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
#include "transport.h"

/**
 * @file git2/remote.h
 * @brief Git remote management functions
 * @defgroup git_remote remote management functions
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

typedef int (*git_remote_rename_problem_cb)(const char *problematic_refspec, void *payload);
/*
 * TODO: This functions still need to be implemented:
 * - _listcb/_foreach
 * - _add
 * - _rename
 * - _del (needs support from config)
 */

/**
 * Add a remote with the default fetch refspec to the repository's configuration.  This
 * calls git_remote_save before returning.
 *
 * @param out the resulting remote
 * @param repo the repository in which to create the remote
 * @param name the remote's name
 * @param url the remote's url
 * @return 0, GIT_EINVALIDSPEC, GIT_EEXISTS or an error code
 */
GIT_EXTERN(int) git_remote_create(
		git_remote **out,
		git_repository *repo,
		const char *name,
		const char *url);

/**
 * Create a remote in memory
 *
 * Create a remote with the given refspec in memory. You can use
 * this when you have a URL instead of a remote's name.  Note that in-memory
 * remotes cannot be converted to persisted remotes.
 *
 * The name, when provided, will be checked for validity.
 * See `git_tag_create()` for rules about valid names.
 *
 * @param out pointer to the new remote object
 * @param repo the associated repository. May be NULL for a "dangling" remote.
 * @param fetch the fetch refspec to use for this remote. May be NULL for defaults.
 * @param url the remote repository's URL
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_create_inmemory(
		git_remote **out,
		git_repository *repo,
		const char *fetch,
		const char *url);

/**
 * Sets the owning repository for the remote.  This is only allowed on
 * dangling remotes.
 *
 * @param remote the remote to configure
 * @param repo the repository that will own the remote
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_set_repository(git_remote *remote, git_repository *repo);

/**
 * Get the information for a particular remote
 *
 * The name will be checked for validity.
 * See `git_tag_create()` for rules about valid names.
 *
 * @param out pointer to the new remote object
 * @param repo the associated repository
 * @param name the remote's name
 * @return 0, GIT_ENOTFOUND, GIT_EINVALIDSPEC or an error code
 */
GIT_EXTERN(int) git_remote_load(git_remote **out, git_repository *repo, const char *name);

/**
 * Save a remote to its repository's configuration
 *
 * One can't save a in-memory remote. Doing so will
 * result in a GIT_EINVALIDSPEC being returned.
 *
 * @param remote the remote to save to config
 * @return 0, GIT_EINVALIDSPEC or an error code
 */
GIT_EXTERN(int) git_remote_save(const git_remote *remote);

/**
 * Get the remote's name
 *
 * @param remote the remote
 * @return a pointer to the name or NULL for in-memory remotes
 */
GIT_EXTERN(const char *) git_remote_name(const git_remote *remote);

/**
 * Get the remote's url
 *
 * @param remote the remote
 * @return a pointer to the url
 */
GIT_EXTERN(const char *) git_remote_url(const git_remote *remote);

/**
 * Get the remote's url for pushing
 *
 * @param remote the remote
 * @return a pointer to the url or NULL if no special url for pushing is set
 */
GIT_EXTERN(const char *) git_remote_pushurl(const git_remote *remote);

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
GIT_EXTERN(const git_refspec *) git_remote_fetchspec(const git_remote *remote);

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

GIT_EXTERN(const git_refspec *) git_remote_pushspec(const git_remote *remote);

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
GIT_EXTERN(int) git_remote_connect(git_remote *remote, git_direction direction);

/**
 * Get a list of refs at the remote
 *
 * The remote (or more exactly its transport) must be connected. The
 * memory belongs to the remote.
 *
 * If you a return a non-zero value from the callback, this will stop
 * looping over the refs.
 *
 * @param remote the remote
 * @param list_cb function to call with each ref discovered at the remote
 * @param payload additional data to pass to the callback
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
		void *payload);

/**
 * Check whether the remote is connected
 *
 * Check whether the remote's underlying transport is connected to the
 * remote host.
 *
 * @param remote the remote
 * @return 1 if it's connected, 0 otherwise.
 */
GIT_EXTERN(int) git_remote_connected(git_remote *remote);

/**
 * Cancel the operation
 *
 * At certain points in its operation, the network code checks whether
 * the operation has been cancelled and if so stops the operation.
 *
 * @param remote the remote
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
 * @return 0 or an error code
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
 * @param out a string array which receives the names of the remotes
 * @param repo the repository to query
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_list(git_strarray *out, git_repository *repo);

/**
 * Choose whether to check the server's certificate (applies to HTTPS only)
 *
 * @param remote the remote to configure
 * @param check whether to check the server's certificate (defaults to yes)
 */
GIT_EXTERN(void) git_remote_check_cert(git_remote *remote, int check);

/**
 * Set a credentials acquisition callback for this remote. If the remote is
 * not available for anonymous access, then you must set this callback in order
 * to provide credentials to the transport at the time of authentication
 * failure so that retry can be performed.
 *
 * @param remote the remote to configure
 * @param cred_acquire_cb The credentials acquisition callback to use (defaults
 * to NULL)
 */
GIT_EXTERN(void) git_remote_set_cred_acquire_cb(
	git_remote *remote,
	git_cred_acquire_cb cred_acquire_cb,
	void *payload);

/**
 * Sets a custom transport for the remote. The caller can use this function
 * to bypass the automatic discovery of a transport by URL scheme (i.e.
 * http://, https://, git://) and supply their own transport to be used
 * instead. After providing the transport to a remote using this function,
 * the transport object belongs exclusively to that remote, and the remote will
 * free it when it is freed with git_remote_free.
 *
 * @param remote the remote to configure
 * @param transport the transport object for the remote to use
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_set_transport(
	git_remote *remote,
	git_transport *transport);

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
	unsigned int version;
	void (*progress)(const char *str, int len, void *data);
	int (*completion)(git_remote_completion_type type, void *data);
	int (*update_tips)(const char *refname, const git_oid *a, const git_oid *b, void *data);
	void *payload;
};

#define GIT_REMOTE_CALLBACKS_VERSION 1
#define GIT_REMOTE_CALLBACKS_INIT {GIT_REMOTE_CALLBACKS_VERSION}

/**
 * Set the callbacks for a remote
 *
 * Note that the remote keeps its own copy of the data and you need to
 * call this function again if you want to change the callbacks.
 *
 * @param remote the remote to configure
 * @param callbacks a pointer to the user's callback settings
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_remote_set_callbacks(git_remote *remote, git_remote_callbacks *callbacks);

/**
 * Get the statistics structure that is filled in by the fetch operation.
 */
GIT_EXTERN(const git_transfer_progress *) git_remote_stats(git_remote *remote);

typedef enum {
	GIT_REMOTE_DOWNLOAD_TAGS_UNSET,
	GIT_REMOTE_DOWNLOAD_TAGS_NONE,
	GIT_REMOTE_DOWNLOAD_TAGS_AUTO,
	GIT_REMOTE_DOWNLOAD_TAGS_ALL
} git_remote_autotag_option_t;

/**
 * Retrieve the tag auto-follow setting
 *
 * @param remote the remote to query
 * @return the auto-follow setting
 */
GIT_EXTERN(git_remote_autotag_option_t) git_remote_autotag(git_remote *remote);

/**
 * Set the tag auto-follow setting
 *
 * @param remote the remote to configure
 * @param value a GIT_REMOTE_DOWNLOAD_TAGS value
 */
GIT_EXTERN(void) git_remote_set_autotag(
	git_remote *remote,
	git_remote_autotag_option_t value);

/**
 * Give the remote a new name
 *
 * All remote-tracking branches and configuration settings
 * for the remote are updated.
 *
 * The new name will be checked for validity.
 * See `git_tag_create()` for rules about valid names.
 *
 * A temporary in-memory remote cannot be given a name with this method.
 *
 * @param remote the remote to rename
 * @param new_name the new name the remote should bear
 * @param callback Optional callback to notify the consumer of fetch refspecs
 * that haven't been automatically updated and need potential manual tweaking.
 * @param payload Additional data to pass to the callback
 * @return 0, GIT_EINVALIDSPEC, GIT_EEXISTS or an error code
 */
GIT_EXTERN(int) git_remote_rename(
	git_remote *remote,
	const char *new_name,
	git_remote_rename_problem_cb callback,
	void *payload);

/**
 * Retrieve the update FETCH_HEAD setting.
 *
 * @param remote the remote to query
 * @return the update FETCH_HEAD setting
 */
GIT_EXTERN(int) git_remote_update_fetchhead(git_remote *remote);

/**
 * Sets the update FETCH_HEAD setting.  By default, FETCH_HEAD will be
 * updated on every fetch.  Set to 0 to disable.
 *
 * @param remote the remote to configure
 * @param value 0 to disable updating FETCH_HEAD
 */
GIT_EXTERN(void) git_remote_set_update_fetchhead(git_remote *remote, int value);

/** @} */
GIT_END_DECL
#endif
