/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_revwalk_h__
#define INCLUDE_git_revwalk_h__

#include "common.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/revwalk.h
 * @brief Git revision traversal routines
 * @defgroup git_revwalk Git revision traversal routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Sort the repository contents in no particular ordering;
 * this sorting is arbitrary, implementation-specific
 * and subject to change at any time.
 * This is the default sorting for new walkers.
 */
#define GIT_SORT_NONE			(0)

/**
 * Sort the repository contents in topological order
 * (parents before children); this sorting mode
 * can be combined with time sorting.
 */
#define GIT_SORT_TOPOLOGICAL (1 << 0)

/**
 * Sort the repository contents by commit time;
 * this sorting mode can be combined with
 * topological sorting.
 */
#define GIT_SORT_TIME			(1 << 1)

/**
 * Iterate through the repository contents in reverse
 * order; this sorting mode can be combined with
 * any of the above.
 */
#define GIT_SORT_REVERSE		(1 << 2)

/**
 * Allocate a new revision walker to iterate through a repo.
 *
 * This revision walker uses a custom memory pool and an internal
 * commit cache, so it is relatively expensive to allocate.
 *
 * For maximum performance, this revision walker should be
 * reused for different walks.
 *
 * This revision walker is *not* thread safe: it may only be
 * used to walk a repository on a single thread; however,
 * it is possible to have several revision walkers in
 * several different threads walking the same repository.
 *
 * @param out pointer to the new revision walker
 * @param repo the repo to walk through
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_new(git_revwalk **out, git_repository *repo);

/**
 * Reset the revision walker for reuse.
 *
 * This will clear all the pushed and hidden commits, and
 * leave the walker in a blank state (just like at
 * creation) ready to receive new commit pushes and
 * start a new walk.
 *
 * The revision walk is automatically reset when a walk
 * is over.
 *
 * @param walker handle to reset.
 */
GIT_EXTERN(void) git_revwalk_reset(git_revwalk *walker);

/**
 * Mark a commit to start traversal from.
 *
 * The given OID must belong to a commit on the walked
 * repository.
 *
 * The given commit will be used as one of the roots
 * when starting the revision walk. At least one commit
 * must be pushed the repository before a walk can
 * be started.
 *
 * @param walk the walker being used for the traversal.
 * @param id the oid of the commit to start from.
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_push(git_revwalk *walk, const git_oid *id);

/**
 * Push matching references
 *
 * The OIDs pointed to by the references that match the given glob
 * pattern will be pushed to the revision walker.
 *
 * A leading 'refs/' is implied if not present as well as a trailing
 * '/ *' if the glob lacks '?', '*' or '['.
 *
 * @param walk the walker being used for the traversal
 * @param glob the glob pattern references should match
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_push_glob(git_revwalk *walk, const char *glob);

/**
 * Push the repository's HEAD
 *
 * @param walk the walker being used for the traversal
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_push_head(git_revwalk *walk);

/**
 * Mark a commit (and its ancestors) uninteresting for the output.
 *
 * The given OID must belong to a commit on the walked
 * repository.
 *
 * The resolved commit and all its parents will be hidden from the
 * output on the revision walk.
 *
 * @param walk the walker being used for the traversal.
 * @param commit_id the oid of commit that will be ignored during the traversal
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_hide(git_revwalk *walk, const git_oid *commit_id);

/**
 * Hide matching references.
 *
 * The OIDs pointed to by the references that match the given glob
 * pattern and their ancestors will be hidden from the output on the
 * revision walk.
 *
 * A leading 'refs/' is implied if not present as well as a trailing
 * '/ *' if the glob lacks '?', '*' or '['.
 *
 * @param walk the walker being used for the traversal
 * @param glob the glob pattern references should match
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_hide_glob(git_revwalk *walk, const char *glob);

/**
 * Hide the repository's HEAD
 *
 * @param walk the walker being used for the traversal
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_hide_head(git_revwalk *walk);

/**
 * Push the OID pointed to by a reference
 *
 * The reference must point to a commit.
 *
 * @param walk the walker being used for the traversal
 * @param refname the reference to push
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_push_ref(git_revwalk *walk, const char *refname);

/**
 * Hide the OID pointed to by a reference
 *
 * The reference must point to a commit.
 *
 * @param walk the walker being used for the traversal
 * @param refname the reference to hide
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_revwalk_hide_ref(git_revwalk *walk, const char *refname);

/**
 * Get the next commit from the revision walk.
 *
 * The initial call to this method is *not* blocking when
 * iterating through a repo with a time-sorting mode.
 *
 * Iterating with Topological or inverted modes makes the initial
 * call blocking to preprocess the commit list, but this block should be
 * mostly unnoticeable on most repositories (topological preprocessing
 * times at 0.3s on the git.git repo).
 *
 * The revision walker is reset when the walk is over.
 *
 * @param out Pointer where to store the oid of the next commit
 * @param walk the walker to pop the commit from.
 * @return 0 if the next commit was found;
 *	GIT_ITEROVER if there are no commits left to iterate
 */
GIT_EXTERN(int) git_revwalk_next(git_oid *out, git_revwalk *walk);

/**
 * Change the sorting mode when iterating through the
 * repository's contents.
 *
 * Changing the sorting mode resets the walker.
 *
 * @param walk the walker being used for the traversal.
 * @param sort_mode combination of GIT_SORT_XXX flags
 */
GIT_EXTERN(void) git_revwalk_sorting(git_revwalk *walk, unsigned int sort_mode);

/**
 * Free a revision walker previously allocated.
 *
 * @param walk traversal handle to close. If NULL nothing occurs.
 */
GIT_EXTERN(void) git_revwalk_free(git_revwalk *walk);

/**
 * Return the repository on which this walker
 * is operating.
 *
 * @param walk the revision walker
 * @return the repository being walked
 */
GIT_EXTERN(git_repository *) git_revwalk_repository(git_revwalk *walk);

/** @} */
GIT_END_DECL
#endif
