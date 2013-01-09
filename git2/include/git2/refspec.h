/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_refspec_h__
#define INCLUDE_git_refspec_h__

#include "common.h"
#include "types.h"

/**
 * @file git2/refspec.h
 * @brief Git refspec attributes
 * @defgroup git_refspec Git refspec attributes
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Get the source specifier
 *
 * @param refspec the refspec
 * @return the refspec's source specifier
 */
GIT_EXTERN(const char *) git_refspec_src(const git_refspec *refspec);

/**
 * Get the destination specifier
 *
 * @param refspec the refspec
 * @return the refspec's destination specifier
 */
GIT_EXTERN(const char *) git_refspec_dst(const git_refspec *refspec);

/**
 * Get the force update setting
 *
 * @param refspec the refspec
 * @return 1 if force update has been set, 0 otherwise
 */
GIT_EXTERN(int) git_refspec_force(const git_refspec *refspec);

/**
 * Check if a refspec's source descriptor matches a reference 
 *
 * @param refspec the refspec
 * @param refname the name of the reference to check
 * @return 1 if the refspec matches, 0 otherwise
 */
GIT_EXTERN(int) git_refspec_src_matches(const git_refspec *refspec, const char *refname);

/**
 * Transform a reference to its target following the refspec's rules
 *
 * @param out where to store the target name
 * @param outlen the size of the `out` buffer
 * @param spec the refspec
 * @param name the name of the reference to transform
 * @return 0, GIT_EBUFS or another error
 */
GIT_EXTERN(int) git_refspec_transform(char *out, size_t outlen, const git_refspec *spec, const char *name);

GIT_END_DECL

#endif
