/*
 * Copyright (C) 2012 the libgit2 contributors
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

typedef enum {
	GIT_SUBMODULE_UPDATE_CHECKOUT = 0,
	GIT_SUBMODULE_UPDATE_REBASE = 1,
	GIT_SUBMODULE_UPDATE_MERGE = 2
} git_submodule_update_t;

typedef enum {
	GIT_SUBMODULE_IGNORE_ALL = 0,       /* never dirty */
	GIT_SUBMODULE_IGNORE_DIRTY = 1,     /* only dirty if HEAD moved */
	GIT_SUBMODULE_IGNORE_UNTRACKED = 2, /* dirty if tracked files change */
	GIT_SUBMODULE_IGNORE_NONE = 3       /* any change or untracked == dirty */
} git_submodule_ignore_t;

/**
 * Description of submodule
 *
 * This record describes a submodule found in a repository.  There
 * should be an entry for every submodule found in the HEAD and for
 * every submodule described in .gitmodules.  The fields are as follows:
 *
 * - `name` is the name of the submodule from .gitmodules.
 * - `path` is the path to the submodule from the repo working directory.
 *   It is almost always the same as `name`.
 * - `url` is the url for the submodule.
 * - `oid` is the HEAD SHA1 for the submodule.
 * - `update` is a value from above - see gitmodules(5) update.
 * - `ignore` is a value from above - see gitmodules(5) ignore.
 * - `fetch_recurse` is 0 or 1 - see gitmodules(5) fetchRecurseSubmodules.
 * - `refcount` is for internal use.
 *
 * If the submodule has been added to .gitmodules but not yet git added,
 * then the `oid` will be zero.  If the submodule has been deleted, but
 * the delete has not been committed yet, then the `oid` will be set, but
 * the `url` will be NULL.
 */
typedef struct {
	char *name;
	char *path;
	char *url;
	git_oid oid; /* sha1 of submodule HEAD ref or zero if not committed */
	git_submodule_update_t update;
	git_submodule_ignore_t ignore;
	int fetch_recurse;
	int refcount;
} git_submodule;

/**
 * Iterate over all submodules of a repository.
 *
 * @param repo The repository
 * @param callback Function to be called with the name of each submodule.
 *        Return a non-zero value to terminate the iteration.
 * @param payload Extra data to pass to callback
 * @return 0 on success, -1 on error, or non-zero return value of callback
 */
GIT_EXTERN(int) git_submodule_foreach(
	git_repository *repo,
	int (*callback)(const char *name, void *payload),
	void *payload);

/**
 * Lookup submodule information by name or path.
 *
 * Given either the submodule name or path (they are ususally the same),
 * this returns a structure describing the submodule.  If the submodule
 * does not exist, this will return GIT_ENOTFOUND and set the submodule
 * pointer to NULL.
 *
 * @param submodule Pointer to submodule description object pointer..
 * @param repo The repository.
 * @param name The name of the submodule.  Trailing slashes will be ignored.
 * @return 0 on success, GIT_ENOTFOUND if submodule does not exist, -1 on error
 */
GIT_EXTERN(int) git_submodule_lookup(
	git_submodule **submodule,
	git_repository *repo,
	const char *name);

/** @} */
GIT_END_DECL
#endif
