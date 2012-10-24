/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_merge_h__
#define INCLUDE_git_merge_h__

#include "common.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/merge.h
 * @brief Git merge-base routines
 * @defgroup git_revwalk Git merge-base routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Find a merge base between two commits
 *
 * @param out the OID of a merge base between 'one' and 'two'
 * @param repo the repository where the commits exist
 * @param one one of the commits
 * @param two the other commit
 */
GIT_EXTERN(int) git_merge_base(git_oid *out, git_repository *repo, git_oid *one, git_oid *two);

/** @} */
GIT_END_DECL
#endif
