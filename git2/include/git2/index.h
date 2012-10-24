/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_index_h__
#define INCLUDE_git_index_h__

#include "common.h"
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

#define GIT_IDXENTRY_NAMEMASK (0x0fff)
#define GIT_IDXENTRY_STAGEMASK (0x3000)
#define GIT_IDXENTRY_EXTENDED (0x4000)
#define GIT_IDXENTRY_VALID		(0x8000)
#define GIT_IDXENTRY_STAGESHIFT 12

/*
 * Flags are divided into two parts: in-memory flags and
 * on-disk ones. Flags in GIT_IDXENTRY_EXTENDED_FLAGS
 * will get saved on-disk.
 *
 * In-memory only flags:
 */
#define GIT_IDXENTRY_UPDATE			(1 << 0)
#define GIT_IDXENTRY_REMOVE			(1 << 1)
#define GIT_IDXENTRY_UPTODATE			(1 << 2)
#define GIT_IDXENTRY_ADDED				(1 << 3)

#define GIT_IDXENTRY_HASHED			(1 << 4)
#define GIT_IDXENTRY_UNHASHED			(1 << 5)
#define GIT_IDXENTRY_WT_REMOVE			(1 << 6) /* remove in work directory */
#define GIT_IDXENTRY_CONFLICTED		(1 << 7)

#define GIT_IDXENTRY_UNPACKED			(1 << 8)
#define GIT_IDXENTRY_NEW_SKIP_WORKTREE (1 << 9)

/*
 * Extended on-disk flags:
 */
#define GIT_IDXENTRY_INTENT_TO_ADD		(1 << 13)
#define GIT_IDXENTRY_SKIP_WORKTREE		(1 << 14)
/* GIT_IDXENTRY_EXTENDED2 is for future extension */
#define GIT_IDXENTRY_EXTENDED2			(1 << 15)

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

/** Representation of an unmerged file entry in the index. */
typedef struct git_index_entry_unmerged {
	unsigned int mode[3];
	git_oid oid[3];
	char *path;
} git_index_entry_unmerged;

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
 * @param index the pointer for the new index
 * @param index_path the path to the index file in disk
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_open(git_index **index, const char *index_path);

/**
 * Clear the contents (all the entries) of an index object.
 * This clears the index object in memory; changes must be manually
 * written to disk for them to take effect.
 *
 * @param index an existing index object
 */
GIT_EXTERN(void) git_index_clear(git_index *index);

/**
 * Free an existing index object.
 *
 * @param index an existing index object
 */
GIT_EXTERN(void) git_index_free(git_index *index);

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
 * Find the first index of any entries which point to given
 * path in the Git index.
 *
 * @param index an existing index object
 * @param path path to search
 * @return an index >= 0 if found, -1 otherwise
 */
GIT_EXTERN(int) git_index_find(git_index *index, const char *path);

/**
 * Remove all entries with equal path except last added
 *
 * @param index an existing index object
 */
GIT_EXTERN(void) git_index_uniq(git_index *index);

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
 * @param index an existing index object
 * @param path filename to add
 * @param stage stage for the entry
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_add(git_index *index, const char *path, int stage);

/**
 * Add or update an index entry from an in-memory struct
 *
 * A full copy (including the 'path' string) of the given
 * 'source_entry' will be inserted on the index.
 *
 * @param index an existing index object
 * @param source_entry new entry object
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_add2(git_index *index, const git_index_entry *source_entry);

/**
 * Add (append) an index entry from a file in disk
 *
 * A new entry will always be inserted into the index;
 * if the index already contains an entry for such
 * path, the old entry will **not** be replaced.
 *
 * The file `path` must be relative to the repository's
 * working folder and must be readable.
 *
 * This method will fail in bare index instances.
 *
 * @param index an existing index object
 * @param path filename to add
 * @param stage stage for the entry
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_append(git_index *index, const char *path, int stage);

/**
 * Add (append) an index entry from an in-memory struct
 *
 * A new entry will always be inserted into the index;
 * if the index already contains an entry for the path
 * in the `entry` struct, the old entry will **not** be
 * replaced.
 *
 * A full copy (including the 'path' string) of the given
 * 'source_entry' will be inserted on the index.
 *
 * @param index an existing index object
 * @param source_entry new entry object
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_append2(git_index *index, const git_index_entry *source_entry);

/**
 * Remove an entry from the index
 *
 * @param index an existing index object
 * @param position position of the entry to remove
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_remove(git_index *index, int position);


/**
 * Get a pointer to one of the entries in the index
 *
 * This entry can be modified, and the changes will be written
 * back to disk on the next write() call.
 *
 * The entry should not be freed by the caller.
 *
 * @param index an existing index object
 * @param n the position of the entry
 * @return a pointer to the entry; NULL if out of bounds
 */
GIT_EXTERN(git_index_entry *) git_index_get(git_index *index, unsigned int n);

/**
 * Get the count of entries currently in the index
 *
 * @param index an existing index object
 * @return integer of count of current entries
 */
GIT_EXTERN(unsigned int) git_index_entrycount(git_index *index);

/**
 * Get the count of unmerged entries currently in the index
 *
 * @param index an existing index object
 * @return integer of count of current unmerged entries
 */
GIT_EXTERN(unsigned int) git_index_entrycount_unmerged(git_index *index);

/**
 * Get an unmerged entry from the index.
 *
 * The returned entry is read-only and should not be modified
 * of freed by the caller.
 *
 * @param index an existing index object
 * @param path path to search
 * @return the unmerged entry; NULL if not found
 */
GIT_EXTERN(const git_index_entry_unmerged *) git_index_get_unmerged_bypath(git_index *index, const char *path);

/**
 * Get an unmerged entry from the index.
 *
 * The returned entry is read-only and should not be modified
 * of freed by the caller.
 *
 * @param index an existing index object
 * @param n the position of the entry
 * @return a pointer to the unmerged entry; NULL if out of bounds
 */
GIT_EXTERN(const git_index_entry_unmerged *) git_index_get_unmerged_byindex(git_index *index, unsigned int n);

/**
 * Return the stage number from a git index entry
 *
 * This entry is calculated from the entrie's flag
 * attribute like this:
 *
 *	(entry->flags & GIT_IDXENTRY_STAGEMASK) >> GIT_IDXENTRY_STAGESHIFT
 *
 * @param entry The entry
 * @returns the stage number
 */
GIT_EXTERN(int) git_index_entry_stage(const git_index_entry *entry);

/**
 * Read a tree into the index file
 *
 * The current index contents will be replaced by the specified tree.
 *
 * @param index an existing index object
 * @param tree tree to read
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_index_read_tree(git_index *index, git_tree *tree);

/** @} */
GIT_END_DECL
#endif
