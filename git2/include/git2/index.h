/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_index_h__
#define INCLUDE_git_index_h__

#include "common.h"
#include "indexer.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/index.h
 * @brief Git index parsing and manipulation routines
 * @defgroup git_index Git index parsing and manipulation routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

#define GIT_IDXENTRY_NAMEMASK  (0x0fff)
#define GIT_IDXENTRY_STAGEMASK (0x3000)
#define GIT_IDXENTRY_EXTENDED  (0x4000)
#define GIT_IDXENTRY_VALID     (0x8000)
#define GIT_IDXENTRY_STAGESHIFT 12

/*
 * Flags are divided into two parts: in-memory flags and
 * on-disk ones. Flags in GIT_IDXENTRY_EXTENDED_FLAGS
 * will get saved on-disk.
 *
 * In-memory only flags:
 */
#define GIT_IDXENTRY_UPDATE            (1 << 0)
#define GIT_IDXENTRY_REMOVE            (1 << 1)
#define GIT_IDXENTRY_UPTODATE          (1 << 2)
#define GIT_IDXENTRY_ADDED             (1 << 3)

#define GIT_IDXENTRY_HASHED            (1 << 4)
#define GIT_IDXENTRY_UNHASHED          (1 << 5)
#define GIT_IDXENTRY_WT_REMOVE         (1 << 6) /* remove in work directory */
#define GIT_IDXENTRY_CONFLICTED        (1 << 7)

#define GIT_IDXENTRY_UNPACKED          (1 << 8)
#define GIT_IDXENTRY_NEW_SKIP_WORKTREE (1 << 9)

/*
 * Extended on-disk flags:
 */
#define GIT_IDXENTRY_INTENT_TO_ADD     (1 << 13)
#define GIT_IDXENTRY_SKIP_WORKTREE     (1 << 14)
/* GIT_IDXENTRY_EXTENDED2 is for future extension */
#define GIT_IDXENTRY_EXTENDED2         (1 << 15)

#define GIT_IDXENTRY_EXTENDED_FLAGS (GIT_IDXENTRY_INTENT_TO_ADD | GIT_IDXENTRY_SKIP_WORKTREE)

/** Time used in a git index entry */
typedef struct {
	git_time_t seconds;
	/* nsec should not be stored as time_t compatible */
	unsigned int nanoseconds;
} git_index_time;

/** Memory representation of a file entry in the index. */
typedef struct git_index_entry {
	git_index_time ctime;
	git_index_time mtime;

	unsigned int dev;
	unsigned int ino;
	unsigned int mode;
	unsigned int uid;
	unsigned int gid;
	git_off_t file_size;

	git_oid oid;

	unsigned short flags;
	unsigned short flags_extended;

	char *path;
} git_index_entry;

/** Representation of a resolve undo entry in the index. */
typedef struct git_index_reuc_entry {
	unsigned int mode[3];
	git_oid oid[3];
	char *path;
} git_index_reuc_entry;

/** Capabilities of system that affect index actions. */
enum {
	GIT_INDEXCAP_IGNORE_CASE = 1,
	GIT_INDEXCAP_NO_FILEMODE = 2,
	GIT_INDEXCAP_NO_SYMLINKS = 4,
	GIT_INDEXCAP_FROM_OWNER  = ~0u
};

/** @name Index File Functions
 *
 * These functions work on the index file itself.
 */
/**@{*/

/**
 * Create a new bare Git index object as a memory representation
 * of the Git index file in 'index_path', without a repository
 * to back it.
 *
 * Since there is no ODB or working directory behind this index,
 * any Index methods which rely on these (e.g. index_add) will
 * fail with the GIT_EBAREINDEX error code.
 *
 * If you need to access the index of an actual repository,
 * use the `git_repository_index` wrapper.
 *
 * The index must be freed once it's no longer in use.
 *
 * @param out the pointer for the new index
 * @param index_path the path to the index file in disk
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_open(git_index **out, const char *index_path);

/**
 * Create an in-memory index object.
 *
 * This index object cannot be read/written to the filesystem,
 * but may be used to perform in-memory index operations.
 *
 * The index must be freed once it's no longer in use.
 *
 * @param out the pointer for the new index
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_new(git_index **out);

/**
 * Free an existing index object.
 *
 * @param index an existing index object
 */
GIT_EXTERN(void) git_index_free(git_index *index);

/**
 * Get the repository this index relates to
 *
 * @param index The index
 * @return A pointer to the repository
 */
GIT_EXTERN(git_repository *) git_index_owner(const git_index *index);

/**
 * Read index capabilities flags.
 *
 * @param index An existing index object
 * @return A combination of GIT_INDEXCAP values
 */
GIT_EXTERN(unsigned int) git_index_caps(const git_index *index);

/**
 * Set index capabilities flags.
 *
 * If you pass `GIT_INDEXCAP_FROM_OWNER` for the caps, then the
 * capabilities will be read from the config of the owner object,
 * looking at `core.ignorecase`, `core.filemode`, `core.symlinks`.
 *
 * @param index An existing index object
 * @param caps A combination of GIT_INDEXCAP values
 * @return 0 on success, -1 on failure
 */
