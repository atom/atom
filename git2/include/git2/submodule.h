/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_submodule_h__
#define INCLUDE_git_submodule_h__

#include "common.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/submodule.h
 * @brief Git submodule management utilities
 * @defgroup git_submodule Git submodule management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Opaque structure representing a submodule.
 *
 * Submodule support in libgit2 builds a list of known submodules and keeps
 * it in the repository.  The list is built from the .gitmodules file, the
 * .git/config file, the index, and the HEAD tree.  Items in the working
 * directory that look like submodules (i.e. a git repo) but are not
 * mentioned in those places won't be tracked.
 */
typedef struct git_submodule git_submodule;

/**
 * Values that could be specified for the update rule of a submodule.
 *
 * Use the DEFAULT value if you have altered the update value via
 * `git_submodule_set_update()` and wish to reset to the original default.
 */
typedef enum {
	GIT_SUBMODULE_UPDATE_DEFAULT = -1,
	GIT_SUBMODULE_UPDATE_CHECKOUT = 0,
	GIT_SUBMODULE_UPDATE_REBASE = 1,
	GIT_SUBMODULE_UPDATE_MERGE = 2,
	GIT_SUBMODULE_UPDATE_NONE = 3
} git_submodule_update_t;

/**
 * Values that could be specified for how closely to examine the
 * working directory when getting submodule status.
 *
 * Use the DEFUALT value if you have altered the ignore value via
 * `git_submodule_set_ignore()` and wish to reset to the original value.
 */
typedef enum {
	GIT_SUBMODULE_IGNORE_DEFAULT = -1,  /* reset to default */
	GIT_SUBMODULE_IGNORE_NONE = 0,      /* any change or untracked == dirty */
	GIT_SUBMODULE_IGNORE_UNTRACKED = 1, /* dirty if tracked files change */
	GIT_SUBMODULE_IGNORE_DIRTY = 2,     /* only dirty if HEAD moved */
	GIT_SUBMODULE_IGNORE_ALL = 3        /* never dirty */
} git_submodule_ignore_t;

/**
 * Return codes for submodule status.
 *
 * A combination of these flags will be returned to describe the status of a
 * submodule.  Depending on the "ignore" property of the submodule, some of
 * the flags may never be returned because they indicate changes that are
 * supposed to be ignored.
 *
 * Submodule info is contained in 4 places: the HEAD tree, the index, config
 * files (both .git/config and .gitmodules), and the working directory.  Any
 * or all of those places might be missing information about the submodule
 * depending on what state the repo is in.  We consider all four places to
 * build the combination of status flags.
 *
 * There are four values that are not really status, but give basic info
 * about what sources of submodule data are available.  These will be
 * returned even if ignore is set to "ALL".
 *
 * * IN_HEAD   - superproject head contains submodule
 * * IN_INDEX  - superproject index contains submodule
 * * IN_CONFIG - superproject gitmodules has submodule
 * * IN_WD     - superproject workdir has submodule
 *
 * The following values will be returned so long as ignore is not "ALL".
 *
 * * INDEX_ADDED       - in index, not in head
 * * INDEX_DELETED     - in head, not in index
 * * INDEX_MODIFIED    - index and head don't match
 * * WD_UNINITIALIZED  - workdir contains empty directory
 * * WD_ADDED          - in workdir, not index
 * * WD_DELETED        - in index, not workdir
 * * WD_MODIFIED       - index and workdir head don't match
 *
 * The following can only be returned if ignore is "NONE" or "UNTRACKED".
 *
 * * WD_INDEX_MODIFIED - submodule workdir index is dirty
 * * WD_WD_MODIFIED    - submodule workdir has modified files
 *
 * Lastly, the following will only be returned for ignore "NONE".
 *
 * * WD_UNTRACKED      - wd contains untracked files
 */
