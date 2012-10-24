/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_signature_h__
#define INCLUDE_git_signature_h__

#include "common.h"
#include "types.h"

/**
 * @file git2/signature.h
 * @brief Git signature creation
 * @defgroup git_signature Git signature creation
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Create a new action signature. The signature must be freed
 * manually or using git_signature_free
 *
 * @param sig_out new signature, in case of error NULL
 * @param name name of the person
 * @param email email of the person
 * @param time time when the action happened
 * @param offset timezone offset in minutes for the time
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_signature_new(git_signature **sig_out, const char *name, const char *email, git_time_t time, int offset);

/**
 * Create a new action signature with a timestamp of 'now'. The
 * signature must be freed manually or using git_signature_free
 *
 * @param sig_out new signature, in case of error NULL
 * @param name name of the person
 * @param email email of the person
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_signature_now(git_signature **sig_out, const char *name, const char *email);


/**
 * Create a copy of an existing signature.
 *
 * All internal strings are also duplicated.
 * @param sig signature to duplicated
 * @return a copy of sig, NULL on out of memory
 */
GIT_EXTERN(git_signature *) git_signature_dup(const git_signature *sig);

/**
 * Free an existing signature
 *
 * @param sig signature to free
 */
GIT_EXTERN(void) git_signature_free(git_signature *sig);

/** @} */
GIT_END_DECL
#endif
