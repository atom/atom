/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_branch_h__
#define INCLUDE_git_branch_h__

#include "common.h"
#include "oid.h"
#include "types.h"

/**
 * @file git2/branch.h
 * @brief Git branch parsing routines
 * @defgroup git_branch Git branch management
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Create a new branch pointing at a target commit
 *
 * A new direct reference will be created pointing to
 * this target commit. If `force` is true and a reference
 * already exists with the given name, it'll be replaced.
 *
 * The returned reference must be freed by the user.
 *
 * @param branch_out Pointer where to store the underlying reference.
 *
 * @param branch_name Name for the branch; this name is
 * validated for consistency. It should also not conflict with
 * an already existing branch name.
 *
 * @param target Object to which this branch should point. This object
 * must belong to the given `repo` and can either be a git_commit or a
 * git_tag. When a git_tag is being passed, it should be dereferencable
 * to a git_commit which oid will be used as the target of the branch.
 *
 * @param force Overwrite existing branch.
 *
 * @return 0 or an error code.
 * A proper reference is written in the refs/heads namespace
 * pointing to the provided target commit.
 */
GIT_EXTERN(int) git_branch_create(
		git_reference **branch_out,
		git_repository *repo,
		const char *branch_name,
		const git_object *target,
		int force);

/**
 * Delete an existing branch reference.
 *
 * If the branch is successfully deleted, the passed reference
 * object will be freed and invalidated.
 *
 * @param branch A valid reference representing a branch
 * @return 0 on success, or an error code.
 */
GIT_EXTERN(int) git_branch_delete(git_reference *branch);

/**
 * Loop over all the branches and issue a callback for each one.
 *
 * If the callback returns a non-zero value, this will stop looping.
 *
 * @param repo Repository where to find the branches.
 *
 * @param list_flags Filtering flags for the branch
 * listing. Valid values are GIT_BRANCH_LOCAL, GIT_BRANCH_REMOTE
 * or a combination of the two.
 *
 * @param branch_cb Callback to invoke per found branch.
 *
 * @param payload Extra parameter to callback function.
 *
 * @return 0 on success, GIT_EUSER on non-zero callback, or error code
 */
GIT_EXTERN(int) git_branch_foreach(
		git_repository *repo,
		unsigned int list_flags,
		int (*branch_cb)(
			const char *branch_name,
			git_branch_t branch_type,
			void *payload),
		void *payload
);

/**
 * Move/rename an existing local branch reference.
 *
 * @param branch Current underlying reference of the branch.
 *
 * @param new_branch_name Target name of the branch once the move
 * is performed; this name is validated for consistency.
 *
 * @param force Overwrite existing branch.
 *
 * @return 0 on success, or an error code.
 */
GIT_EXTERN(int) git_branch_move(
		git_reference *branch,
		const char *new_branch_name,
		int force);

/**
 * Lookup a branch by its name in a repository.
 *
 * The generated reference must be freed by the user.
 *
 * @param branch_out pointer to the looked-up branch reference
 *
 * @param repo the repository to look up the branch
 *
 * @param branch_name Name of the branch to be looked-up;
 * this name is validated for consistency.
 *
 * @param branch_type Type of the considered branch. This should
 * be valued with either GIT_BRANCH_LOCAL or GIT_BRANCH_REMOTE.
 *
 * @return 0 on success; GIT_ENOTFOUND when no matching branch
 * exists, otherwise an error code.
 */
GIT_EXTERN(int) git_branch_lookup(
		git_reference **branch_out,
		git_repository *repo,
		const char *branch_name,
		git_branch_t branch_type);

/**
 * Return the reference supporting the remote tracking branch,
 * given a local branch reference.
 *
 * @param tracking_out Pointer where to store the retrieved
 * reference.
 *
 * @param branch Current underlying reference of the branch.
 *
 * @return 0 on success; GIT_ENOTFOUND when no remote tracking
 * reference exists, otherwise an error code.
 */
GIT_EXTERN(int) git_branch_tracking(
		git_reference **tracking_out,
		git_reference *branch);

/**
 * Determine if the current local branch is pointed at by HEAD.
 *
 * @param branch Current underlying reference of the branch.
 *
 * @return 1 if HEAD points at the branch, 0 if it isn't,
 * error code otherwise.
 */
GIT_EXTERN(int) git_branch_is_head(
		git_reference *branch);

/** @} */
GIT_END_DECL
#endif