typedef enum {
	 GIT_SUBMODULE_STATUS_IN_HEAD           = (1u << 0),
	 GIT_SUBMODULE_STATUS_IN_INDEX          = (1u << 1),
	 GIT_SUBMODULE_STATUS_IN_CONFIG         = (1u << 2),
	 GIT_SUBMODULE_STATUS_IN_WD             = (1u << 3),
	 GIT_SUBMODULE_STATUS_INDEX_ADDED       = (1u << 4),
	 GIT_SUBMODULE_STATUS_INDEX_DELETED     = (1u << 5),
	 GIT_SUBMODULE_STATUS_INDEX_MODIFIED    = (1u << 6),
	 GIT_SUBMODULE_STATUS_WD_UNINITIALIZED  = (1u << 7),
	 GIT_SUBMODULE_STATUS_WD_ADDED          = (1u << 8),
	 GIT_SUBMODULE_STATUS_WD_DELETED        = (1u << 9),
	 GIT_SUBMODULE_STATUS_WD_MODIFIED       = (1u << 10),
	 GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED = (1u << 11),
	 GIT_SUBMODULE_STATUS_WD_WD_MODIFIED    = (1u << 12),
	 GIT_SUBMODULE_STATUS_WD_UNTRACKED      = (1u << 13),
} git_submodule_status_t;

#define GIT_SUBMODULE_STATUS_IS_UNMODIFIED(S) \
	(((S) & ~(GIT_SUBMODULE_STATUS_IN_HEAD | \
	GIT_SUBMODULE_STATUS_IN_INDEX | \
	GIT_SUBMODULE_STATUS_IN_CONFIG | \
	GIT_SUBMODULE_STATUS_IN_WD)) == 0)

#define GIT_SUBMODULE_STATUS_IS_WD_DIRTY(S) \
	(((S) & (GIT_SUBMODULE_STATUS_WD_INDEX_MODIFIED | \
	GIT_SUBMODULE_STATUS_WD_WD_MODIFIED | \
	GIT_SUBMODULE_STATUS_WD_UNTRACKED)) != 0)

/**
 * Lookup submodule information by name or path.
 *
 * Given either the submodule name or path (they are usually the same), this
 * returns a structure describing the submodule.
 *
 * There are two expected error scenarios:
 *
 * - The submodule is not mentioned in the HEAD, the index, and the config,
 *   but does "exist" in the working directory (i.e. there is a subdirectory
 *   that is a valid self-contained git repo).  In this case, this function
 *   returns GIT_EEXISTS to indicate the the submodule exists but not in a
 *   state where a git_submodule can be instantiated.
 * - The submodule is not mentioned in the HEAD, index, or config and the
 *   working directory doesn't contain a value git repo at that path.
 *   There may or may not be anything else at that path, but nothing that
 *   looks like a submodule.  In this case, this returns GIT_ENOTFOUND.
 *
 * The submodule object is owned by the containing repo and will be freed
 * when the repo is freed.  The caller need not free the submodule.
 *
 * @param submodule Pointer to submodule description object pointer..
 * @param repo The repository.
 * @param name The name of the submodule.  Trailing slashes will be ignored.
 * @return 0 on success, GIT_ENOTFOUND if submodule does not exist,
 *         GIT_EEXISTS if submodule exists in working directory only, -1 on
 *         other errors.
 */
GIT_EXTERN(int) git_submodule_lookup(
	git_submodule **submodule,
	git_repository *repo,
	const char *name);

/**
 * Iterate over all tracked submodules of a repository.
 *
 * See the note on `git_submodule` above.  This iterates over the tracked
 * submodules as decribed therein.
 *
 * If you are concerned about items in the working directory that look like
 * submodules but are not tracked, the diff API will generate a diff record
 * for workdir items that look like submodules but are not tracked, showing
 * them as added in the workdir.  Also, the status API will treat the entire
 * subdirectory of a contained git repo as a single GIT_STATUS_WT_NEW item.
 *
 * @param repo The repository
 * @param callback Function to be called with the name of each submodule.
 *        Return a non-zero value to terminate the iteration.
 * @param payload Extra data to pass to callback
 * @return 0 on success, -1 on error, or non-zero return value of callback
 */
