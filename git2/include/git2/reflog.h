/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_reflog_h__
#define INCLUDE_git_reflog_h__

#include "common.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/reflog.h
 * @brief Git reflog management routines
 * @defgroup git_reflog Git reflog management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Read the reflog for the given reference
 *
 * The reflog must be freed manually by using
 * git_reflog_free().
 *
 * @param reflog pointer to reflog
 * @param ref reference to read the reflog for
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reflog_read(git_reflog **reflog, git_reference *ref);

/**
 * Write a new reflog for the given reference
 *
 * If there is no reflog file for the given
 * reference yet, it will be created.
 *
 * `oid_old` may be NULL in case it's a new reference.
 *
 * `msg` is optional and can be NULL.
 *
 * @param ref the changed reference
 * @param oid_old the OID the reference was pointing to
 * @param committer the signature of the committer
 * @param msg the reflog message
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reflog_write(git_reference *ref, const git_oid *oid_old, const git_signature *committer, const char *msg);

/**
 * Rename the reflog for the given reference
 *
 * @param ref the reference
 * @param new_name the new name of the reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reflog_rename(git_reference *ref, const char *new_name);

/**
 * Delete the reflog for the given reference
 *
 * @param ref the reference
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_reflog_delete(git_reference *ref);

/**
 * Get the number of log entries in a reflog
 *
 * @param reflog the previously loaded reflog
 * @return the number of log entries
 */
GIT_EXTERN(unsigned int) git_reflog_entrycount(git_reflog *reflog);

/**
 * Lookup an entry by its index
 *
 * @param reflog a previously loaded reflog
 * @param idx the position to lookup
 * @return the entry; NULL if not found
 */
GIT_EXTERN(const git_reflog_entry *) git_reflog_entry_byindex(git_reflog *reflog, unsigned int idx);

/**
 * Get the old oid
 *
 * @param entry a reflog entry
 * @return the old oid
 */
GIT_EXTERN(const git_oid *) git_reflog_entry_oidold(const git_reflog_entry *entry);

/**
 * Get the new oid
 *
 * @param entry a reflog entry
 * @return the new oid at this time
 */
GIT_EXTERN(const git_oid *) git_reflog_entry_oidnew(const git_reflog_entry *entry);

/**
 * Get the committer of this entry
 *
 * @param entry a reflog entry
 * @return the committer
 */
GIT_EXTERN(git_signature *) git_reflog_entry_committer(const git_reflog_entry *entry);

/**
 * Get the log msg
 *
 * @param entry a reflog entry
 * @return the log msg
 */
GIT_EXTERN(char *) git_reflog_entry_msg(const git_reflog_entry *entry);

/**
 * Free the reflog
 *
 * @param reflog reflog to free
 */
GIT_EXTERN(void) git_reflog_free(git_reflog *reflog);

/** @} */
GIT_END_DECL
#endif
