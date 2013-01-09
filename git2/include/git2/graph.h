/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_graph_h__
#define INCLUDE_git_graph_h__

#include "common.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/graph.h
 * @brief Git graph traversal routines
 * @defgroup git_revwalk Git graph traversal routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Count the number of unique commits between two commit objects
 *
 * @param ahead number of commits, starting at `one`, unique from commits in `two`
 * @param behind number of commits, starting at `two`, unique from commits in `one`
 * @param repo the repository where the commits exist
 * @param one one of the commits
 * @param two the other commit
 */
GIT_EXTERN(int) git_graph_ahead_behind(size_t *ahead, size_t *behind, git_repository *repo, const git_oid *one, const git_oid *two);

/** @} */
GIT_END_DECL
#endif
