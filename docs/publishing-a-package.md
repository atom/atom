## Publishing a Package

This guide will show you how to publish a package or theme to the
[atom.io][atomio] package registry.

Publishing a package allows other people to install it and use it in Atom. It
is a great way to share what you've made and get feedback and contributions from
others.

This guide assumes your package's name is `my-package` but you should pick a
better name.

### Install apm

The `apm` command line utility that ships with Atom supports publishing packages
to the atom.io registry.

Check that you have `apm` installed by running the following command in your
terminal:

```sh
apm help publish
```

You should see a message print out with details about the `apm publish` command.

If you do not, launch Atom and run the _Atom > Install Shell Commands_ menu
to install the `apm` and `atom` commands.

### Prepare Your Package

If you've followed the steps in the [your first package][your-first-package]
doc then you should be ready to publish and you can skip to the next step.

If not, there are a few things you should check before publishing:

  * Your *package.json* file has `name`, `description`, and `repository` fields.
  * Your *package.json* file has a `version` field with a value of  `"0.0.0"`.
  * Your *package.json* file has an `engines` field that contains an entry
    for Atom such as: `"engines": {"atom": ">=0.50.0"}`.
  * Your package has a `README.md` file at the root.
  * Your package is in a Git repository that has been pushed to
    [GitHub][github]. Follow [this guide][repo-guide] if your package isn't
    already on GitHub.

### Publish Your Package

Before you publish a package it is a good idea to check ahead of time if
a package with the same name has already been published to atom.io. You can do
that by visiting `https://atom.io/packages/my-package` to see if the package
already exists. If it does, update your package's name to something that is
available before proceeding.

Now let's review what the `apm publish` command does:

  1. Registers the package name on atom.io if it is being published for the
     first time.
  2. Updates the `version` field in the *package.json* file and commits it.
  3. Creates a new [Git tag][git-tag] for the version being published.
  4. Pushes the tag and current branch up to GitHub.
  5. Updates atom.io with the new version being published.

Now run the following commands to publish your package:

```sh
cd ~/github/my-package
apm publish minor
```

If this is the first package you are publishing, the `apm publish` command may
prompt you for your GitHub username and password. This is required to publish
and you only need to enter this information the first time you publish. The
credentials are stored securely in your [keychain][keychain] once you login.

:tada: Your package is now published and available on atom.io. Head on over to
`https://atom.io/packages/my-package` to see your package's page.

With `apm publish`, you can bump the version and publish by using
```sh
apm publish <version-type>
```
where `<version-type>` can be `major`, `minor` and `patch`.

The `major` option to the publish command tells apm to increment the first
digit of the version before publishing so the published version will be `1.0.0`
and the Git tag created will be `v1.0.0`.

The `minor` option to the publish command tells apm to increment the second
digit of the version before publishing so the published version will be `0.1.0`
and the Git tag created will be `v0.1.0`.

The `patch` option to the publish command tells apm to increment the third
digit of the version before publishing so the published version will be `0.0.1`
and the Git tag created will be `v0.0.1`.

Use `major` when you make a huge change, like a rewrite, or a large change to the functionality or interface.
Use `minor` when adding or removing a feature.
Use `patch` when you make a small change like a bug fix that does not add or remove features.

### Further Reading

* Check out [semantic versioning][semver] to learn more about versioning your
  package releases.
* Consult the [Atom.io package API docs][apm-rest-api] to learn more about how
  `apm` works.

[atomio]: https://atom.io
[github]: https://github.com
[git-tag]: http://git-scm.com/book/en/Git-Basics-Tagging
[keychain]: https://en.wikipedia.org/wiki/Keychain_(Apple)
[repo-guide]: http://guides.github.com/overviews/desktop
[semver]: http://semver.org
[your-first-package]: your-first-package.html
[apm-rest-api]: apm-rest-api.md
