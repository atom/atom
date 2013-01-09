/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_reset_h__
#define INCLUDE_git_reset_h__

/**
 * @file git2/reset.h
 * @brief Git reset management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Kinds of reset operation
 */
typedef enum {
	GIT_RESET_SOFT  = 1, /** Move the head to the given commit */
	GIT_RESET_MIXED = 2, /** SOFT plus reset index to the commit */
	GIT_RESET_HARD  = 3, /** MIXED plus changes in working tree discarded */
} git_reset_t;

/**
 * Sets the current head to the specified commit oid and optionally
 * resets the index and working tree to match.
 *
 * SOFT reset means the head will be moved to the commit.
 *
 * MIXED reset will trigger a SOFT reset, plus the index will be replaced
 * with the content of the commit tree.
 *
 * HARD reset will trigger a MIXED reset and the working directory will be
 * replaced with the content of the index.  (Untracked and ignored files
 * will be left alone, however.)
 *
 * TODO: Implement remaining kinds of resets.
 *
 * @param repo Repository where to perform the reset operation.
 *
 * @param target Object to which the Head should be moved to. This object
 * must belong to the given `repo` and can either be a git_commit or a
 * git_tag. When a git_tag is being passed, it should be dereferencable
 * to a git_commit which oid will be used as the target of the branch.
 *
 * @param reset_type Kind of reset operation to perform.
 *
 * @return 0 on success or an error code < 0
 */
GIT_EXTERN(int) git_reset(
	git_repository *repo, git_object *target, git_reset_t reset_type);

/** @} */
GIT_END_DECL
#endif
