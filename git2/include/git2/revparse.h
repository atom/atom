/*
 * Copyright (C) 2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_revparse_h__
#define INCLUDE_git_revparse_h__

#include "common.h"
#include "types.h"


/**
 * @file git2/revparse.h
 * @brief Git revision parsing routines
 * @defgroup git_revparse Git revision parsing routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Find an object, as specified by a revision string. See `man gitrevisions`, or the documentation
 * for `git rev-parse` for information on the syntax accepted.
 *
 * @param out pointer to output object
 * @param repo the repository to search in
 * @param spec the textual specification for an object
 * @return  on success, GIT_ERROR otherwise (use git_error_last for information about the error)
 */
GIT_EXTERN(int) git_revparse_single(git_object **out, git_repository *repo, const char *spec);

/** @} */
GIT_END_DECL
#endif
