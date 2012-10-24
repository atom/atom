/*
 * Copyright (C) 2009-2012 the libgit2 contributors
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */
#ifndef INCLUDE_git_config_h__
#define INCLUDE_git_config_h__

#include "common.h"
#include "types.h"

/**
 * @file git2/config.h
 * @brief Git config management routines
 * @defgroup git_config Git config management routines
 * @ingroup Git
 * @{
 */
GIT_BEGIN_DECL

/**
 * Generic backend that implements the interface to
 * access a configuration file
 */
struct git_config_file {
	struct git_config *cfg;

	/* Open means open the file/database and parse if necessary */
	int (*open)(struct git_config_file *);
	int (*get)(struct git_config_file *, const char *key, const char **value);
	int (*get_multivar)(struct git_config_file *, const char *key, const char *regexp, int (*fn)(const char *, void *), void *data);
	int (*set)(struct git_config_file *, const char *key, const char *value);
	int (*set_multivar)(git_config_file *cfg, const char *name, const char *regexp, const char *value);
	int (*del)(struct git_config_file *, const char *key);
	int (*foreach)(struct git_config_file *, int (*fn)(const char *, const char *, void *), void *data);
	void (*free)(struct git_config_file *);
};

typedef enum {
	GIT_CVAR_FALSE = 0,
	GIT_CVAR_TRUE = 1,
	GIT_CVAR_INT32,
	GIT_CVAR_STRING
} git_cvar_t;

typedef struct {
	git_cvar_t cvar_type;
	const char *str_match;
	int map_value;
} git_cvar_map;

/**
 * Locate the path to the global configuration file
 *
 * The user or global configuration file is usually
 * located in `$HOME/.gitconfig`.
 *
 * This method will try to guess the full path to that
 * file, if the file exists. The returned path
 * may be used on any `git_config` call to load the
 * global configuration file.
 *
 * @param global_config_path Buffer of GIT_PATH_MAX length to store the path
 * @return 0 if a global configuration file has been
 *	found. Its path will be stored in `buffer`.
 */
GIT_EXTERN(int) git_config_find_global(char *global_config_path, size_t length);

/**
 * Locate the path to the system configuration file
 *
 * If /etc/gitconfig doesn't exist, it will look for
 * %PROGRAMFILES%\Git\etc\gitconfig.

 * @param system_config_path Buffer of GIT_PATH_MAX length to store the path
 * @return 0 if a system configuration file has been
 *	found. Its path will be stored in `buffer`.
 */
GIT_EXTERN(int) git_config_find_system(char *system_config_path, size_t length);

/**
 * Open the global configuration file
 *
 * Utility wrapper that calls `git_config_find_global`
 * and opens the located file, if it exists.
 *
 * @param out Pointer to store the config instance
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_open_global(git_config **out);

/**
 * Create a configuration file backend for ondisk files
 *
 * These are the normal `.gitconfig` files that Core Git
 * processes. Note that you first have to add this file to a
 * configuration object before you can query it for configuration
 * variables.
 *
 * @param out the new backend
 * @param path where the config file is located
 */
GIT_EXTERN(int) git_config_file__ondisk(struct git_config_file **out, const char *path);

/**
 * Allocate a new configuration object
 *
 * This object is empty, so you have to add a file to it before you
 * can do anything with it.
 *
 * @param out pointer to the new configuration
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_new(git_config **out);

/**
 * Add a generic config file instance to an existing config
 *
 * Note that the configuration object will free the file
 * automatically.
 *
 * Further queries on this config object will access each
 * of the config file instances in order (instances with
 * a higher priority will be accessed first).
 *
 * @param cfg the configuration to add the file to
 * @param file the configuration file (backend) to add
 * @param priority the priority the backend should have
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_add_file(git_config *cfg, git_config_file *file, int priority);

/**
 * Add an on-disk config file instance to an existing config
 *
 * The on-disk file pointed at by `path` will be opened and
 * parsed; it's expected to be a native Git config file following
 * the default Git config syntax (see man git-config).
 *
 * Note that the configuration object will free the file
 * automatically.
 *
 * Further queries on this config object will access each
 * of the config file instances in order (instances with
 * a higher priority will be accessed first).
 *
 * @param cfg the configuration to add the file to
 * @param path path to the configuration file (backend) to add
 * @param priority the priority the backend should have
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_add_file_ondisk(git_config *cfg, const char *path, int priority);


/**
 * Create a new config instance containing a single on-disk file
 *
 * This method is a simple utility wrapper for the following sequence
 * of calls:
 *	- git_config_new
 *	- git_config_add_file_ondisk
 *
 * @param cfg The configuration instance to create
 * @param path Path to the on-disk file to open
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_open_ondisk(git_config **cfg, const char *path);

/**
 * Free the configuration and its associated memory and files
 *
 * @param cfg the configuration to free
 */