GIT_EXTERN(int) git_submodule_foreach(
	git_repository *repo,
	int (*callback)(git_submodule *sm, const char *name, void *payload),
	void *payload);

/**
 * Set up a new git submodule for checkout.
 *
 * This does "git submodule add" up to the fetch and checkout of the
 * submodule contents.  It preps a new submodule, creates an entry in
 * .gitmodules and creates an empty initialized repository either at the
 * given path in the working directory or in .git/modules with a gitlink
 * from the working directory to the new repo.
 *
 * To fully emulate "git submodule add" call this function, then open the
 * submodule repo and perform the clone step as needed.  Lastly, call
 * `git_submodule_add_finalize()` to wrap up adding the new submodule and
 * .gitmodules to the index to be ready to commit.
 *
 * @param submodule The newly created submodule ready to open for clone
 * @param repo Superproject repository to contain the new submodule
 * @param url URL for the submodules remote
 * @param path Path at which the submodule should be created
 * @param use_gitlink Should workdir contain a gitlink to the repo in
 *        .git/modules vs. repo directly in workdir.
 * @return 0 on success, GIT_EEXISTS if submodule already exists,
 *         -1 on other errors.
 */
GIT_EXTERN(int) git_submodule_add_setup(
	git_submodule **submodule,
	git_repository *repo,
	const char *url,
	const char *path,
	int use_gitlink);

/**
 * Resolve the setup of a new git submodule.
 *
 * This should be called on a submodule once you have called add setup
 * and done the clone of the submodule.  This adds the .gitmodules file
 * and the newly cloned submodule to the index to be ready to be committed
 * (but doesn't actually do the commit).
 *
 * @param submodule The submodule to finish adding.
 */
GIT_EXTERN(int) git_submodule_add_finalize(git_submodule *submodule);

/**
 * Add current submodule HEAD commit to index of superproject.
 *
 * @param submodule The submodule to add to the index
 * @param write_index Boolean if this should immediately write the index
 *            file.  If you pass this as false, you will have to get the
 *            git_index and explicitly call `git_index_write()` on it to
 *            save the change.
 * @return 0 on success, <0 on failure
 */
GIT_EXTERN(int) git_submodule_add_to_index(
	git_submodule *submodule,
	int write_index);

/**
 * Write submodule settings to .gitmodules file.
 *
 * This commits any in-memory changes to the submodule to the gitmodules
 * file on disk.  You may also be interested in `git_submodule_init()` which
 * writes submodule info to ".git/config" (which is better for local changes
 * to submodule settings) and/or `git_submodule_sync()` which writes
 * settings about remotes to the actual submodule repository.
 *
 * @param submodule The submodule to write.
 * @return 0 on success, <0 on failure.
 */
GIT_EXTERN(int) git_submodule_save(git_submodule *submodule);

/**
 * Get the containing repository for a submodule.
 *
 * This returns a pointer to the repository that contains the submodule.
 * This is a just a reference to the repository that was passed to the
 * original `git_submodule_lookup()` call, so if that repository has been
 * freed, then this may be a dangling reference.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to `git_repository`
 */
GIT_EXTERN(git_repository *) git_submodule_owner(git_submodule *submodule);

/**
 * Get the name of submodule.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to the submodule name
 */
GIT_EXTERN(const char *) git_submodule_name(git_submodule *submodule);

/**
 * Get the path to the submodule.
 *
 * The path is almost always the same as the submodule name, but the
 * two are actually not required to match.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to the submodule path
 */
GIT_EXTERN(const char *) git_submodule_path(git_submodule *submodule);

/**
 * Get the URL for the submodule.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to the submodule url
 */
GIT_EXTERN(const char *) git_submodule_url(git_submodule *submodule);

/**
 * Set the URL for the submodule.
 *
 * This sets the URL in memory for the submodule. This will be used for
 * any following submodule actions while this submodule data is in memory.
 *
 * After calling this, you may wish to call `git_submodule_save()` to write
 * the changes back to the ".gitmodules" file and `git_submodule_sync()` to
 * write the changes to the checked out submodule repository.
 *
 * @param submodule Pointer to the submodule object
 * @param url URL that should be used for the submodule
 * @return 0 on success, <0 on failure
 */
