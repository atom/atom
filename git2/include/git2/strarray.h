/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_strarray_h__
#define INCLUDE_git_strarray_h__

#include "common.h"

/**
 * @file git2/strarray.h
 * @brief Git string array routines
 * @defgroup git_strarray Git string array routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/** Array of strings */
typedef struct _git_strarray git_strarray;
struct _git_strarray {
    char **strings;
    size_t count;
};

/**
 * Close a string array object
 *
 * This method must always be called once a git_strarray is no
 * longer needed, otherwise memory will leak.
 *
 * @param array array to close
 */
GIT_EXTERN(void) git_strarray_free(git_strarray *array);

/**
 * Copy a string array object from source to target.
 * 
 * Note: target is overwritten and hence should be empty, 
 * otherwise its contents are leaked.
 *
 * @param tgt target
 * @param src source
 */
GIT_EXTERN(int) git_strarray_copy(git_strarray *tgt, const git_strarray *src);


/** @} */
GIT_END_DECL

#endif
 
