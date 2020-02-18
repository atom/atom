# Contributing to the Atom GitHub Package

For general contributing information, see the [Atom contributing guide](https://github.com/atom/atom/blob/master/CONTRIBUTING.md); however, contributing to the GitHub package differs from contributing to other core Atom packages in some ways.

In particular, the GitHub package is under constant development by a portion of the core Atom team, and there is currently a clear vision for short- to medium-term features and enhancements. That doesn't mean we won't merge pull requests or fix other issues, but it *does* mean that you should consider discussing things with us first so that you don't spend time implementing things in a way that differs from the patterns we want to establish or build a feature that we're already working on.

Feel free to [open an issue](https://github.com/atom/github/issues) if you want to discuss anything with us. Depending on the scope and complexity of your proposal we may ask you to reframe it as a [Feature Request](/docs/how-we-work.md#new-features). If you're curious what we're working on and will be working on in the near future, you can take a look at [our most recent sprint project](https://github.com/atom/github/project) or [accepted Feature Requests](/docs/feature-requests/).

## Getting started

If you're working on the GitHub package day-to-day, it's useful to have a development environment configured to use the latest and greatest source.

1. Run an [Atom nightly build](https://github.com/atom/atom-nightly-releases) if you can. Occasionally, we depend on upstream changes in Atom that have not yet percolated through to stable builds. This will also help us notice any changes in Atom core that cause regressions. It may also be convenient to create shell aliases from `atom` to `atom-nightly` and `apm` to `apm-nightly`.
2. Install the GitHub package from its git URL:

   ```sh
   apm-nightly install atom/github
   ```

   When you run Atom in non-dev-mode (`atom-nightly .`) you'll be running the latest _merged_ code in this repository. If this isn't stable enough for day-to-day work, then we have bugs to fix :wink:
3. Link your GitHub package source in dev mode:

   ```sh
   # In the root directory of your atom/github clone
   apm-nightly link --dev .
   ```

   When you run Atom in dev mode (`atom-nightly -d .`) you'll be running your local changes. This is useful for reproducing bugs or trying out new changes live before merging them.

### Running tests

The GitHub package's specs may be run with Atom's graphical test runner or from the command line.

Launch the graphical test runner by executing `Window: Run Package Specs` from the command palette. Once a test window is visible, tests may be re-run by refreshing it with cmd-R. Toggle the developer tools within the test runner window with cmd-shift-I to see syntax errors, warnings, or the output from `console.log` debug statements.

To run tests from the command line, use:

```sh
atom-nightly --test test/
```

If this process exits with no output and a nonzero exit status, try:

```sh
atom-nightly --enable-electron-logging --test test/
```

#### Flakes

Occasionally, a test unrelated to your changes may fail sporadically. We file issues for these with the ["flaky-test" label](https://github.com/atom/github/issues?q=is%3Aissue+is%3Aopen+label%3Aflaky-test) and add a retry statement:

```js
it('passes sometimes and fails sometimes', function() {
  this.retries(5); // FLAKE

  // ..
})
```

If that isn't enough to pass the suite reliably -- for example, if a failure manipulates some global state to cause it to fail again on the retries -- skip the test until we can investigate further:

```js
// FLAKE
it.skip('breaks everything horribly when it fails', function() {
  // ..
});
```

If you wish to help make these more reliable (for which we would be eternally grateful! :pray:) we have a helper that focuses and re-runs a single `it` or `describe` block many times:

```js
it.stress(100, 'seems to break sometimes', function() {
  //
});
```

### Style and formatting

We enforce style consistency with eslint and the [fbjs-opensource](https://github.com/facebook/fbjs/tree/master/packages/eslint-config-fbjs-opensource) ruleset. Our CI will automatically verify that pull requests conform to the existing ruleset. If you wish to check your changes against our rules before you submit a pull request, run:

```sh
npm run lint
```

It's often more convenient to have Atom automatically lint and correct your source as you edit. To set this up, you'll need to install a frontend and a backend linter packages. I use [linter-eslint](https://atom.io/packages/linter-eslint) as a backend and [atom-ide-ui](https://atom.io/packages/atom-ide-ui) as a frontend.

```sh
apm-nightly install atom-ide-ui linter-eslint
```

### Coverage

Code coverage by our specs is measured by [istanbul](https://istanbul.js.org/) and reported to [Coveralls](https://coveralls.io/github/atom/github?branch=master). Links to coverage information will be available in a pull request comment and a status check. While we don't _enforce_ full coverage, we do encourage submissions to not regress our coverage percentage whenever feasible.

If you wish to preview coverage data locally, run one of:

```sh
# ASCII table output
npm run test:coverage:text

# HTML document output
npm run test:coverage:html

# lcov output
npm run test:coverage
```

Generating lcov data allows you to integrate an Atom package like [atom-lcov](https://atom.io/packages/atom-lcov) to see covered and uncovered source lines and branches with editor annotations.

If you prefer the graphical test runner, it may be altered to generate lcov coverage data by adding a command like the following to your `init.js` file:

```js
atom.commands.add('atom-workspace', {
  'me:run-package-specs': () => {
    atom.workspace.getElement().runPackageSpecs({
      env: Object.assign({}, process.env, {ATOM_GITHUB_BABEL_ENV: 'coverage'})
    });
  },
});
```

### Snapshotting

To accelerate its launch time, Atom constructs a [v8 snapshot](http://blog.atom.io/2017/04/18/improving-startup-time.html) at build time that may be loaded much more efficiently than parsing source code from scratch. As a bundled core package, the GitHub package is included in this snapshot. A tool called [electron-link](https://github.com/atom/electron-link) is used to pre-process all bundled source to prepare it for snapshot generation. This does introduce some constraints on the code constructs that may be used, however. While uncommon, it pays to be aware of the limitations this introduces.

The most commonly encountered hindrance is that you cannot reference DOM primitives, native modules, or Atom API constructs _at module require time_ - in other words, with a top-level `const` or `let` expression, or a function or the constructor of a class invoked from one:

```js
import {TextBuffer} from 'atom';

// Error: static reference to DOM methods
const node = document.createElement('div')

// Error: indirect static reference to core Atom API
function makeTextBuffer() {
  return new TextBuffer({text: 'oops'});
}
const theBuffer = newTextBuffer();

// Error: static reference to DOM in class definition
class SomeElement extends HTMLElement {
  // ...
}
```

Introducing new third-party npm package dependencies (as non-`devDependencies`) or upgrading existing ones can also result in snapshot regressions, because authors of general-purpose npm packages, naturally, don't consider this :wink:

We do have a CI job in our test matrix that verifies that a electron-link and snapshot creation succeed for each commit.

If any of these situations are _unavoidable_, individual modules _may_ be excluded from the snapshot generation process by adding them to the exclusion lists [within Atom's build scripts](https://github.com/atom/atom/blob/d29bb96c8ea09e5d9af2eb5b060227d11be2b92a/script/lib/generate-startup-snapshot.js#L27-L68) and [the GitHub package's snapshot testing script](https://github.com/atom/github/blob/3703f571e41f22c7076243abaab1a610b5b37647/test/generation.snapshot.js#L38-L43). Use this solution very sparingly, though, as it impacts Atom's startup time and adds confusion.

## Technical contribution tips

### More information

We have a growing body of documentation about the architecture and organization of our source code in the [`docs/` subdirectory](/docs) of this repository. Check there for detailed technical dives into the layers of our git integration, our React component architecture, and other information.

We use the following technologies:

* [Atom API](https://atom.io/docs) to interact with the editor.
* [React](https://reactjs.org/) is the framework that powers our view implementation.
* We interact with GitHub via its [GraphQL](https://graphql.org/) API.
* [Relay](https://github.com/facebook/relay) is a layer of glue between React and GraphQL queries that handles responsibilities like query composition and caching.
* Our tests are written with [Mocha](https://mochajs.org/) and [Chai](https://www.chaijs.com/) [_(with the "assert" style)_](https://www.chaijs.com/api/assert/). We also use [Enzyme](https://airbnb.io/enzyme/) to assert against React behavior.
* We use a [custom Babel 7 transpiler pipeline](https://github.com/atom/atom-babel7-transpiler) to write modern source with JSX, `import` statements, and other constructs unavailable natively within Atom's Node.js version.

### Updating the GraphQL Schema

Relay includes a source-level transform that depends on having a local copy of the GraphQL schema available. If you need to update the local schema to the latest version, run

```bash
GITHUB_TOKEN=abcdef0123456789 npm run fetch-schema
```

where `abcdef0123456789` is a token generated as per the [Creating a personal access token for the command line](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) help article.

Please check in the generated `graphql/schema.graphql`.

In addition, if you make any changes to any of the GraphQL queries or fragments (inside the `graphql` tagged template literals), you will need to run `npm run relay` to regenerate the statically-generated query files.

### Async Tests

Sometimes it's necessary to test async operations. For example, imagine the following test:

```javascript
// Fails
let value = 0;
setTimeout(() => value = 1)
assert.equal(value, 1)
```

You could write this test using a promise along with the `test-until` library:

```javascript
// Passes, but not ideal
import until from 'test-until'

let value = 0;
setTimeout(() => value = 1)
await until(() => value === 1)
```

However, we lose the information about the failure ('expected 0 to equal 1') and the test is harder to read (you have to parse the `until` expression to figure out what the assertion really is).

The GitHub package includes a Babel transform that makes this a little nicer; just add `.async` to your `assert` (and don't forget to `await` it):

```javascript
// Passes!
let value = 0;
setTimeout(() => value = 1)
await assert.async.equal(value, 1)
```

This transpiles into a form similar to the one above, so is asynchronous, but if the test fails, we'll still see a message that contains 'expected 0 to equal 1'.

When writing tests that depend on values that get set asynchronously, prefer `assert.async.x(...)` over other forms.
