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
that by visiting `http://atom.io/packages/my-package` to see if the package
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
`http://atom.io/packages/my-package` to see your package's page.

The `minor` option to the publish command tells apm to increment the second
digit of the version before publishing so the published version will be `0.1.0`
and the Git tag created will be `v0.1.0`.

In the future you can run `apm publish major` to publish the `1.0.0` version but
since this was the first version being published it is a good idea to start
with a minor release.

### Further Reading

* Check out [semantic versioning][semver] to learn more about versioning your
  package releases.

[atomio]: https://atom.io
[github]: https://github.com
[git-tag]: http://git-scm.com/book/en/Git-Basics-Tagging
[keychain]: http://en.wikipedia.org/wiki/Keychain_(Apple)
[repo-guide]: http://guides.github.com/overviews/desktop
[semver]: http://semver.org
[your-first-package]: your-first-package.html
