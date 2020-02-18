# Git interactions

Describe the various classes involved in interacting with git and what kinds of behavior to find in each.

The GitHub package uses [dugite](https://github.com/desktop/dugite) to execute git commands as subprocesses. Dugite bundles a minimal git distribution built from the primary git tree. This has the advantages that we ensure compatibility and consistency with native git operations and that Atom users don't need to download and install git themselves, at the cost of a larger download size (by about 30MB).

## WorkerManager and Workers

When a subprocess is spawned from Node.js, the resident set of memory pages needs to be copied into the new process' address space. This copy happens _synchronously_ even when using asynchronous variants of functions from the `child_process` module, and from an Electron process, the RSS can become quite large. Because this blocks the event loop it locks the processing of UI events. This leads to a quite noticeable degradation of Atom's performance when spawning a large number of subprocesses, manifesting as stuttering and locking.

To work around this, the GitHub package creates a secondary Electron renderer process, with no visible window, and uses an IPC request/response protocol to perform subprocess creation within that process instead. The sidecar renderer process tracks a running average of the duration of the synchronous portion of the spawn calls it performs and, if it degrades too much, self-destructs and re-launches itself. The IPC and process creation overhead are easily cancelled out by the smoothing that this brings.

The sidecar process execution is implemented on the host process side by the [`WorkerManager`, `Worker`, `RendererProcess` and `Operation`](/lib/worker-manager.js) classes. The client side is implemented by [`worker.js`](/lib/worker.js), which is loaded by [`renderer.html`](/lib/renderer.html).

If you wish to see the sidecar renderer process window with its diagnostic information, set the environment variable `ATOM_GITHUB_SHOW_RENDERER_WINDOW` before launching Atom. To opt out of the sidecar process entirely (for CI tests, for example) set `ATOM_GITHUB_INLINE_GIT_EXEC`.

## Git Shell Out Strategy

The [`GitShellOutStrategy`](/lib/git-shell-out-strategy.js) class is responsible for composing the actual commands and arguments passed to `git` subprocesses, either through dugite directly or through the `WorkerManager`. An asynchronous queue implementation manages git command concurrency: commands that acquire a lock on the git index - write operations - run serially, but read operations are permitted to execute in parallel.

Command arguments are injected to override problematic git configuration options that could break our ability to parse git's output for certain commands, and to register Atom's GitPromptServer as a handler for SSH, https auth, and GPG credential requests.

It also measures performance data and reports diagnostics to the dev console if the appropriate Atom configuration key is set.

`GitShellOutStrategy` methods communicate by means of plain JavaScript objects and strings. They are very low-level; each method calls a single `git` command and reports any output with minimal postprocessing or parsing.

> Historical note: `GitShellOutStrategy` and [`CompositeGitStrategy`](/lib/composite-git-strategy.js) are the remnants of exploratory work to back some operations by calls to [libgit2](https://libgit2.org/) by means of [nodegit](https://www.npmjs.com/package/nodegit). The performance and stability cost ended up not being worth it for us.

## GitPromptServer

A [`GitTempDir`](/lib/git-temp-dir.js) and [`GitPromptServer`](/lib/git-prompt-server.js) are created during certain `GitShellOutStrategy` methods to service any credential requests that git requires. We handle passphrase requests by:

* Creating a temporary directory.
* Copying a set of [helper scripts](/bin) to the temporary directory and, on non-Windows platforms, marking them executable. These scripts are `/bin/sh` scripts that execute their corresponding JavaScript modules as Node.js processes with the current Electron binary (by setting `ELECTRON_RUN_AS_NODE=1`), propagating along any arguments.
* A UNIX domain socket or named pipe is created within the temporary directory. :memo: _Note that UNIX domain socket paths are limited to a maximum of 107 characters for [reasons](https://unix.stackexchange.com/questions/367008/why-is-socket-path-length-limited-to-a-hundred-chars). On platforms where this is an issue, the temporary directory name must be short enough to accommodate this._
* The host Atom process creates a server listening on the UNIX domain socket or named pipe.
* The `git` subprocess is spawned, configured to use the copied helper scripts as credential handlers.
  * For HTTPS authentication, the argument `-c credential.helper=...` is used to ensure [`bin/git-credential-atom.js`](/bin/git-credential-atom.js) is used as the highest-priority [git credential helper](https://git-scm.com/docs/git-credential). `git-credential-atom.js` implements git's credential helper protocol by:
    1. Executing any credential helpers configured by your system git. Some git installations are already configured to read from the OS keychain, but dugite's bundled git won't respect configution from your system installation.
    2. Reading an Atom-specific key from your OS keychain. If you have logged in to the GitHub tab, your OAuth token will be found here as well.
    3. If neither of those are successful, connect to the socket opened by `GitPromptServer` and write a JSON query.
    4. When a JSON reply is received, it is written back to git on stdout.
    5. If git reports that the credential is accepted, and if the "remember me" flag was set in the query reply, the provided password will be written to the OS keychain.
    6. If git reports that the credential was rejected, the provided password will be deleted from the OS keychain.
  * To unlock SSH keys, the environment variables `SSH_ASKPASS` and `GIT_ASKPASS` are set to the path to the script that runs [`git-askpass-atom.js`](bin/git-askpass-atom.js). `DISPLAY` is also set to a non-empty value so that `ssh` will respect `SSH_ASKPASS`. `git-askpass-atom.js` reads its prompt from its process arguments, attempts to execute the system askpass if one is present, and falls back to querying the `GitPromptServer` if that does not succeed. Its passphrase is written to stdout.
  * For GPG passphrases, `-c gpg.program=...` is set to [`bin/gpg-wrapper.sh`](/bin/gpg-wrapper.sh). `gpg-wrapper.sh` attempts to use the `--passphrase-fd` argument to GPG to prompt for your passphrase by reading and writing to file descriptor 3. Unfortunately, more recent versions of GPG not longer respect this argument (and use a much more complicated architecture for pinentry configuration through `gpg-agent`,) so for now native GPG pinentry programs must often be used.
  * On Linux, `GIT_SSH_COMMAND` is set to [`bin/linux-ssh-wrapper.sh`](/bin/linux-ssh-wrapper.sh), a wrapper script that runs the ssh command in a new process group. Otherwise, `ssh` will ignore `SSH_ASKPASS` and insist on prompting on the tty you used to launch Atom.

## Repository

[`Repository`](/lib/models/repository.js) is the higher-level model class that most of the view layer uses to interact with a git repository.

Repositories are stateful: when created with a path, they are **loading**, after which they may become **present** if a `.git` directory is found, or **empty** otherwise. They may also be **absent** if you don't even have a path. **Empty** repositories may transition to **initializing** or **cloning** if a `git init` or `git clone` operation is begun. For more details about Repository states, see [the `lib/models/repository-states/` README](/lib/models/repository-states/).

Repository instances mostly delegate operations to their current _state instance_. (This delegation is not automatic; there is [an explicit list](/lib/models/repository.js#L265-L363) of methods that are delegated, which must be updated if new functionality is added.) However, Repositories do directly implement methods for:

* Composite operations that chain together several one-git-command pieces from its state, and
* Alias operations that re-interpret the result from a single primitive command in different ways.

### Present

[`Present`](/lib/models/repository-states/present.js) is the most often-used state because it represents a `Repository` that's actually there to operate on. Present has methods for all primitive `git` operations, implemented as calls to the active git strategy.

Present's methods communicate with a language of model objects: [`Branch`](/lib/models/branch.js), [`Commit`](/lib/models/commit.js), [`FilePatch`](/lib/models/file-patch.js).

Present is responsible for caching the results of commands that read state and for selectively busting invalidated cache keys based on write operations that are performed or filesystem activity observed within the `.git` directory.

To write a method that reads from the cache, first locate or create a new cache key. These are static `CacheKey` objects found within [the `Key` structure](/lib/models/repository-states/present.js#L1072-L1165). If the git operation depends on some of its operations, you may need to introduce a function that creates a unique cache key based on its input.

```js
const Keys = {
  // Single static key that does not depend on input.
  lastCommit: new CacheKey('last-commit'),

  // A group of related cache keys.
  config: {
    // Generate a key based on a command argument.
    // The created key belongs to two "groups" that can be used to invalidate it.
    oneWith: (setting, local) => {
      return new CacheKey(`config:${setting}:${local}`, ['config', `config:${local}`]);
    },

    // Used to invalidate *all* cache entries belonging to a given group at once.
    all: new GroupKey('config'),
  },
}
```

Then write your method to call `this.cache.getOrSet()` with the appropriate key or keys as its first argument:

```js
getConfig(option, local = false) {
  return this.cache.getOrSet(Keys.config.oneWith(option, local), () => {
    return this.git().getConfig(option, {local});
  });
}
```

To write a method that may invalidate the cache, wrap it with the `invalidate()` method:

```js
setConfig(setting, value, options) {
  return this.invalidate(
    () => Keys.config.eachWithSetting(setting),
    () => this.git().setConfig(setting, value, options),
  );
}
```

To respond appropriately to git commands performed externally, be sure to also add invalidation logic to the [`Present::observeFilesystemChange()`](/lib/models/repository-states/present.js#L94-L160).

### State

[`State`](/lib/models/repository-states/state.js) is the root class of the hierarchy used to implement Repository states. It provides implementations of all expected state methods that do nothing and return an appropriate null object.

When adding new git functionality, be sure to provide an appropriate null version of your methods here, so that newly added methods will work properly on Repositories that are loading, empty, or absent.
