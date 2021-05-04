# Atom Core Packages

This folder contains core packages that are bundled with Atom releases.  Not all Atom core packages are kept here; please
see the table below for the location of every core Atom package.

> **NOTE:** There is an ongoing effort to migrate more Atom packages from their individual repositories to this folder.
See [RFC 003](https://github.com/atom/atom/blob/master/docs/rfcs/003-consolidate-core-packages.md) for more details.

| Package | Where to find it | Migration issue |
|---------|------------------|-----------------|
| **about** | [`./about`](./about) | [#17832](https://github.com/atom/atom/issues/17832) |
| **atom-dark-syntax** | [`./atom-dark-syntax`](./atom-dark-syntax) | [#17849](https://github.com/atom/atom/issues/17849) |
| **atom-dark-ui** | [`./atom-dark-ui`](./atom-dark-ui) | [#17850](https://github.com/atom/atom/issues/17850) |
| **atom-light-syntax** | [`./atom-light-syntax`](./atom-light-syntax) | [#17851](https://github.com/atom/atom/issues/17851) |
| **atom-light-ui** | [`./atom-light-ui`](./atom-light-ui) | [#17852](https://github.com/atom/atom/issues/17852) |
| **autocomplete-atom-api** | [`atom/autocomplete-atom-api`][autocomplete-atom-api] |  |
| **autocomplete-css** | [`atom/autocomplete-css`][autocomplete-css] |  |
| **autocomplete-html** | [`atom/autocomplete-html`][autocomplete-html] |  |
| **autocomplete-plus** | [`atom/autocomplete-plus`][autocomplete-plus] |  |
| **autocomplete-snippets** | [`atom/autocomplete-snippets`][autocomplete-snippets] |  |
| **autoflow** | [`./autoflow`](./autoflow) | [#17833](https://github.com/atom/atom/issues/17833) |
| **autosave** | [`atom/autosave`][autosave] | [#17834](https://github.com/atom/atom/issues/17834) |
| **background-tips** | [`atom/background-tips`][background-tips] | [#17835](https://github.com/atom/atom/issues/17835) |
| **base16-tomorrow-dark-theme** | [`./base16-tomorrow-dark-theme`](./base16-tomorrow-dark-theme) | [#17836](https://github.com/atom/atom/issues/17836) |
| **base16-tomorrow-light-theme** | [`./base16-tomorrow-light-theme`](./base16-tomorrow-light-theme) | [#17837](https://github.com/atom/atom/issues/17837) |
| **bookmarks** | [`atom/bookmarks`][bookmarks] | [#18273](https://github.com/atom/atom/issues/18273) |
| **bracket-matcher** | [`atom/bracket-matcher`][bracket-matcher] |  |
| **command-palette** | [`atom/command-palette`][command-palette] |  |
| **dalek** | [`./dalek`](./dalek) | [#17838](https://github.com/atom/atom/issues/17838) |
| **deprecation-cop** | [`./deprecation-cop`](./deprecation-cop) | [#17839](https://github.com/atom/atom/issues/17839) |
| **dev-live-reload** | [`./dev-live-reload`](dev-live-reload) | [#17840](https://github.com/atom/atom/issues/17840) |
| **encoding-selector** | [`atom/encoding-selector`][encoding-selector] | [#17841](https://github.com/atom/atom/issues/17841) |
| **exception-reporting** | [`./exception-reporting`](./exception-reporting) | [#17842](https://github.com/atom/atom/issues/17842) |
| **find-and-replace** | [`atom/find-and-replace`][find-and-replace] |  |
| **fuzzy-finder** | [`atom/fuzzy-finder`][fuzzy-finder] |  |
| **github** | [`atom/github`][github] |  |
| **git-diff** | [`./git-diff`](./git-diff) | [#17843](https://github.com/atom/atom/issues/17843) |
| **go-to-line** | [`./go-to-line`](./go-to-line) | [#17844](https://github.com/atom/atom/issues/17844) |
| **grammar-selector** | [`./grammar-selector`](./grammar-selector) | [#17845](https://github.com/atom/atom/issues/17845) |
| **image-view** | [`atom/image-view`][image-view] | [#18274](https://github.com/atom/atom/issues/18274) |
| **incompatible-packages** | [`./incompatible-packages`](./incompatible-packages) | [#17846](https://github.com/atom/atom/issues/17846) |
| **keybinding-resolver** | [`atom/keybinding-resolver`][keybinding-resolver] | [#18275](https://github.com/atom/atom/issues/18275) |
| **language-c** | [`atom/language-c`][language-c] |  |
| **language-clojure** | [`atom/language-clojure`][language-clojure] |  |
| **language-coffee-script** | [`atom/language-coffee-script`][language-coffee-script] |  |
| **language-csharp** | [`atom/language-csharp`][language-csharp] |  |
| **language-css** | [`atom/language-css`][language-css] |  |
| **language-gfm** | [`atom/language-gfm`][language-gfm] |  |
| **language-git** | [`atom/language-git`][language-git] |  |
| **language-go** | [`atom/language-go`][language-go] |  |
| **language-html** | [`atom/language-html`][language-html] |  |
| **language-hyperlink** | [`atom/language-hyperlink`][language-hyperlink] |  |
| **language-java** | [`atom/language-java`][language-java] |  |
| **language-javascript** | [`atom/language-javascript`][language-javascript] |  |
| **language-json** | [`atom/language-json`][language-json] |  |
| **language-less** | [`atom/language-less`][language-less] |  |
| **language-make** | [`atom/language-make`][language-make] |  |
| **language-mustache** | [`atom/language-mustache`][language-mustache] |  |
| **language-objective-c** | [`atom/language-objective-c`][language-objective-c] |  |
| **language-perl** | [`atom/language-perl`][language-perl] |  |
| **language-php** | [`atom/language-php`][language-php] |  |
| **language-property-list** | [`atom/language-property-list`][language-property-list] |  |
| **language-python** | [`atom/language-python`][language-python] |  |
| **language-ruby** | [`atom/language-ruby`][language-ruby] |  |
| **language-ruby-on-rails** | [`atom/language-ruby-on-rails`][language-ruby-on-rails] |  |
| **language-rust-bundled** | [`./language-rust-bundled`](./language-rust-bundled) |  |
| **language-sass** | [`atom/language-sass`][language-sass] |  |
| **language-shellscript** | [`atom/language-shellscript`][language-shellscript] |  |
| **language-source** | [`atom/language-source`][language-source] |  |
| **language-sql** | [`atom/language-sql`][language-sql] |  |
| **language-text** | [`atom/language-text`][language-text] |  |
| **language-todo** | [`atom/language-todo`][language-todo] |  |
| **language-toml** | [`atom/language-toml`][language-toml] |  |
| **language-typescript** | [`atom/language-typescript`][language-typescript] |  |
| **language-xml** | [`atom/language-xml`][language-xml] |  |
| **language-yaml** | [`atom/language-yaml`][language-yaml] |  |
| **line-ending-selector** | [`./packages/line-ending-selector`](./line-ending-selector) | [#17847](https://github.com/atom/atom/issues/17847) |
| **link** | [`./link`](./link) | [#17848](https://github.com/atom/atom/issues/17848) |
| **markdown-preview** | [`atom/markdown-preview`][markdown-preview] |  |
| **metrics** | [`atom/metrics`][metrics] | [#18276](https://github.com/atom/atom/issues/18276) |
| **notifications** | [`atom/notifications`][notifications] | [#18277](https://github.com/atom/atom/issues/18277) |
| **one-dark-syntax** | [`./one-dark-syntax`](./one-dark-syntax) | [#17853](https://github.com/atom/atom/issues/17853) |
| **one-dark-ui** | [`./one-dark-ui`](./one-dark-ui) | [#17854](https://github.com/atom/atom/issues/17854) |
| **one-light-syntax** | [`./one-light-syntax`](./one-light-syntax) | [#17855](https://github.com/atom/atom/issues/17855) |
| **one-light-ui** | [`./one-light-ui`](./one-light-ui) | [#17856](https://github.com/atom/atom/issues/17856) |
| **open-on-github** | [`atom/open-on-github`][open-on-github] | [#18278](https://github.com/atom/atom/issues/18278) |
| **package-generator** | [`atom/package-generator`][package-generator] | [#18279](https://github.com/atom/atom/issues/18279) |
| **settings-view** | [`atom/settings-view`][settings-view] |  |
| **snippets** | [`atom/snippets`][snippets] |  |
| **solarized-dark-syntax** | [`./solarized-dark-syntax`](./solarized-dark-syntax) | [#18280](https://github.com/atom/atom/issues/18280) |
| **solarized-light-syntax** | [`./solarized-light-syntax`](./solarized-light-syntax) | [#18281](https://github.com/atom/atom/issues/18281) |
| **spell-check** | [`atom/spell-check`][spell-check] |  |
| **status-bar** | [`atom/status-bar`][status-bar] | [#18282](https://github.com/atom/atom/issues/18282) |
| **styleguide** | [`atom/styleguide`][styleguide] | [#18283](https://github.com/atom/atom/issues/18283) |
| **symbols-view** | [`atom/symbols-view`][symbols-view] |  |
| **tabs** | [`atom/tabs`][tabs] |  |
| **timecop** | [`atom/timecop`][timecop] | [#18272](https://github.com/atom/atom/issues/18272) |
| **tree-view** | [`atom/tree-view`][tree-view] |  |
| **update-package-dependencies** | [`./update-package-dependencies`](./update-package-dependencies) | [#18284](https://github.com/atom/atom/issues/18284) |
| **welcome** | [`./welcome`](./welcome) | [#18285](https://github.com/atom/atom/issues/18285) |
| **whitespace** | [`atom/whitespace`][whitespace] |  |
| **wrap-guide** | [`atom/wrap-guide`][wrap-guide] | [#18286](https://github.com/atom/atom/issues/18286) |

[archive-view]: https://github.com/atom/archive-view
[autocomplete-atom-api]: https://github.com/atom/autocomplete-atom-api
[autocomplete-css]: https://github.com/atom/autocomplete-css
[autocomplete-html]: https://github.com/atom/autocomplete-html
[autocomplete-plus]: https://github.com/atom/autocomplete-plus
[autocomplete-snippets]: https://github.com/atom/autocomplete-snippets
[autosave]: https://github.com/atom/autosave
[background-tips]: https://github.com/atom/background-tips
[bookmarks]: https://github.com/atom/bookmarks
[bracket-matcher]: https://github.com/atom/bracket-matcher
[command-palette]: https://github.com/atom/command-palette
[encoding-selector]: https://github.com/atom/encoding-selector
[find-and-replace]: https://github.com/atom/find-and-replace
[fuzzy-finder]: https://github.com/atom/fuzzy-finder
[github]: https://github.com/atom/github
[image-view]: https://github.com/atom/image-view
[keybinding-resolver]: https://github.com/atom/keybinding-resolver
[language-c]: https://github.com/atom/language-c
[language-clojure]: https://github.com/atom/language-clojure
[language-coffee-script]: https://github.com/atom/language-coffee-script
[language-csharp]: https://github.com/atom/language-csharp
[language-css]: https://github.com/atom/language-css
[language-gfm]: https://github.com/atom/language-gfm
[language-git]: https://github.com/atom/language-git
[language-go]: https://github.com/atom/language-go
[language-html]: https://github.com/atom/language-html
[language-hyperlink]: https://github.com/atom/language-hyperlink
[language-java]: https://github.com/atom/language-java
[language-javascript]: https://github.com/atom/language-javascript
[language-json]: https://github.com/atom/language-json
[language-less]: https://github.com/atom/language-less
[language-make]: https://github.com/atom/language-make
[language-mustache]: https://github.com/atom/language-mustache
[language-objective-c]: https://github.com/atom/language-objective-c
[language-perl]: https://github.com/atom/language-perl
[language-php]: https://github.com/atom/language-php
[language-property-list]: https://github.com/atom/language-property-list
[language-python]: https://github.com/atom/language-python
[language-ruby]: https://github.com/atom/language-ruby
[language-ruby-on-rails]: https://github.com/atom/language-ruby-on-rails
[language-sass]: https://github.com/atom/language-sass
[language-shellscript]: https://github.com/atom/language-shellscript
[language-source]: https://github.com/atom/language-source
[language-sql]: https://github.com/atom/language-sql
[language-text]: https://github.com/atom/language-text
[language-todo]: https://github.com/atom/language-todo
[language-toml]: https://github.com/atom/language-toml
[language-typescript]: https://github.com/atom/language-typescript
[language-xml]: https://github.com/atom/language-xml
[language-yaml]: https://github.com/atom/language-yaml
[markdown-preview]: https://github.com/atom/markdown-preview
[metrics]: https://github.com/atom/metrics
[notifications]: https://github.com/atom/notifications
[open-on-github]: https://github.com/atom/open-on-github
[package-generator]: https://github.com/atom/package-generator
[settings-view]: https://github.com/atom/settings-view
[snippets]: https://github.com/atom/snippets
[spell-check]: https://github.com/atom/spell-check
[status-bar]: https://github.com/atom/status-bar
[styleguide]: https://github.com/atom/styleguide
[symbols-view]: https://github.com/atom/symbols-view
[tabs]: https://github.com/atom/tabs
[timecop]: https://github.com/atom/timecop
[tree-view]: https://github.com/atom/tree-view
[whitespace]: https://github.com/atom/whitespace
[wrap-guide]: https://github.com/atom/wrap-guide
