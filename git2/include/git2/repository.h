/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_repository_h__
#define INCLUDE_git_repository_h__

#include "common.h"
#include "types.h"
#include "oid.h"

/**
 * @file git2/repository.h
 * @brief Git repository management routines
 * @defgroup git_repository Git repository management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Open a git repository.
 *
 * The 'path' argument must point to either a git repository
 * folder, or an existing work dir.
 *
 * The method will automatically detect if 'path' is a normal
 * or bare repository or fail is 'path' is neither.
 *
 * @param repository pointer to the repo which will be opened
 * @param path the path to the repository
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_repository_open(git_repository **repository, const char *path);

/**
 * Look for a git repository and copy its path in the given buffer.
 * The lookup start from base_path and walk across parent directories
 * if nothing has been found. The lookup ends when the first repository
 * is found, or when reaching a directory referenced in ceiling_dirs
 * or when the filesystem changes (in case across_fs is true).
 *
 * The method will automatically detect if the repository is bare
 * (if there is a repository).
 *
 * @param repository_path The user allocated buffer which will
 * contain the found path.
 *
 * @param size repository_path size
 *
 * @param start_path The base path where the lookup starts.
 *
 * @param across_fs If true, then the lookup will not stop when a
 * filesystem device change is detected while exploring parent directories.
 *
 * @param ceiling_dirs A GIT_PATH_LIST_SEPARATOR separated list of
 * absolute symbolic link free paths. The lookup will stop when any
 * of this paths is reached. Note that the lookup always performs on
 * start_path no matter start_path appears in ceiling_dirs ceiling_dirs
 * might be NULL (which is equivalent to an empty string)
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_repository_discover(
		char *repository_path,
		size_t size,
		const char *start_path,
		int across_fs,
		const char *ceiling_dirs);

enum {
	GIT_REPOSITORY_OPEN_NO_SEARCH = (1 << 0),
	GIT_REPOSITORY_OPEN_CROSS_FS  = (1 << 1),
};

/**
 * Find and open a repository with extended controls.
 */
GIT_EXTERN(int) git_repository_open_ext(
	git_repository **repo,
	const char *start_path,
	uint32_t flags,
	const char *ceiling_dirs);

/**
 * Free a previously allocated repository
 *
 * Note that after a repository is free'd, all the objects it has spawned
 * will still exist until they are manually closed by the user
 * with `git_object_free`, but accessing any of the attributes of
 * an object without a backing repository will result in undefined
 * behavior
 *
 * @param repo repository handle to close. If NULL nothing occurs.
 */
GIT_EXTERN(void) git_repository_free(git_repository *repo);

/**
 * Creates a new Git repository in the given folder.
 *
 * TODO:
 *	- Reinit the repository
 *
 * @param repo_out pointer to the repo which will be created or reinitialized
 * @param path the path to the repository
 * @param is_bare if true, a Git repository without a working directory is created
 *		at the pointed path. If false, provided path will be considered as the working
 *		directory into which the .git directory will be created.
 *
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_repository_init(git_repository **repo_out, const char *path, unsigned is_bare);

/**
 * Retrieve and resolve the reference pointed at by HEAD.
 *
 * @param head_out pointer to the reference which will be retrieved
 * @param repo a repository object
 *
 * @return 0 on success; error code otherwise
 */
GIT_EXTERN(int) git_repository_head(git_reference **head_out, git_repository *repo);

/**
 * Check if a repository's HEAD is detached
 *
 * A repository's HEAD is detached when it points directly to a commit
 * instead of a branch.
 *
 * @param repo Repo to test
 * @return 1 if HEAD is detached, 0 if i'ts not; error code if there
 * was an error.
 */
GIT_EXTERN(int) git_repository_head_detached(git_repository *repo);

/**
 * Check if the current branch is an orphan
 *
 * An orphan branch is one named from HEAD but which doesn't exist in
 * the refs namespace, because it doesn't have any commit to point to.
 *
 * @param repo Repo to test
 * @return 1 if the current branch is an orphan, 0 if it's not; error
 * code if therewas an error
 */
GIT_EXTERN(int) git_repository_head_orphan(git_repository *repo);