GIT_EXTERN(void) git_config_free(git_config *cfg);

/**
 * Get the value of an integer config variable.
 *
 * @param out pointer to the variable where the value should be stored
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_int32(int32_t *out, git_config *cfg, const char *name);

/**
 * Get the value of a long integer config variable.
 *
 * @param out pointer to the variable where the value should be stored
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_int64(int64_t *out, git_config *cfg, const char *name);

/**
 * Get the value of a boolean config variable.
 *
 * This function uses the usual C convention of 0 being false and
 * anything else true.
 *
 * @param out pointer to the variable where the value should be stored
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_bool(int *out, git_config *cfg, const char *name);

/**
 * Get the value of a string config variable.
 *
 * The string is owned by the variable and should not be freed by the
 * user.
 *
 * @param out pointer to the variable's value
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_get_string(const char **out, git_config *cfg, const char *name);

/**
 * Get each value of a multivar.
 *
 * The callback will be called on each variable found
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param regexp regular expression to filter which variables we're
 * interested in. Use NULL to indicate all
 * @param fn the function to be called on each value of the variable
 * @param data opaque pointer to pass to the callback
 */
GIT_EXTERN(int) git_config_get_multivar(git_config *cfg, const char *name, const char *regexp, int (*fn)(const char *, void *), void *data);

/**
 * Set the value of an integer config variable.
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value Integer value for the variable
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_int32(git_config *cfg, const char *name, int32_t value);

/**
 * Set the value of a long integer config variable.
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value Long integer value for the variable
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_int64(git_config *cfg, const char *name, int64_t value);

/**
 * Set the value of a boolean config variable.
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value the value to store
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_bool(git_config *cfg, const char *name, int value);

/**
 * Set the value of a string config variable.
 *
 * A copy of the string is made and the user is free to use it
 * afterwards.
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param value the string to store.
 * @return 0 or an error code
 */
GIT_EXTERN(int) git_config_set_string(git_config *cfg, const char *name, const char *value);


/**
 * Set a multivar
 *
 * @param cfg where to look for the variable
 * @param name the variable's name
 * @param regexp a regular expression to indicate which values to replace
 * @param value the new value.
 */
GIT_EXTERN(int) git_config_set_multivar(git_config *cfg, const char *name, const char *regexp, const char *value);

/**
 * Delete a config variable
 *
 * @param cfg the configuration
 * @param name the variable to delete
 */
GIT_EXTERN(int) git_config_delete(git_config *cfg, const char *name);

/**
 * Perform an operation on each config variable.
 *
 * The callback receives the normalized name and value of each variable
 * in the config backend, and the data pointer passed to this function.
 * As soon as one of the callback functions returns something other than 0,
 * this function returns that value.
 *
 * @param cfg where to get the variables from
 * @param callback the function to call on each variable
 * @param payload the data to pass to the callback
 * @return 0 or the return value of the callback which didn't return 0
 */
GIT_EXTERN(int) git_config_foreach(
	git_config *cfg,
	int (*callback)(const char *var_name, const char *value, void *payload),
	void *payload);


/**
 * Query the value of a config variable and return it mapped to
 * an integer constant.
 *
 * This is a helper method to easily map different possible values
 * to a variable to integer constants that easily identify them.
 *
 * A mapping array looks as follows:
 *
 *	git_cvar_map autocrlf_mapping[3] = {
 *		{GIT_CVAR_FALSE, NULL, GIT_AUTO_CRLF_FALSE},
 *		{GIT_CVAR_TRUE, NULL, GIT_AUTO_CRLF_TRUE},
 *		{GIT_CVAR_STRING, "input", GIT_AUTO_CRLF_INPUT},
 *		{GIT_CVAR_STRING, "default", GIT_AUTO_CRLF_DEFAULT}};
 *
 * On any "false" value for the variable (e.g. "false", "FALSE", "no"), the
 * mapping will store `GIT_AUTO_CRLF_FALSE` in the `out` parameter.
 *
 * The same thing applies for any "true" value such as "true", "yes" or "1", storing
 * the `GIT_AUTO_CRLF_TRUE` variable.
 *
 * Otherwise, if the value matches the string "input" (with case insensitive comparison),
 * the given constant will be stored in `out`, and likewise for "default".
 *
 * If not a single match can be made to store in `out`, an error code will be
 * returned.
 *
 * @param out place to store the result of the mapping
 * @param cfg config file to get the variables from
 * @param name name of the config variable to lookup
 * @param maps array of `git_cvar_map` objects specifying the possible mappings
 * @param map_n number of mapping objects in `maps`
 * @return 0 on success, error code otherwise
 */
GIT_EXTERN(int) git_config_get_mapped(int *out, git_config *cfg, const char *name, git_cvar_map *maps, size_t map_n);

/** @} */
GIT_END_DECL
#endif