GIT_EXTERN(int) git_submodule_set_url(git_submodule *submodule, const char *url);

/**
 * Get the OID for the submodule in the index.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to git_oid or NULL if submodule is not in index.
 */
GIT_EXTERN(const git_oid *) git_submodule_index_id(git_submodule *submodule);

/**
 * Get the OID for the submodule in the current HEAD tree.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to git_oid or NULL if submodule is not in the HEAD.
 */
GIT_EXTERN(const git_oid *) git_submodule_head_id(git_submodule *submodule);

/**
 * Get the OID for the submodule in the current working directory.
 *
 * This returns the OID that corresponds to looking up 'HEAD' in the checked
 * out submodule.  If there are pending changes in the index or anything
 * else, this won't notice that.  You should call `git_submodule_status()`
 * for a more complete picture about the state of the working directory.
 *
 * @param submodule Pointer to submodule object
 * @return Pointer to git_oid or NULL if submodule is not checked out.
 */
GIT_EXTERN(const git_oid *) git_submodule_wd_id(git_submodule *submodule);

/**
 * Get the ignore rule for the submodule.
 *
 * There are four ignore values:
 *
 *  - **GIT_SUBMODULE_IGNORE_NONE** will consider any change to the contents
 *    of the submodule from a clean checkout to be dirty, including the
 *    addition of untracked files.  This is the default if unspecified.
 *  - **GIT_SUBMODULE_IGNORE_UNTRACKED** examines the contents of the
 *    working tree (i.e. call `git_status_foreach()` on the submodule) but
 *    UNTRACKED files will not count as making the submodule dirty.
 *  - **GIT_SUBMODULE_IGNORE_DIRTY** means to only check if the HEAD of the
 *    submodule has moved for status.  This is fast since it does not need to
 *    scan the working tree of the submodule at all.
 *  - **GIT_SUBMODULE_IGNORE_ALL** means not to open the submodule repo.
 *    The working directory will be consider clean so long as there is a
 *    checked out version present.
 */
GIT_EXTERN(git_submodule_ignore_t) git_submodule_ignore(
	git_submodule *submodule);

/**
 * Set the ignore rule for the submodule.
 *
 * This sets the ignore rule in memory for the submodule.  This will be used
 * for any following actions (such as `git_submodule_status()`) while the
 * submodule is in memory.  You should call `git_submodule_save()` if you
 * want to persist the new ignore role.
 *
 * Calling this again with GIT_SUBMODULE_IGNORE_DEFAULT or calling
 * `git_submodule_reload()` will revert the rule to the value that was in the
 * original config.
 *
 * @return old value for ignore
 */
GIT_EXTERN(git_submodule_ignore_t) git_submodule_set_ignore(
	git_submodule *submodule,
	git_submodule_ignore_t ignore);

/**
 * Get the update rule for the submodule.
 */
GIT_EXTERN(git_submodule_update_t) git_submodule_update(
	git_submodule *submodule);

/**
 * Set the update rule for the submodule.
 *
 * This sets the update rule in memory for the submodule.  You should call
 * `git_submodule_save()` if you want to persist the new update rule.
 *
 * Calling this again with GIT_SUBMODULE_UPDATE_DEFAULT or calling
 * `git_submodule_reload()` will revert the rule to the value that was in the
 * original config.
 *
 * @return old value for update
 */
GIT_EXTERN(git_submodule_update_t) git_submodule_set_update(
	git_submodule *submodule,
	git_submodule_update_t update);

/**
 * Read the fetchRecurseSubmodules rule for a submodule.
 *
 * This accesses the submodule.<name>.fetchRecurseSubmodules value for
 * the submodule that controls fetching behavior for the submodule.
 *
 * Note that at this time, libgit2 does not honor this setting and the
 * fetch functionality current ignores submodules.
 *
 * @return 0 if fetchRecurseSubmodules is false, 1 if true
 */
GIT_EXTERN(int) git_submodule_fetch_recurse_submodules(
	git_submodule *submodule);

