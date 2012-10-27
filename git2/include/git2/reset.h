/*
 * Copyright (C) 2009-2012 the libgit2 contributors
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
 * Sets the current head to the specified commit oid and optionally
 * resets the index and working tree to match.
 *
 * When specifying a Soft kind of reset, the head will be moved to the commit.
 *
 * Specifying a Mixed kind of reset will trigger a Soft reset and the index will
 * be replaced with the content of the commit tree.
 *
 * Specifying a Hard kind of reset will trigger a Mixed reset and the working
 * directory will be replaced with the content of the index.
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
 * @return GIT_SUCCESS or an error code
 */
GIT_EXTERN(int) git_reset(git_repository *repo, git_object *target, git_reset_type reset_type);

/** @} */
GIT_END_DECL
#endif
