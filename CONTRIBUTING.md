# Contributing to Atom

:+1::tada: First off, thanks for taking the time to contribute! :tada::+1:

The following is a set of guidelines for contributing to Atom and its packages, which are hosted in the [Atom Organization](https://github.com/atom) on GitHub.
These are just guidelines, not rules, use your best judgment and feel free to propose changes to this document in a pull request.

#### Table Of Contents

[What should I know before I get started?](#what-should-i-know-before-i-get-started)
  * [Code of Conduct](#code-of-conduct)
  * [Atom and Packages](#atom-and-packages)
  * [Atom Design Decisions](#design-decisions)

[How Can I Contribute?](#how-can-i-contribute)
  * [Reporting Bugs](#reporting-bugs)
  * [Suggesting Enhancements](#suggesting-enhancements)
  * [Your First Code Contribution](#your-first-code-contribution)
  * [Pull Requests](#pull-requests)

[Styleguides](#styleguides)
  * [Git Commit Messages](#git-commit-messages)
  * [JavaScript Styleguide](#javascript-styleguide)
  * [CoffeeScript Styleguide](#coffeescript-styleguide)
  * [Specs Styleguide](#specs-styleguide)
  * [Documentation Styleguide](#documentation-styleguide)

[Additional Notes](#additional-notes)
  * [Issue and Pull Request Labels](#issue-and-pull-request-labels)

## What should I know before I get started?

### Code of Conduct

This project adheres to the Contributor Covenant [code of conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.
Please report unacceptable behavior to [atom@github.com](mailto:atom@github.com).

### Atom and Packages

Atom is a large open source project—it's made up of over [200 repositories](https://github.com/atom).
When you initially consider contributing to Atom, you might be unsure about which of those 200 repositories implements the functionality you want to change or report a bug for.
This section should help you with that.

Atom is intentionally very modular.
Nearly every non-editor UI element you interact with comes from a package, even fundamental things like tabs and the status-bar.
These packages are packages in the same way that packages in the [package store](https://atom.io/packages) are packages, with one difference: they are bundled into the [default distribution](https://github.com/atom/atom/blob/10b8de6fc499a7def9b072739486e68530d67ab4/package.json#L58).

![atom-packages](https://cloud.githubusercontent.com/assets/69169/10472281/84fc9792-71d3-11e5-9fd1-19da717df079.png)

To get a sense for the packages that are bundled with Atom, you can go to Settings > Packages within Atom and take a look at the Core Packages section.

Here's a list of the big ones:

* [atom/atom](https://github.com/atom/atom) - Atom Core! The core editor component is responsible for basic text editing (e.g. cursors, selections, scrolling), text indentation, wrapping, and folding, text rendering, editor rendering, file system operations (e.g. saving), and installation and auto-updating. You should also use this repository for feedback related to the [core API](https://atom.io/docs/api/latest) and for large, overarching design proposals.
* [tree-view](https://github.com/atom/tree-view) - file and directory listing on the left of the UI.
* [fuzzy-finder](https://github.com/atom/fuzzy-finder) - the quick file opener.
* [find-and-replace](https://github.com/atom/find-and-replace) - all search and replace functionality.
* [tabs](https://github.com/atom/tabs) - the tabs for open editors at the top of the UI.
* [status-bar](https://github.com/atom/status-bar) - the status bar at the bottom of the UI.
* [markdown-preview](https://github.com/atom/markdown-preview) - the rendered markdown pane item.
* [settings-view](https://github.com/atom/settings-view) - the settings UI pane item.
* [autocomplete-plus](https://github.com/atom/autocomplete-plus) - autocompletions shown while typing. Some languages have additional packages for autocompletion functionality, such as [autocomplete-html](https://github.com/atom/autocomplete-html).
* [git-diff](https://github.com/atom/git-diff) - Git change indicators shown in the editor's gutter.
* [language-javascript](https://github.com/atom/language-javascript) - all bundled languages are packages too, and each one has a separate package `language-[name]`. Use these for feedback on syntax highlighting issues that only appear for a specific language.
* [one-dark-ui](https://github.com/atom/one-dark-ui) - the default UI styling for anything but the text editor. UI theme packages (i.e. packages with a `-ui` suffix) provide only styling and it's possible that a bundled package is responsible for a UI issue. There are other other bundled UI themes, such as [one-light-ui](https://github.com/atom/one-light-ui).
* [one-dark-syntax](https://github.com/atom/one-dark-syntax) - the default syntax highlighting styles applied for all languages. There are other other bundled syntax themes, such as [solarized-dark-syntax](https://github.com/atom/solarized-dark-syntax). You should use these packages for reporting issues that appear in many languages, but disappear if you change to another syntax theme.
* [apm](https://github.com/atom/apm) - the `apm` command line tool (Atom Package Manager). You should use this repository for any contributions related to the `apm` tool and to publishing packages.
* [atom.io](https://github.com/atom/atom.io) - the repository for feedback on the [Atom.io website](https://atom.io) and the [Atom.io package API](https://github.com/atom/atom/blob/master/docs/apm-rest-api.md) used by [apm](https://github.com/atom/apm).

There are many more, but this list should be a good starting point.
For more information on how to work with Atom's official packages, see [Contributing to Atom Packages](https://github.com/atom/atom/blob/master/docs/contributing-to-packages.md).

Also, because Atom is so extensible, it's possible that a feature you've become accustomed to in Atom or an issue you're encountering aren't coming from a bundled package at all, but rather a [community package](https://atom.io/packages) you've installed.
Each community package has its own repository too, and you should be able to find it in Settings > Packages for the packages you installed and contribute there.

### Design Decisions

When we make a significant decision in how we maintain the project and what we can or cannot support, we will be documenting them in the [atom/design-decisions repository](https://github.com/atom/design-decisions). If you have a question around how we do things, check to see if it is documented there. If it is *not* documented there, please open a new topic on [Discuss, the official Atom message board](https://discuss.atom.io) and ask your question.

## How Can I Contribute?

### Reporting Bugs

This section guides you through submitting a bug report for Atom. Following these guidelines helps maintainers and the community understand your report :pencil:, reproduce the behavior :computer: :computer:, and find related reports :mag_right:.

Before creating bug reports, please check [this list](#before-submitting-a-bug-report) as you might find out that you don't need to create one. When you are creating a bug report, please [include as many details as possible](#how-do-i-submit-a-good-bug-report). If you'd like, you can use [this template](#template-for-submitting-bug-reports) to structure the information.

#### Before Submitting A Bug Report

* **Check the [debugging guide](http://flight-manual.atom.io/hacking-atom/sections/debugging/).** You might be able to find the cause of the problem and fix things yourself. Most importantly, check if you can reproduce the problem [in the latest version of Atom](http://flight-manual.atom.io/hacking-atom/sections/debugging/#update-to-the-latest-version), if the problem happens when you run Atom in [safe mode](http://flight-manual.atom.io/hacking-atom/sections/debugging/#check-if-the-problem-shows-up-in-safe-mode), and if you can get the desired behavior by changing [Atom's or packages' config settings](http://flight-manual.atom.io/hacking-atom/sections/debugging/#check-atom-and-package-settings).
* **Check the [FAQs on the forum](https://discuss.atom.io/c/faq)** for a list of common questions and problems.
* **Determine [which repository the problem should be reported in](#atom-and-packages)**.
* **Perform a [cursory search](https://github.com/issues?q=+is%3Aissue+user%3Aatom)** to see if the problem has already been reported. If it has, add a comment to the existing issue instead of opening a new one.

#### How Do I Submit A (Good) Bug Report?

Bugs are tracked as [GitHub issues](https://guides.github.com/features/issues/). After you've determined [which repository](#atom-and-packages) your bug is related to, create an issue on that repository and provide the following information.

Explain the problem and include additional details to help maintainers reproduce the problem:

* **Use a clear and descriptive title** for the issue to identify the problem.
* **Describe the exact steps which reproduce the problem** in as many details as possible. For example, start by explaining how you started Atom, e.g. which command exactly you used in the terminal, or how you started Atom otherwise. When listing steps, **don't just say what you did, but explain how you did it**. For example, if you moved the cursor to the end of a line, explain if you used the mouse, or a keyboard shortcut or an Atom command, and if so which one?
* **Provide specific examples to demonstrate the steps**. Include links to files or GitHub projects, or copy/pasteable snippets, which you use in those examples. If you're providing snippets in the issue, use [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).
* **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
* **Explain which behavior you expected to see instead and why.**
* **Include screenshots and animated GIFs** which show you following the described steps and clearly demonstrate the problem. If you use the keyboard while following the steps, **record the GIF with the [Keybinding Resolver](https://github.com/atom/keybinding-resolver) shown**. You can use [this tool](http://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux.
* **If you're reporting that Atom crashed**, include a crash report with a stack trace from the operating system. On macOS, the crash report will be available in `Console.app` under "Diagnostic and usage information" > "User diagnostic reports". Include the crash report in the issue in a [code block](https://help.github.com/articles/markdown-basics/#multiple-lines), a [file attachment](https://help.github.com/articles/file-attachments-on-issues-and-pull-requests/), or put it in a [gist](https://gist.github.com/) and provide link to that gist.
* **If the problem is related to performance**, include a [CPU profile capture and a screenshot](http://flight-manual.atom.io/hacking-atom/sections/debugging/#diagnose-performance-problems-with-the-dev-tools-cpu-profiler) with your report.
* **If the Chrome's developer tools pane is shown without you triggering it**, that normally means that an exception was thrown. The Console tab will include an entry for the exception. Expand the exception so that the stack trace is visible, and provide the full exception and stack trace in a [code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines) and as a screenshot.
* **If the problem wasn't triggered by a specific action**, describe what you were doing before the problem happened and share more information using the guidelines below.

Provide more context by answering these questions:

* **Can you reproduce the problem in [safe mode](http://flight-manual.atom.io/hacking-atom/sections/debugging/#diagnose-runtime-performance-problems-with-the-dev-tools-cpu-profiler)?**
* **Did the problem start happening recently** (e.g. after updating to a new version of Atom) or was this always a problem?
* If the problem started happening recently, **can you reproduce the problem in an older version of Atom?** What's the most recent version in which the problem doesn't happen? You can download older versions of Atom from [the releases page](https://github.com/atom/atom/releases).
* **Can you reliably reproduce the issue?** If not, provide details about how often the problem happens and under which conditions it normally happens.
* If the problem is related to working with files (e.g. opening and editing files), **does the problem happen for all files and projects or only some?** Does the problem happen only when working with local or remote files (e.g. on network drives), with files of a specific type (e.g. only JavaScript or Python files), with large files or files with very long lines, or with files in a specific encoding? Is there anything else special about the files you are using?

Include details about your configuration and environment:

* **Which version of Atom are you using?** You can get the exact version by running `atom -v` in your terminal, or by starting Atom and running the `Application: About` command from the [Command Palette](https://github.com/atom/command-palette).
* **What's the name and version of the OS you're using**?
* **Are you running Atom in a virtual machine?** If so, which VM software are you using and which operating systems and versions are used for the host and the guest?
* **Which [packages](#atom-and-packages) do you have installed?** You can get that list by running `apm list --installed`.
* **Are you using [local configuration files](http://flight-manual.atom.io/using-atom/sections/basic-customization/)** `config.cson`, `keymap.cson`, `snippets.cson`, `styles.less`, `syntax-styles.less`, and `init.coffee` to customize Atom? If so, provide the contents of those files, preferably in a [code block](https://help.github.com/articles/markdown-basics/#multiple-lines) or with a link to a [gist](https://gist.github.com/).
* **Are you using Atom with multiple monitors?** If so, can you reproduce the problem when you use a single monitor?
* **Which keyboard layout are you using?** Are you using a US layout or some other layout?

#### Template For Submitting Bug Reports

    [Short description of problem here]

    **Reproduction Steps:**

    1. [First Step]
    2. [Second Step]
    3. [Other Steps...]

    **Expected behavior:**

    [Describe expected behavior here]

    **Observed behavior:**

    [Describe observed behavior here]

    **Screenshots and GIFs**

    ![Screenshots and GIFs which follow reproduction steps to demonstrate the problem](url)

    **Atom version:** [Enter Atom version here]
    **OS and version:** [Enter OS name and version here]

    **Installed packages:**

    [List of installed packages here]

    **Additional information:**

    * Problem can be reproduced in safe mode: [Yes/No]
    * Problem started happening recently, didn't happen in an older version of Atom: [Yes/No]
    * Problem can be reliably reproduced, doesn't happen randomly: [Yes/No]
    * Problem happens with all files and projects, not only some files or projects: [Yes/No]

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Atom, including completely new features and minor improvements to existing functionality. Following these guidelines helps maintainers and the community understand your suggestion :pencil: and find related suggestions :mag_right:.

Before creating enhancement suggestions, please check [this list](#before-submitting-an-enhancement-suggestion) as you might find out that you don't need to create one. When you are creating an enhancement suggestion, please [include as many details as possible](#how-do-i-submit-a-good-enhancement-suggestion). If you'd like, you can use [this template](#template-for-submitting-enhancement-suggestions) to structure the information.

#### Before Submitting An Enhancement Suggestion

* **Check the [debugging guide](http://flight-manual.atom.io/hacking-atom/sections/debugging/)** for tips — you might discover that the enhancement is already available. Most importantly, check if you're using [the latest version of Atom](http://flight-manual.atom.io/hacking-atom/sections/debugging/#update-to-the-latest-version) and if you can get the desired behavior by changing [Atom's or packages' config settings](http://flight-manual.atom.io/hacking-atom/sections/debugging/#check-atom-and-package-settings).
* **Check if there's already [a package](https://atom.io/packages) which provides that enhancement.**
* **Determine [which repository the enhancement should be suggested in](#atom-and-packages).**
* **Perform a [cursory search](https://github.com/issues?q=+is%3Aissue+user%3Aatom)** to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.

#### How Do I Submit A (Good) Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub issues](https://guides.github.com/features/issues/). After you've determined [which repository](#atom-and-packages) your enhancement suggestions is related to, create an issue on that repository and provide the following information:

* **Use a clear and descriptive title** for the issue to identify the suggestion.
* **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
* **Provide specific examples to demonstrate the steps**. Include copy/pasteable snippets which you use in those examples, as [Markdown code blocks](https://help.github.com/articles/markdown-basics/#multiple-lines).
* **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
* **Include screenshots and animated GIFs** which help you demonstrate the steps or point out the part of Atom which the suggestion is related to. You can use [this tool](http://www.cockos.com/licecap/) to record GIFs on macOS and Windows, and [this tool](https://github.com/colinkeenan/silentcast) or [this tool](https://github.com/GNOME/byzanz) on Linux.
* **Explain why this enhancement would be useful** to most Atom users and isn't something that can or should be implemented as a [community package](#atom-and-packages).
* **List some other text editors or applications where this enhancement exists.**
* **Specify which version of Atom you're using.** You can get the exact version by running `atom -v` in your terminal, or by starting Atom and running the `Application: About` command from the [Command Palette](https://github.com/atom/command-palette).
* **Specify the name and version of the OS you're using.**

#### Template For Submitting Enhancement Suggestions

    [Short description of suggestion]

    **Steps which explain the enhancement**

    1. [First Step]
    2. [Second Step]
    3. [Other Steps...]

    **Current and suggested behavior**

    [Describe current and suggested behavior here]

    **Why would the enhancement be useful to most users**

    [Explain why the enhancement would be useful to most users]

    [List some other text editors or applications where this enhancement exists]

    **Screenshots and GIFs**

    ![Screenshots and GIFs which demonstrate the steps or part of Atom the enhancement suggestion is related to](url)

    **Atom Version:** [Enter Atom version here]
    **OS and Version:** [Enter OS name and version here]

### Your First Code Contribution

Unsure where to begin contributing to Atom? You can start by looking through these `beginner` and `help-wanted` issues:

* [Beginner issues][beginner] - issues which should only require a few lines of code, and a test or two.
* [Help wanted issues][help-wanted] - issues which should be a bit more involved than `beginner` issues.

Both issue lists are sorted by total number of comments. While not perfect, number of comments is a reasonable proxy for impact a given change will have.

If you want to read about using Atom or developing packages in Atom, the [Atom Flight Manual](http://flight-manual.atom.io) is free and available online. You can find the source to the manual in [atom/flight-manual.atom.io](https://github.com/atom/flight-manual.atom.io).

### Pull Requests

* Include screenshots and animated GIFs in your pull request whenever possible.
* Follow the [CoffeeScript](#coffeescript-styleguide),
  [JavaScript](https://github.com/styleguide/javascript),
  and [CSS](https://github.com/styleguide/css) styleguides.
* Include thoughtfully-worded, well-structured
  [Jasmine](http://jasmine.github.io/) specs in the `./spec` folder. Run them using `apm test`. See the [Specs Styleguide](#specs-styleguide) below.
* Document new code based on the
  [Documentation Styleguide](#documentation-styleguide)
* End files with a newline.
* Place requires in the following order:
    * Built in Node Modules (such as `path`)
    * Built in Atom and Atom Shell Modules (such as `atom`, `shell`)
    * Local Modules (using relative paths)
* Place class properties in the following order:
    * Class methods and properties (methods starting with a `@`)
    * Instance methods and properties
* Avoid platform-dependent code:
    * Use `require('fs-plus').getHomeDirectory()` to get the home directory.
    * Use `path.join()` to concatenate filenames.
    * Use `os.tmpdir()` rather than `/tmp` when you need to reference the
      temporary directory.
* Using a plain `return` when returning explicitly at the end of a function.
    * Not `return null`, `return undefined`, `null`, or `undefined`

## Styleguides

### Git Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally
* When only changing documentation, include `[ci skip]` in the commit description
* Consider starting the commit message with an applicable emoji:
    * :art: `:art:` when improving the format/structure of the code
    * :racehorse: `:racehorse:` when improving performance
    * :non-potable_water: `:non-potable_water:` when plugging memory leaks
    * :memo: `:memo:` when writing docs
    * :penguin: `:penguin:` when fixing something on Linux
    * :apple: `:apple:` when fixing something on macOS
    * :checkered_flag: `:checkered_flag:` when fixing something on Windows
    * :bug: `:bug:` when fixing a bug
    * :fire: `:fire:` when removing code or files
    * :green_heart: `:green_heart:` when fixing the CI build
    * :white_check_mark: `:white_check_mark:` when adding tests
    * :lock: `:lock:` when dealing with security
    * :arrow_up: `:arrow_up:` when upgrading dependencies
    * :arrow_down: `:arrow_down:` when downgrading dependencies
    * :shirt: `:shirt:` when removing linter warnings

### JavaScript Styleguide

All JavaScript must adhere to [JavaScript Standard Style](http://standardjs.com/).

* Prefer the object spread operator (`{...anotherObj}`) to `Object.assign()`
* Inline `export`s with expressions whenever possible
  ```js
  // Use this:
  export default class ClassName {

  }

  // Instead of:
  class ClassName {

  }
  export default ClassName
  ```

### CoffeeScript Styleguide

* Set parameter defaults without spaces around the equal sign
    * `clear = (count=1) ->` instead of `clear = (count = 1) ->`
* Use spaces around operators
    * `count + 1` instead of `count+1`
* Use spaces after commas (unless separated by newlines)
* Use parentheses if it improves code clarity.
* Prefer alphabetic keywords to symbolic keywords:
    * `a is b` instead of `a == b`
* Avoid spaces inside the curly-braces of hash literals:
    * `{a: 1, b: 2}` instead of `{ a: 1, b: 2 }`
* Include a single line of whitespace between methods.
* Capitalize initialisms and acronyms in names, except for the first word, which
  should be lower-case:
  * `getURI` instead of `getUri`
  * `uriToOpen` instead of `URIToOpen`
* Use `slice()` to copy an array
* Add an explicit `return` when your function ends with a `for`/`while` loop and
  you don't want it to return a collected array.
* Use `this` instead of a standalone `@`
  * `return this` instead of `return @`

### Specs Styleguide

- Include thoughtfully-worded, well-structured
  [Jasmine](http://jasmine.github.io/) specs in the `./spec` folder.
- treat `describe` as a noun or situation.
- treat `it` as a statement about state or how an operation changes state.

#### Example

```coffee
describe 'a dog', ->
 it 'barks', ->
 # spec here
 describe 'when the dog is happy', ->
  it 'wags its tail', ->
  # spec here
```

### Documentation Styleguide

* Use [AtomDoc](https://github.com/atom/atomdoc).
* Use [Markdown](https://daringfireball.net/projects/markdown).
* Reference methods and classes in markdown with the custom `{}` notation:
    * Reference classes with `{ClassName}`
    * Reference instance methods with `{ClassName::methodName}`
    * Reference class methods with `{ClassName.methodName}`

#### Example

```coffee
# Public: Disable the package with the given name.
#
# * `name`    The {String} name of the package to disable.
# * `options` (optional) The {Object} with disable options (default: {}):
#   * `trackTime`     A {Boolean}, `true` to track the amount of time taken.
#   * `ignoreErrors`  A {Boolean}, `true` to catch and ignore errors thrown.
# * `callback` The {Function} to call after the package has been disabled.
#
# Returns `undefined`.
disablePackage: (name, options, callback) ->
```

## Additional Notes

### Issue and Pull Request Labels

This section lists the labels we use to help us track and manage issues and pull requests. Most labels are used across all Atom repositories, but some are specific to `atom/atom`.

[GitHub search](https://help.github.com/articles/searching-issues/) makes it easy to use labels for finding groups of issues or pull requests you're interested in. For example, you might be interested in [open issues across `atom/atom` and all Atom-owned packages which are labeled as bugs, but still need to be reliably reproduced](https://github.com/issues?utf8=%E2%9C%93&q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Abug+label%3Aneeds-reproduction) or perhaps [open pull requests in `atom/atom` which haven't been reviewed yet](https://github.com/issues?utf8=%E2%9C%93&q=is%3Aopen+is%3Apr+repo%3Aatom%2Fatom+comments%3A0). To help you find issues and pull requests, each label is listed with search links for finding open items with that label in `atom/atom` only and also across all Atom repositories. We  encourage you to read about [other search filters](https://help.github.com/articles/searching-issues/) which will help you write more focused queries.

The labels are loosely grouped by their purpose, but it's not required that every issue have a label from every group or that an issue can't have more than one label from the same group.

Please open an issue on `atom/atom` if you have suggestions for new labels, and if you notice some labels are missing on some repositories, then please open an issue on that repository.

#### Type of Issue and Issue State

| Label name | `atom/atom` :mag_right: | `atom`‑org :mag_right: | Description |
| --- | --- | --- | --- |
| `enhancement` | [search][search-atom-repo-label-enhancement] | [search][search-atom-org-label-enhancement] | Feature requests. |
| `bug` | [search][search-atom-repo-label-bug] | [search][search-atom-org-label-bug] | Confirmed bugs or reports that are very likely to be bugs. |
| `question` | [search][search-atom-repo-label-question] | [search][search-atom-org-label-question] | Questions more than bug reports or feature requests (e.g. how do I do X). |
| `feedback` | [search][search-atom-repo-label-feedback] | [search][search-atom-org-label-feedback] | General feedback more than bug reports or feature requests. |
| `help-wanted` | [search][search-atom-repo-label-help-wanted] | [search][search-atom-org-label-help-wanted] | The Atom core team would appreciate help from the community in resolving these issues. |
| `beginner` | [search][search-atom-repo-label-beginner] | [search][search-atom-org-label-beginner] | Less complex issues which would be good first issues to work on for users who want to contribute to Atom. |
| `more-information-needed` | [search][search-atom-repo-label-more-information-needed] | [search][search-atom-org-label-more-information-needed] | More information needs to be collected about these problems or feature requests (e.g. steps to reproduce). |
| `needs-reproduction` | [search][search-atom-repo-label-needs-reproduction] | [search][search-atom-org-label-needs-reproduction] | Likely bugs, but haven't been reliably reproduced. |
| `blocked` | [search][search-atom-repo-label-blocked] | [search][search-atom-org-label-blocked] | Issues blocked on other issues. |
| `duplicate` | [search][search-atom-repo-label-duplicate] | [search][search-atom-org-label-duplicate] | Issues which are duplicates of other issues, i.e. they have been reported before. |
| `wontfix` | [search][search-atom-repo-label-wontfix] | [search][search-atom-org-label-wontfix] | The Atom core team has decided not to fix these issues for now, either because they're working as intended or for some other reason. |
| `invalid` | [search][search-atom-repo-label-invalid] | [search][search-atom-org-label-invalid] | Issues which aren't valid (e.g. user errors). |
| `package-idea` | [search][search-atom-repo-label-package-idea] | [search][search-atom-org-label-package-idea] | Feature request which might be good candidates for new packages, instead of extending Atom or core Atom packages. |
| `wrong-repo` | [search][search-atom-repo-label-wrong-repo] | [search][search-atom-org-label-wrong-repo] | Issues reported on the wrong repository (e.g. a bug related to the [Settings View package](https://github.com/atom/settings-view) was reported on [Atom core](https://github.com/atom/atom)). |

#### Topic Categories

| Label name | `atom/atom` :mag_right: | `atom`‑org :mag_right: | Description |
| --- | --- | --- | --- |
| `windows` | [search][search-atom-repo-label-windows] | [search][search-atom-org-label-windows] | Related to Atom running on Windows. |
| `linux` | [search][search-atom-repo-label-linux] | [search][search-atom-org-label-linux] | Related to Atom running on Linux. |
| `mac` | [search][search-atom-repo-label-mac] | [search][search-atom-org-label-mac] | Related to Atom running on macOS. |
| `documentation` | [search][search-atom-repo-label-documentation] | [search][search-atom-org-label-documentation] | Related to any type of documentation (e.g. [API documentation](https://atom.io/docs/api/latest/) and the [flight manual](http://flight-manual.atom.io/)). |
| `performance` | [search][search-atom-repo-label-performance] | [search][search-atom-org-label-performance] | Related to performance. |
| `security` | [search][search-atom-repo-label-security] | [search][search-atom-org-label-security] | Related to security. |
| `ui` | [search][search-atom-repo-label-ui] | [search][search-atom-org-label-ui] | Related to visual design. |
| `api` | [search][search-atom-repo-label-api] | [search][search-atom-org-label-api] | Related to Atom's public APIs. |
| `uncaught-exception` | [search][search-atom-repo-label-uncaught-exception] | [search][search-atom-org-label-uncaught-exception] | Issues about uncaught exceptions, normally created from the [Notifications package](https://github.com/atom/notifications). |
| `crash` | [search][search-atom-repo-label-crash] | [search][search-atom-org-label-crash] | Reports of Atom completely crashing. |
| `auto-indent` | [search][search-atom-repo-label-auto-indent] | [search][search-atom-org-label-auto-indent] | Related to auto-indenting text. |
| `encoding` | [search][search-atom-repo-label-encoding] | [search][search-atom-org-label-encoding] | Related to character encoding. |
| `network` | [search][search-atom-repo-label-network] | [search][search-atom-org-label-network] | Related to network problems or working with remote files (e.g. on network drives). |
| `git` | [search][search-atom-repo-label-git] | [search][search-atom-org-label-git] | Related to Git functionality (e.g. problems with gitignore files or with showing the correct file status). |

#### `atom/atom` Topic Categories

| Label name | `atom/atom` :mag_right: | `atom`‑org :mag_right: | Description |
| --- | --- | --- | --- |
| `editor-rendering` | [search][search-atom-repo-label-editor-rendering] | [search][search-atom-org-label-editor-rendering] | Related to language-independent aspects of rendering text (e.g. scrolling, soft wrap, and font rendering). |
| `build-error` | [search][search-atom-repo-label-build-error] | [search][search-atom-org-label-build-error] | Related to problems with building Atom from source. |
| `error-from-pathwatcher` | [search][search-atom-repo-label-error-from-pathwatcher] | [search][search-atom-org-label-error-from-pathwatcher] | Related to errors thrown by the [pathwatcher library](https://github.com/atom/node-pathwatcher). |
| `error-from-save` | [search][search-atom-repo-label-error-from-save] | [search][search-atom-org-label-error-from-save] | Related to errors thrown when saving files. |
| `error-from-open` | [search][search-atom-repo-label-error-from-open] | [search][search-atom-org-label-error-from-open] | Related to errors thrown when opening files. |
| `installer` | [search][search-atom-repo-label-installer] | [search][search-atom-org-label-installer] | Related to the Atom installers for different OSes. |
| `auto-updater` | [search][search-atom-repo-label-auto-updater] | [search][search-atom-org-label-auto-updater] | Related to the auto-updater for different OSes. |
| `deprecation-help` | [search][search-atom-repo-label-deprecation-help] | [search][search-atom-org-label-deprecation-help] | Issues for helping package authors remove usage of deprecated APIs in packages. |
| `electron` | [search][search-atom-repo-label-electron] | [search][search-atom-org-label-electron] | Issues that require changes to [Electron](https://electron.atom.io) to fix or implement. |

#### Core Team Project Management

| Label name | `atom/atom` :mag_right: | `atom`‑org :mag_right: | Description |
| --- | --- | --- | --- |
| `atom` | [search][search-atom-repo-label-atom] | [search][search-atom-org-label-atom] | Topics discussed for prioritization at the next meeting of Atom core team members. |

#### Pull Request Labels

| Label name | `atom/atom` :mag_right: | `atom`‑org :mag_right: | Description
| --- | --- | --- | --- |
| `work-in-progress` | [search][search-atom-repo-label-work-in-progress] | [search][search-atom-org-label-work-in-progress] | Pull requests which are still being worked on, more changes will follow. |
| `needs-review` | [search][search-atom-repo-label-needs-review] | [search][search-atom-org-label-needs-review] | Pull requests which need code review, and approval from maintainers or Atom core team. |
| `under-review` | [search][search-atom-repo-label-under-review] | [search][search-atom-org-label-under-review] | Pull requests being reviewed by maintainers or Atom core team. |
| `requires-changes` | [search][search-atom-repo-label-requires-changes] | [search][search-atom-org-label-requires-changes] | Pull requests which need to be updated based on review comments and then reviewed again. |
| `needs-testing` | [search][search-atom-repo-label-needs-testing] | [search][search-atom-org-label-needs-testing] | Pull requests which need manual testing. |

[search-atom-repo-label-enhancement]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aenhancement
[search-atom-org-label-enhancement]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aenhancement
[search-atom-repo-label-bug]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Abug
[search-atom-org-label-bug]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Abug
[search-atom-repo-label-question]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aquestion
[search-atom-org-label-question]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aquestion
[search-atom-repo-label-feedback]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Afeedback
[search-atom-org-label-feedback]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Afeedback
[search-atom-repo-label-help-wanted]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Ahelp-wanted
[search-atom-org-label-help-wanted]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Ahelp-wanted
[search-atom-repo-label-beginner]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Abeginner
[search-atom-org-label-beginner]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Abeginner
[search-atom-repo-label-more-information-needed]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Amore-information-needed
[search-atom-org-label-more-information-needed]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Amore-information-needed
[search-atom-repo-label-needs-reproduction]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aneeds-reproduction
[search-atom-org-label-needs-reproduction]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aneeds-reproduction
[search-atom-repo-label-triage-help-needed]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Atriage-help-needed
[search-atom-org-label-triage-help-needed]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Atriage-help-needed
[search-atom-repo-label-windows]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Awindows
[search-atom-org-label-windows]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Awindows
[search-atom-repo-label-linux]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Alinux
[search-atom-org-label-linux]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Alinux
[search-atom-repo-label-mac]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Amac
[search-atom-org-label-mac]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Amac
[search-atom-repo-label-documentation]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Adocumentation
[search-atom-org-label-documentation]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Adocumentation
[search-atom-repo-label-performance]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aperformance
[search-atom-org-label-performance]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aperformance
[search-atom-repo-label-security]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Asecurity
[search-atom-org-label-security]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Asecurity
[search-atom-repo-label-ui]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aui
[search-atom-org-label-ui]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aui
[search-atom-repo-label-api]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aapi
[search-atom-org-label-api]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aapi
[search-atom-repo-label-crash]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Acrash
[search-atom-org-label-crash]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Acrash
[search-atom-repo-label-auto-indent]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aauto-indent
[search-atom-org-label-auto-indent]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aauto-indent
[search-atom-repo-label-encoding]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aencoding
[search-atom-org-label-encoding]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aencoding
[search-atom-repo-label-network]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Anetwork
[search-atom-org-label-network]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Anetwork
[search-atom-repo-label-uncaught-exception]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Auncaught-exception
[search-atom-org-label-uncaught-exception]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Auncaught-exception
[search-atom-repo-label-git]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Agit
[search-atom-org-label-git]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Agit
[search-atom-repo-label-blocked]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Ablocked
[search-atom-org-label-blocked]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Ablocked
[search-atom-repo-label-duplicate]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aduplicate
[search-atom-org-label-duplicate]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aduplicate
[search-atom-repo-label-wontfix]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Awontfix
[search-atom-org-label-wontfix]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Awontfix
[search-atom-repo-label-invalid]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Ainvalid
[search-atom-org-label-invalid]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Ainvalid
[search-atom-repo-label-package-idea]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Apackage-idea
[search-atom-org-label-package-idea]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Apackage-idea
[search-atom-repo-label-wrong-repo]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Awrong-repo
[search-atom-org-label-wrong-repo]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Awrong-repo
[search-atom-repo-label-editor-rendering]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aeditor-rendering
[search-atom-org-label-editor-rendering]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aeditor-rendering
[search-atom-repo-label-build-error]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Abuild-error
[search-atom-org-label-build-error]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Abuild-error
[search-atom-repo-label-error-from-pathwatcher]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aerror-from-pathwatcher
[search-atom-org-label-error-from-pathwatcher]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aerror-from-pathwatcher
[search-atom-repo-label-error-from-save]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aerror-from-save
[search-atom-org-label-error-from-save]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aerror-from-save
[search-atom-repo-label-error-from-open]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aerror-from-open
[search-atom-org-label-error-from-open]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aerror-from-open
[search-atom-repo-label-installer]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Ainstaller
[search-atom-org-label-installer]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Ainstaller
[search-atom-repo-label-auto-updater]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aauto-updater
[search-atom-org-label-auto-updater]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aauto-updater
[search-atom-repo-label-deprecation-help]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Adeprecation-help
[search-atom-org-label-deprecation-help]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Adeprecation-help
[search-atom-repo-label-electron]: https://github.com/issues?q=is%3Aissue+repo%3Aatom%2Fatom+is%3Aopen+label%3Aelectron
[search-atom-org-label-electron]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aelectron
[search-atom-repo-label-atom]: https://github.com/issues?q=is%3Aopen+is%3Aissue+repo%3Aatom%2Fatom+label%3Aatom
[search-atom-org-label-atom]: https://github.com/issues?q=is%3Aopen+is%3Aissue+user%3Aatom+label%3Aatom
[search-atom-repo-label-work-in-progress]: https://github.com/pulls?q=is%3Aopen+is%3Apr+repo%3Aatom%2Fatom+label%3Awork-in-progress
[search-atom-org-label-work-in-progress]: https://github.com/pulls?q=is%3Aopen+is%3Apr+user%3Aatom+label%3Awork-in-progress
[search-atom-repo-label-needs-review]: https://github.com/pulls?q=is%3Aopen+is%3Apr+repo%3Aatom%2Fatom+label%3Aneeds-review
[search-atom-org-label-needs-review]: https://github.com/pulls?q=is%3Aopen+is%3Apr+user%3Aatom+label%3Aneeds-review
[search-atom-repo-label-under-review]: https://github.com/pulls?q=is%3Aopen+is%3Apr+repo%3Aatom%2Fatom+label%3Aunder-review
[search-atom-org-label-under-review]: https://github.com/pulls?q=is%3Aopen+is%3Apr+user%3Aatom+label%3Aunder-review
[search-atom-repo-label-requires-changes]: https://github.com/pulls?q=is%3Aopen+is%3Apr+repo%3Aatom%2Fatom+label%3Arequires-changes
[search-atom-org-label-requires-changes]: https://github.com/pulls?q=is%3Aopen+is%3Apr+user%3Aatom+label%3Arequires-changes
[search-atom-repo-label-needs-testing]: https://github.com/pulls?q=is%3Aopen+is%3Apr+repo%3Aatom%2Fatom+label%3Aneeds-testing
[search-atom-org-label-needs-testing]: https://github.com/pulls?q=is%3Aopen+is%3Apr+user%3Aatom+label%3Aneeds-testing

[beginner]:https://github.com/issues?utf8=%E2%9C%93&q=is%3Aopen+is%3Aissue+label%3Abeginner+label%3Ahelp-wanted+user%3Aatom+sort%3Acomments-desc
[help-wanted]:https://github.com/issues?q=is%3Aopen+is%3Aissue+label%3Ahelp-wanted+user%3Aatom+sort%3Acomments-desc