/**
 * Set the fetchRecurseSubmodules rule for a submodule.
 *
 * This sets the submodule.<name>.fetchRecurseSubmodules value for
 * the submodule.  You should call `git_submodule_save()` if you want
 * to persist the new value.
 *
 * @param submodule The submodule to modify
 * @param fetch_recurse_submodules Boolean value
 * @return old value for fetchRecurseSubmodules
 */
GIT_EXTERN(int) git_submodule_set_fetch_recurse_submodules(
	git_submodule *submodule,
	int fetch_recurse_submodules);

/**
 * Copy submodule info into ".git/config" file.
 *
 * Just like "git submodule init", this copies information about the
 * submodule into ".git/config".  You can use the accessor functions
 * above to alter the in-memory git_submodule object and control what
 * is written to the config, overriding what is in .gitmodules.
 *
 * @param submodule The submodule to write into the superproject config
 * @param overwrite By default, existing entries will not be overwritten,
 *                  but setting this to true forces them to be updated.
 * @return 0 on success, <0 on failure.
 */
GIT_EXTERN(int) git_submodule_init(git_submodule *submodule, int overwrite);

/**
 * Copy submodule remote info into submodule repo.
 *
 * This copies the information about the submodules URL into the checked out
 * submodule config, acting like "git submodule sync".  This is useful if
 * you have altered the URL for the submodule (or it has been altered by a
 * fetch of upstream changes) and you need to update your local repo.
 */
GIT_EXTERN(int) git_submodule_sync(git_submodule *submodule);

/**
 * Open the repository for a submodule.
 *
 * This is a newly opened repository object.  The caller is responsible for
 * calling `git_repository_free()` on it when done.  Multiple calls to this
 * function will return distinct `git_repository` objects.  This will only
 * work if the submodule is checked out into the working directory.
 *
 * @param subrepo Pointer to the submodule repo which was opened
 * @param submodule Submodule to be opened
 * @return 0 on success, <0 if submodule repo could not be opened.
 */
GIT_EXTERN(int) git_submodule_open(
	git_repository **repo,
	git_submodule *submodule);

/**
 * Reread submodule info from config, index, and HEAD.
 *
 * Call this to reread cached submodule information for this submodule if
 * you have reason to believe that it has changed.
 */
GIT_EXTERN(int) git_submodule_reload(git_submodule *submodule);

/**
 * Reread all submodule info.
 *
 * Call this to reload all cached submodule information for the repo.
 */
GIT_EXTERN(int) git_submodule_reload_all(git_repository *repo);

/**
 * Get the status for a submodule.
 *
 * This looks at a submodule and tries to determine the status.  It
 * will return a combination of the `GIT_SUBMODULE_STATUS` values above.
 * How deeply it examines the working directory to do this will depend
 * on the `git_submodule_ignore_t` value for the submodule - which can be
 * set either temporarily or permanently with `git_submodule_set_ignore()`.
 *
 * @param status Combination of `GIT_SUBMODULE_STATUS` flags
 * @param submodule Submodule for which to get status
 * @return 0 on success, <0 on error
 */
GIT_EXTERN(int) git_submodule_status(
	unsigned int *status,
	git_submodule *submodule);

/**
 * Get the locations of submodule information.
 *
 * This is a bit like a very lightweight version of `git_submodule_status`.
 * It just returns a made of the first four submodule status values (i.e.
 * the ones like GIT_SUBMODULE_STATUS_IN_HEAD, etc) that tell you where the
 * submodule data comes from (i.e. the HEAD commit, gitmodules file, etc.).
 * This can be useful if you want to know if the submodule is present in the
 * working directory at this point in time, etc.
 *
 * @param status Combination of first four `GIT_SUBMODULE_STATUS` flags
 * @param submodule Submodule for which to get status
 * @return 0 on success, <0 on error
 */
GIT_EXTERN(int) git_submodule_location(
	unsigned int *location_status,
	git_submodule *submodule);

/** @} */
GIT_END_DECL
#endif