GIT_EXTERN(int) git_index_set_caps(git_index *index, unsigned int caps);

/**
 * Update the contents of an existing index object in memory
 * by reading from the hard disk.
 *
 * @param index an existing index object
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_read(git_index *index);

/**
 * Write an existing index object from memory back to disk
 * using an atomic file lock.
 *
 * @param index an existing index object
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_write(git_index *index);

/**
 * Read a tree into the index file with stats
 *
 * The current index contents will be replaced by the specified tree.
 *
 * @param index an existing index object
 * @param tree tree to read
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_read_tree(git_index *index, const git_tree *tree);

/**
 * Write the index as a tree
 *
 * This method will scan the index and write a representation
 * of its current state back to disk; it recursively creates
 * tree objects for each of the subtrees stored in the index,
 * but only returns the OID of the root tree. This is the OID
 * that can be used e.g. to create a commit.
 *
 * The index instance cannot be bare, and needs to be associated
 * to an existing repository.
 *
 * The index must not contain any file in conflict.
 *
 * @param out Pointer where to store the OID of the written tree
 * @param index Index to write
 * @return 0 on success, GIT_EUNMERGED when the index is not clean
 * or an error code
 */
GIT_EXTERN(int) git_index_write_tree(git_oid *out, git_index *index);

/**
 * Write the index as a tree to the given repository
 *
 * This method will do the same as `git_index_write_tree`, but
 * letting the user choose the repository where the tree will
 * be written.
 *
 * The index must not contain any file in conflict.
 *
 * @param out Pointer where to store OID of the the written tree
 * @param index Index to write
 * @param repo Repository where to write the tree
 * @return 0 on success, GIT_EUNMERGED when the index is not clean
 * or an error code
 */
GIT_EXTERN(int) git_index_write_tree_to(git_oid *out, git_index *index, git_repository *repo);

/**@}*/

/** @name Raw Index Entry Functions
 *
 * These functions work on index entries, and allow for raw manipulation
 * of the entries.
 */
/**@{*/

/* Index entry manipulation */

/**
 * Get the count of entries currently in the index
 *
 * @param index an existing index object
 * @return integer of count of current entries
 */
GIT_EXTERN(size_t) git_index_entrycount(const git_index *index);

/**
 * Clear the contents (all the entries) of an index object.
 * This clears the index object in memory; changes must be manually
 * written to disk for them to take effect.
 *
 * @param index an existing index object
 */
GIT_EXTERN(void) git_index_clear(git_index *index);

/**
 * Get a pointer to one of the entries in the index
 *
 * The values of this entry can be modified (except the path)
 * and the changes will be written back to disk on the next
 * write() call.
 *
 * The entry should not be freed by the caller.
 *
 * @param index an existing index object
 * @param n the position of the entry
 * @return a pointer to the entry; NULL if out of bounds
 */
GIT_EXTERN(const git_index_entry *) git_index_get_byindex(
	git_index *index, size_t n);

/**
 * Get a pointer to one of the entries in the index
 *
 * The values of this entry can be modified (except the path)
 * and the changes will be written back to disk on the next
 * write() call.
 *
 * The entry should not be freed by the caller.
 *
 * @param index an existing index object
 * @param path path to search
 * @param stage stage to search
 * @return a pointer to the entry; NULL if it was not found
 */
GIT_EXTERN(const git_index_entry *) git_index_get_bypath(
	git_index *index, const char *path, int stage);

/**
 * Remove an entry from the index
 *
 * @param index an existing index object
 * @param path path to search
 * @param stage stage to search
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_remove(git_index *index, const char *path, int stage);

/**
 * Add or update an index entry from an in-memory struct
 *
 * If a previous index entry exists that has the same path and stage
 * as the given 'source_entry', it will be replaced.  Otherwise, the
 * 'source_entry' will be added.
 *
 * A full copy (including the 'path' string) of the given
 * 'source_entry' will be inserted on the index.
 *
 * @param index an existing index object
 * @param source_entry new entry object
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_add(git_index *index, const git_index_entry *source_entry);

/**
 * Return the stage number from a git index entry
 *
 * This entry is calculated from the entry's flag
 * attribute like this:
 *
 *	(entry->flags & GIT_IDXENTRY_STAGEMASK) >> GIT_IDXENTRY_STAGESHIFT
 *
 * @param entry The entry
 * @returns the stage number
 */
GIT_EXTERN(int) git_index_entry_stage(const git_index_entry *entry);

/**@}*/

/** @name Workdir Index Entry Functions
 *
 * These functions work on index entries specifically in the working
 * directory (ie, stage 0).
 */
/**@{*/

/**
 * Add or update an index entry from a file in disk
 *
 * The file `path` must be relative to the repository's
 * working folder and must be readable.
 *
 * This method will fail in bare index instances.
 *
 * This forces the file to be added to the index, not looking
 * at gitignore rules.  Those rules can be evaluated through
 * the git_status APIs (in status.h) before calling this.
 *
 * If this file currently is the result of a merge conflict, this
 * file will no longer be marked as conflicting.  The data about
 * the conflict will be moved to the "resolve undo" (REUC) section.
 *
 * @param index an existing index object
 * @param path filename to add
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_add_from_workdir(git_index *index, const char *path);

/**
 * Find the first index of any entries which point to given
 * path in the Git index.
 *
 * @param index an existing index object
 * @param path path to search
 * @return an index >= 0 if found, -1 otherwise
 */
