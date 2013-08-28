**Polish the user experience**

First and foremost, Atom is a **product**. Atom needs to feel familiar and
inviting. This includes a solid introductory experience and parity with the most
important features of Sublime Text.

  * First launch UI and flow (actions below should be easily discoverable)
    * Create a new file
    * Open a project and edit an existing file
    * Install a package
    * Change settings (adjust theme, change key bindings, set config options)
    * How to use command P
  * Use collaboration internally
  * How and where to edit keyBinding should be obvious to new users
  * Finish find and replace in buffer/project
  * Atom should start < 300ms
  * Match Sublime's multiple selection functionality (#523)
  * Fix softwrap bugs
  * Menus & Context menus
  * Track usage/engagement of our users (make this opted in?)
  * Windows support
  * Reliably and securely auto-update and list what's new
  * Secure access to the keychain (don't give every package access to the keychain)
  * Secure access to GitHub (each package can ask to have it's own oauth token)
  * Don't crash when opening/editing large (> 10Mb) files
  * Send js and native crash reports to a remote server

**Lay solid groundwork for a package and theme ecosystem**

Extensibility is one of Atom's key value propositions, so a smooth experience
for creating and maintaining packages is just as important as the user
experience. The package development, dependency and publishing workflow needs to
be solid. We also want to have a mechanism for clearly communicating with
package authors about breaking API changes.

  * Finish APM backend (integrate with GitHub Releases)
  * Streamline Dev workflow
    * `apm create` - create package scaffolding
    * `apm test` - so users can run focused package tests
    * `apm publish` - should integrate release best practices (ie npm version)
  * Determine which classes and methods should be included in the public API
  * Users can find/install/update/fork existing packages and themes
  
**Tighten up the view layer**
Our current approach to the view layer need some improvement. We want to
actively promote the use of the M-V-VM design pattern, provide some declarative
event binding mechanisms in the view layer, and improve the performance of the
typical package specs. We don't want the current approach to be used as an
example in a bunch of new packages, so it's important to improve it now.

  * Add marker view API

**Get atom.io online with some exciting articles and documentation**
We'd love to send our private alpha candidates to a nice site with information
about what Atom is, the philosophies and technologies behind it, and guidance
for how to get started.

  * Design and create www.atom.io
    * Guides
      * Theme & Package creation guide
    * Full API per release tag
    * Changelog per release
    * Explanation of features
    * Explain Semver and general plans for the future (reassure developers we care about them)
    * General Values/Goals
  * Make docs accessible from Atom
  * Community/contribution guidelines
    * Is all communication to be done through issues?
    * When should you publish a plugin?
    * Do we need to vet plugins from a security perspective?
