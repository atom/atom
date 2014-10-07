# Atom.io package and update API

This guide describes the web API used by [apm](https://github.com/atom/apm) and
Atom. The vast majority of use cases are met by the `apm` command-line tool,
which does other useful things like incrementing your version in `package.json`
and making sure you have pushed your git tag. In fact, Atom itself shells out to
`apm` rather than hitting the API directly. If you're curious about how Atom
uses `apm`, see the [PackageManager class](https://github.com/atom/settings-view/blob/master/lib/package-manager.coffee)
in the `settings-view` package.

*This API should be considered pre-release and is subject to change (though significant breaking changes are unlikely).*

### Authorization

For calls to the API that require authentication, provide a valid token from your
[Atom.io account page](https://atom.io/account) in the `Authorization` header.

### Media type

All requests that take parameters require `application/json`.

# API Resources

## Packages

### Listing packages

#### GET /api/packages

Parameters:

- **page** (optional)
- **sort** (optional, values: `created_at`, `updated_at`, `downloads`)
- **direction** (optional, values: `asc`, `desc`)

Returns a list of all packages in the following format:
```json
  [
    {
      "releases": {
        "latest": "0.6.0"
      },
      "name": "thedaniel-test-package",
      "repository": {
        "type": "git",
        "url": "https://github.com/thedaniel/test-package"
      }
    },
    ...
  ]
```

Results are paginated 30 at a time, and links to the next and last pages are
provided in the `Link` header:

```
Link: <https://www.atom.io/api/packages?page=1>; rel="self",
      <https://www.atom.io/api/packages?page=41>; rel="last",
      <https://www.atom.io/api/packages?page=2>; rel="next"
```

By default, results are sorted by download count, descending.

#### GET /api/packages/search

Parameters:

- **q** String query to search
- **sort** (optional, values: `created_at`, `updated_at`, `downloads`)
- **direction** (optional, values: `asc`, `desc`)

Returns a list of all packages in the same format as `/api/packages`.

By default, results sorted by relevance to search query.

### Showing package details

#### GET /api/packages/:package_name

Returns package details and versions for a single package

Parameters:

- **engine** (optional) - Only show packages with versions compatible with this
  Atom version. Must be valid [SemVer](http://semver.org).

Returns:

```json
  {
    "releases": {
      "latest": "0.6.0"
    },
    "name": "thedaniel-test-package",
    "repository": {
      "type": "git",
      "url": "https://github.com/thedaniel/test-package"
    },
    "versions": [
      (see single version output below)
      ...,
    ]
  }
```

### Creating a package

#### POST /api/packages

Create a new package; requires authentication.

The name and version will be fetched from the `package.json`
file in the specified repository. The authenticating user *must* have access
to the indicated repository.

When a package is created, a release hook is registered with GitHub for package
version creation.

Parameters:

- **repository** - String. The repository containing the plugin, in the form "owner/repo"

Returns:

- **201** - Successfully created, returns created package.
- **400** - Repository is inaccessible, nonexistent, not an atom package. Possible
  error messages include:
  - That repo does not exist, isn't an atom package, or atombot does not have access
  - The package.json at owner/repo isn't valid
- **409** - A package by that name already exists

### Deleting a package

#### DELETE /api/packages/:package_name

Delete a package; requires authentication.

Returns:

- **204** - Success
- **400** - Repository is inaccessible
- **401** - Unauthorized

### Renaming a package

Packages are renamed by publishing a new version with the name changed in `package.json`
See [Creating a new package version](#creating-a-new-package-version) for details.

Requests made to the previous name will forward to the new name.

### Package Versions

#### GET /api/packages/:package_name/versions/:version_name

Returns `package.json` with `dist` key added for e.g. tarball download:

```json
  {
    "bugs": {
      "url": "https://github.com/thedaniel/test-package/issues"
    },
    "dependencies": {
      "async": "~0.2.6",
      "pegjs": "~0.7.0",
      "season": "~0.13.0"
    },
    "description": "Expand snippets matching the current prefix with `tab`.",
    "dist": {
      "tarball": "https://codeload.github.com/..."
    },
    "engines": {
      "atom": "*"
    },
    "main": "./lib/snippets",
    "name": "thedaniel-test-package",
    "publishConfig": {
      "registry": "https://...",
    },
    "repository": {
      "type": "git",
      "url": "https://github.com/thedaniel/test-package.git"
    },
    "version": "0.6.0"
  }
```


### Creating a new package version

#### POST /api/packages/:package_name/versions

Creates a new package version from a git tag; requires authentication. If `rename`
is not `true`, the `name` field in `package.json` *must* match the current package
name.

#### Parameters

- **tag** - A git tag for the version you'd like to create. It's important to note
  that the version name will not be taken from the tag, but from the `version`
  key in the `package.json` file at that ref. The authenticating user *must* have
  access to the package repository.
- **rename** - Boolean indicating whether this version contains a new name for the package.

#### Returns

- **201** - Successfully created. Returns created version.
- **400** - Git tag not found / Repository inaccessible / package.json invalid
- **409** - Version exists

### Deleting a version

#### DELETE /api/packages/:package_name/versions/:version_name

Deletes a package version; requires authentication.

Note that a version cannot be republished with a different tag if it is deleted.
If you need to delete the latest version of a package for e.g. security reasons,
you'll need to increment the version when republishing.

Returns 204 No Content


## Stars

### Listing user stars

#### GET /api/users/:login/stars

List a user's starred packages.

Return value is similar to **GET /api/packages**

#### GET /api/stars

List the authenticated user's starred packages; requires authentication.

Return value is similar to **GET /api/packages**

### Starring a package

#### POST /api/packages/:name/star

Star a package; requires authentication.

Returns a package.

### Unstarring a package

#### DELETE /api/packages/:name/star

Unstar a package; requires authentication.

Returns 204 No Content.

### Listing a package's stargazers

#### GET /api/packages/:name/stargazers

List the users that have starred a package.

Returns a list of user objects:

```json
[
  {"login":"aperson"},
  {"login":"anotherperson"},
]
```

## Atom updates

### Listing Atom updates

#### GET /api/updates

Atom update feed, following the format expected by [Squirrel](https://github.com/Squirrel/).

Returns:

```json
{
    "name": "0.96.0",
    "notes": "[HTML release notes]",
    "pub_date": "2014-05-19T15:52:06.000Z",
    "url": "https://www.atom.io/api/updates/download"
}
```