GIT_EXTERN(int) git_index_find(git_index *index, const char *path);

/**@}*/

/** @name Conflict Index Entry Functions
 *
 * These functions work on conflict index entries specifically (ie, stages 1-3)
 */
/**@{*/

/**
 * Add or update index entries to represent a conflict
 *
 * The entries are the entries from the tree included in the merge.  Any
 * entry may be null to indicate that that file was not present in the
 * trees during the merge.  For example, ancestor_entry may be NULL to
 * indicate that a file was added in both branches and must be resolved.
 *
 * @param index an existing index object
 * @param ancestor_entry the entry data for the ancestor of the conflict
 * @param our_entry the entry data for our side of the merge conflict
 * @param their_entry the entry data for their side of the merge conflict
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_conflict_add(
   git_index *index,
	const git_index_entry *ancestor_entry,
	const git_index_entry *our_entry,
	const git_index_entry *their_entry);

/**
 * Get the index entries that represent a conflict of a single file.
 *
 * The values of this entry can be modified (except the paths)
 * and the changes will be written back to disk on the next
 * write() call.
 *
 * @param ancestor_out Pointer to store the ancestor entry
 * @param our_out Pointer to store the our entry
 * @param their_out Pointer to store the their entry
 * @param index an existing index object
 * @param path path to search
 */
GIT_EXTERN(int) git_index_conflict_get(git_index_entry **ancestor_out, git_index_entry **our_out, git_index_entry **their_out, git_index *index, const char *path);

/**
 * Removes the index entries that represent a conflict of a single file.
 *
 * @param index an existing index object
 * @param path to search
 */
GIT_EXTERN(int) git_index_conflict_remove(git_index *index, const char *path);

/**
 * Remove all conflicts in the index (entries with a stage greater than 0.)
 *
 * @param index an existing index object
 */
GIT_EXTERN(void) git_index_conflict_cleanup(git_index *index);

/**
 * Determine if the index contains entries representing file conflicts.
 *
 * @return 1 if at least one conflict is found, 0 otherwise.
 */
GIT_EXTERN(int) git_index_has_conflicts(const git_index *index);

/**@}*/

/** @name Resolve Undo (REUC) index entry manipulation.
 *
 * These functions work on the Resolve Undo index extension and contains
 * data about the original files that led to a merge conflict.
 */
/**@{*/

/**
 * Get the count of resolve undo entries currently in the index.
 *
 * @param index an existing index object
 * @return integer of count of current resolve undo entries
 */
GIT_EXTERN(unsigned int) git_index_reuc_entrycount(git_index *index);

/**
 * Finds the resolve undo entry that points to the given path in the Git
 * index.
 *
 * @param index an existing index object
 * @param path path to search
 * @return an index >= 0 if found, -1 otherwise
 */
GIT_EXTERN(int) git_index_reuc_find(git_index *index, const char *path);

/**
 * Get a resolve undo entry from the index.
 *
 * The returned entry is read-only and should not be modified
 * or freed by the caller.
 *
 * @param index an existing index object
 * @param path path to search
 * @return the resolve undo entry; NULL if not found
 */
GIT_EXTERN(const git_index_reuc_entry *) git_index_reuc_get_bypath(git_index *index, const char *path);

/**
 * Get a resolve undo entry from the index.
 *
 * The returned entry is read-only and should not be modified
 * or freed by the caller.
 *
 * @param index an existing index object
 * @param n the position of the entry
 * @return a pointer to the resolve undo entry; NULL if out of bounds
 */
GIT_EXTERN(const git_index_reuc_entry *) git_index_reuc_get_byindex(git_index *index, size_t n);

/**
 * Adds a resolve undo entry for a file based on the given parameters.
 *
 * The resolve undo entry contains the OIDs of files that were involved
 * in a merge conflict after the conflict has been resolved.  This allows
 * conflicts to be re-resolved later.
 *
 * If there exists a resolve undo entry for the given path in the index,
 * it will be removed.
 *
 * This method will fail in bare index instances.
 *
 * @param index an existing index object
 * @param path filename to add
 * @param ancestor_mode mode of the ancestor file
 * @param ancestor_id oid of the ancestor file
 * @param our_mode mode of our file
 * @param our_id oid of our file
 * @param their_mode mode of their file
 * @param their_id oid of their file
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_reuc_add(git_index *index, const char *path,
	int ancestor_mode, git_oid *ancestor_id,
	int our_mode, git_oid *our_id,
	int their_mode, git_oid *their_id);

/**
 * Remove an resolve undo entry from the index
 *
 * @param index an existing index object
 * @param n position of the resolve undo entry to remove
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_reuc_remove(git_index *index, size_t n);

/**@}*/

/** @} */
GIT_END_DECL
#endif
