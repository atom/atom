## Publishing a Package

This guide will show you how to publish a package or theme to the
[atom.io][atomio] package registry.

Publishing a package allows other people to install it and use it.  It is a
great way to share what you've made and get feedback and contributions from
others.

### Install apm

The `apm` command line utility that ships with Atom supports publishing packages
to the atom.io registry.

Check that you have `apm` installed by running the following command in your
terminal:

```sh
apm help publish
```

You should see a message print out with details about the `apm publish` command.

If you do not, launch Atom and run the _Atom > Install Shell Commmands_ menu
to install the `apm` and `atom` commands.

### Prepare Your Package

If you've followed the steps in the [your first package][your-first-package]
doc then you should be ready to publish and you can skip to the next step.

If not, there are a few things you should check before publishing:

  * Your *package.json* file contains the accurate `name`, `description`,
    and `repository` information.
  * Your *package.json* file has a version field of `0.0.0`.
  * Your *package.json* file has an `engines` field that contains an entry
    for Atom such as: `"engines": {"atom": ">=0.50.0"}`
  * Your package is stored in a git repository that is hosted on [GitHub][github]
  * Your package has a `README.md` file at the root.
  
### Publish Your Package

Run the following commands to publish your package (this assumes your package
is located at `~/github/my-package`).

```sh
cd ~/github/my-package
apm publish minor
```

If this is the first time you are publishing, the `apm publish` command may
prompt you for your GitHub] username and password. This is required to publish
and you only need to enter this information the first time you publish. The
credentials are stored securely in your [keychain][keychain] once you login.

The `minor` option to the publish command tells apm to increment the second
digit of your version before publishing so the version published will be
`0.1.0`. You could have run `apm publish major` to publish a `1.0.0` version
but since this is your first version it is better to start with minor release.
You can read more about semantic versioning [here][semver].

The publish command also creates and pushes a [Git tag][git-tag] for this
release.  You should now see a `v0.1.0` tag in your Git repository after
publishing.


[atomio]: https://atom.io
[github]: https://github.com
[git-tag]: http://git-scm.com/book/en/Git-Basics-Tagging
[keychain]: http://en.wikipedia.org/wiki/Keychain_(Apple)
[semver]: http://semver.org
[your-first-package]: ./your-first-package.html