/**
 * Check if a repository is empty
 *
 * An empty repository has just been initialized and contains
 * no commits.
 *
 * @param repo Repo to test
 * @return 1 if the repository is empty, 0 if it isn't, error code
 * if the repository is corrupted
 */
GIT_EXTERN(int) git_repository_is_empty(git_repository *repo);

/**
 * Get the path of this repository
 *
 * This is the path of the `.git` folder for normal repositories,
 * or of the repository itself for bare repositories.
 *
 * @param repo A repository object
 * @return the path to the repository
 */
GIT_EXTERN(const char *) git_repository_path(git_repository *repo);

/**
 * Get the path of the working directory for this repository
 *
 * If the repository is bare, this function will always return
 * NULL.
 *
 * @param repo A repository object
 * @return the path to the working dir, if it exists
 */
GIT_EXTERN(const char *) git_repository_workdir(git_repository *repo);

/**
 * Set the path to the working directory for this repository
 *
 * The working directory doesn't need to be the same one
 * that contains the `.git` folder for this repository.
 *
 * If this repository is bare, setting its working directory
 * will turn it into a normal repository, capable of performing
 * all the common workdir operations (checkout, status, index
 * manipulation, etc).
 *
 * @param repo A repository object
 * @param workdir The path to a working directory
 * @return 0, or an error code
 */
GIT_EXTERN(int) git_repository_set_workdir(git_repository *repo, const char *workdir);

/**
 * Check if a repository is bare
 *
 * @param repo Repo to test
 * @return 1 if the repository is bare, 0 otherwise.
 */
GIT_EXTERN(int) git_repository_is_bare(git_repository *repo);

/**
 * Get the configuration file for this repository.
 *
 * If a configuration file has not been set, the default
 * config set for the repository will be returned, including
 * global and system configurations (if they are available).
 *
 * The configuration file must be freed once it's no longer
 * being used by the user.
 *
 * @param out Pointer to store the loaded config file
 * @param repo A repository object
 * @return 0, or an error code
 */
GIT_EXTERN(int) git_repository_config(git_config **out, git_repository *repo);

/**
 * Set the configuration file for this repository
 *
 * This configuration file will be used for all configuration
 * queries involving this repository.
 *
 * The repository will keep a reference to the config file;
 * the user must still free the config after setting it
 * to the repository, or it will leak.
 *
 * @param repo A repository object
 * @param config A Config object
 */
GIT_EXTERN(void) git_repository_set_config(git_repository *repo, git_config *config);

/**
 * Get the Object Database for this repository.
 *
 * If a custom ODB has not been set, the default
 * database for the repository will be returned (the one
 * located in `.git/objects`).
 *
 * The ODB must be freed once it's no longer being used by
 * the user.
 *
 * @param out Pointer to store the loaded ODB
 * @param repo A repository object
 * @return 0, or an error code
 */
GIT_EXTERN(int) git_repository_odb(git_odb **out, git_repository *repo);

/**
 * Set the Object Database for this repository
 *
 * The ODB will be used for all object-related operations
 * involving this repository.
 *
 * The repository will keep a reference to the ODB; the user
 * must still free the ODB object after setting it to the
 * repository, or it will leak.
 *
 * @param repo A repository object
 * @param odb An ODB object
 */
GIT_EXTERN(void) git_repository_set_odb(git_repository *repo, git_odb *odb);

/**
 * Get the Index file for this repository.
 *
 * If a custom index has not been set, the default
 * index for the repository will be returned (the one
 * located in `.git/index`).
 *
 * The index must be freed once it's no longer being used by
 * the user.
 *
 * @param out Pointer to store the loaded index
 * @param repo A repository object
 * @return 0, or an error code
 */
GIT_EXTERN(int) git_repository_index(git_index **out, git_repository *repo);

/**
 * Set the index file for this repository
 *
 * This index will be used for all index-related operations
 * involving this repository.
 *
 * The repository will keep a reference to the index file;
 * the user must still free the index after setting it
 * to the repository, or it will leak.
 *
 * @param repo A repository object
 * @param index An index object
 */
GIT_EXTERN(void) git_repository_set_index(git_repository *repo, git_index *index);

/** @} */
GIT_END_DECL
#endif
