/** @babel */
/** @jsx etch.dom */

import _ from 'underscore-plus';
import { CompositeDisposable } from 'atom';
import etch from 'etch';
import fs from 'fs-plus';
import Grim from 'grim';
import { marked } from 'marked';
import path from 'path';
import { shell } from 'electron';

export default class DeprecationCopView {
  constructor({ uri }) {
    this.uri = uri;
    this.subscriptions = new CompositeDisposable();
    this.subscriptions.add(
      Grim.on('updated', () => {
        etch.update(this);
      })
    );
    // TODO: Remove conditional when the new StyleManager deprecation APIs reach stable.
    if (atom.styles.onDidUpdateDeprecations) {
      this.subscriptions.add(
        atom.styles.onDidUpdateDeprecations(() => {
          etch.update(this);
        })
      );
    }
    etch.initialize(this);
    this.subscriptions.add(
      atom.commands.add(this.element, {
        'core:move-up': () => {
          this.scrollUp();
        },
        'core:move-down': () => {
          this.scrollDown();
        },
        'core:page-up': () => {
          this.pageUp();
        },
        'core:page-down': () => {
          this.pageDown();
        },
        'core:move-to-top': () => {
          this.scrollToTop();
        },
        'core:move-to-bottom': () => {
          this.scrollToBottom();
        }
      })
    );
  }

  serialize() {
    return {
      deserializer: this.constructor.name,
      uri: this.getURI(),
      version: 1
    };
  }

  destroy() {
    this.subscriptions.dispose();
    return etch.destroy(this);
  }

  update() {
    return etch.update(this);
  }

  render() {
    return (
      <div
        className="deprecation-cop pane-item native-key-bindings"
        tabIndex="-1"
      >
        <div className="panel">
          <div className="padded deprecation-overview">
            <div className="pull-right btn-group">
              <button
                className="btn btn-primary check-for-update"
                onclick={event => {
                  event.preventDefault();
                  this.checkForUpdates();
                }}
              >
                Check for Updates
              </button>
            </div>
          </div>

          <div className="panel-heading">
            <span>Deprecated calls</span>
          </div>
          <ul className="list-tree has-collapsable-children">
            {this.renderDeprecatedCalls()}
          </ul>

          <div className="panel-heading">
            <span>Deprecated selectors</span>
          </div>
          <ul className="selectors list-tree has-collapsable-children">
            {this.renderDeprecatedSelectors()}
          </ul>
        </div>
      </div>
    );
  }

  renderDeprecatedCalls() {
    const deprecationsByPackageName = this.getDeprecatedCallsByPackageName();
    const packageNames = Object.keys(deprecationsByPackageName);
    if (packageNames.length === 0) {
      return <li className="list-item">No deprecated calls</li>;
    } else {
      return packageNames.sort().map(packageName => (
        <li className="deprecation list-nested-item collapsed">
          <div
            className="deprecation-info list-item"
            onclick={event =>
              event.target.parentElement.classList.toggle('collapsed')
            }
          >
            <span className="text-highlight">{packageName || 'atom core'}</span>
            <span>{` (${_.pluralize(
              deprecationsByPackageName[packageName].length,
              'deprecation'
            )})`}</span>
          </div>

          <ul className="list">
            {this.renderPackageActionsIfNeeded(packageName)}
            {deprecationsByPackageName[packageName].map(
              ({ deprecation, stack }) => (
                <li className="list-item deprecation-detail">
                  <span className="text-warning icon icon-alert" />
                  <div
                    className="list-item deprecation-message"
                    innerHTML={marked(deprecation.getMessage())}
                  />
                  {this.renderIssueURLIfNeeded(
                    packageName,
                    deprecation,
                    this.buildIssueURL(packageName, deprecation, stack)
                  )}
                  <div className="stack-trace">
                    {stack.map(({ functionName, location }) => (
                      <div className="stack-line">
                        <span>{functionName}</span>
                        <span> - </span>
                        <a
                          className="stack-line-location"
                          href={location}
                          onclick={event => {
                            event.preventDefault();
                            this.openLocation(location);
                          }}
                        >
                          {location}
                        </a>
                      </div>
                    ))}
                  </div>
                </li>
              )
            )}
          </ul>
        </li>
      ));
    }
  }

  renderDeprecatedSelectors() {
    const deprecationsByPackageName = this.getDeprecatedSelectorsByPackageName();
    const packageNames = Object.keys(deprecationsByPackageName);
    if (packageNames.length === 0) {
      return <li className="list-item">No deprecated selectors</li>;
    } else {
      return packageNames.map(packageName => (
        <li className="deprecation list-nested-item collapsed">
          <div
            className="deprecation-info list-item"
            onclick={event =>
              event.target.parentElement.classList.toggle('collapsed')
            }
          >
            <span className="text-highlight">{packageName}</span>
          </div>

          <ul className="list">
            {this.renderPackageActionsIfNeeded(packageName)}
            {deprecationsByPackageName[packageName].map(
              ({ packagePath, sourcePath, deprecation }) => {
                const relativeSourcePath = path.relative(
                  packagePath,
                  sourcePath
                );
                const issueTitle = `Deprecated selector in \`${relativeSourcePath}\``;
                const issueBody = `In \`${relativeSourcePath}\`: \n\n${
                  deprecation.message
                }`;
                return (
                  <li className="list-item source-file">
                    <a
                      className="source-url"
                      href={sourcePath}
                      onclick={event => {
                        event.preventDefault();
                        this.openLocation(sourcePath);
                      }}
                    >
                      {relativeSourcePath}
                    </a>
                    <ul className="list">
                      <li className="list-item deprecation-detail">
                        <span className="text-warning icon icon-alert" />
                        <div
                          className="list-item deprecation-message"
                          innerHTML={marked(deprecation.message)}
                        />
                        {this.renderSelectorIssueURLIfNeeded(
                          packageName,
                          issueTitle,
                          issueBody
                        )}
                      </li>
                    </ul>
                  </li>
                );
              }
            )}
          </ul>
        </li>
      ));
    }
  }

  renderPackageActionsIfNeeded(packageName) {
    if (packageName && atom.packages.getLoadedPackage(packageName)) {
      return (
        <div className="padded">
          <div className="btn-group">
            <button
              className="btn check-for-update"
              onclick={event => {
                event.preventDefault();
                this.checkForUpdates();
              }}
            >
              Check for Update
            </button>
            <button
              className="btn disable-package"
              data-package-name={packageName}
              onclick={event => {
                event.preventDefault();
                this.disablePackage(packageName);
              }}
            >
              Disable Package
            </button>
          </div>
        </div>
      );
    } else {
      return '';
    }
  }

  encodeURI(str) {
    return encodeURI(str)
      .replace(/#/g, '%23')
      .replace(/;/g, '%3B')
      .replace(/%20/g, '+');
  }

  renderSelectorIssueURLIfNeeded(packageName, issueTitle, issueBody) {
    const repoURL = this.getRepoURL(packageName);
    if (repoURL) {
      const issueURL = `${repoURL}/issues/new?title=${this.encodeURI(
        issueTitle
      )}&body=${this.encodeURI(issueBody)}`;
      return (
        <div className="btn-toolbar">
          <button
            className="btn issue-url"
            data-issue-title={issueTitle}
            data-repo-url={repoURL}
            data-issue-url={issueURL}
            onclick={event => {
              event.preventDefault();
              this.openIssueURL(repoURL, issueURL, issueTitle);
            }}
          >
            Report Issue
          </button>
        </div>
      );
    } else {
      return '';
    }
  }

  renderIssueURLIfNeeded(packageName, deprecation, issueURL) {
    if (packageName && issueURL) {
      const repoURL = this.getRepoURL(packageName);
      const issueTitle = `${deprecation.getOriginName()} is deprecated.`;
      return (
        <div className="btn-toolbar">
          <button
            className="btn issue-url"
            data-issue-title={issueTitle}
            data-repo-url={repoURL}
            data-issue-url={issueURL}
            onclick={event => {
              event.preventDefault();
              this.openIssueURL(repoURL, issueURL, issueTitle);
            }}
          >
            Report Issue
          </button>
        </div>
      );
    } else {
      return '';
    }
  }

  buildIssueURL(packageName, deprecation, stack) {
    const repoURL = this.getRepoURL(packageName);
    if (repoURL) {
      const title = `${deprecation.getOriginName()} is deprecated.`;
      const stacktrace = stack
        .map(({ functionName, location }) => `${functionName} (${location})`)
        .join('\n');
      const body = `${deprecation.getMessage()}\n\`\`\`\n${stacktrace}\n\`\`\``;
      return `${repoURL}/issues/new?title=${encodeURI(title)}&body=${encodeURI(
        body
      )}`;
    } else {
      return null;
    }
  }

  async openIssueURL(repoURL, issueURL, issueTitle) {
    const issue = await this.findSimilarIssue(repoURL, issueTitle);
    if (issue) {
      shell.openExternal(issue.html_url);
    } else if (process.platform === 'win32') {
      // Windows will not launch URLs greater than ~2000 bytes so we need to shrink it
      shell.openExternal((await this.shortenURL(issueURL)) || issueURL);
    } else {
      shell.openExternal(issueURL);
    }
  }

  async findSimilarIssue(repoURL, issueTitle) {
    const url = 'https://api.github.com/search/issues';
    const repo = repoURL.replace(/http(s)?:\/\/(\d+\.)?github.com\//gi, '');
    const query = `${issueTitle} repo:${repo}`;
    const response = await window.fetch(
      `${url}?q=${encodeURI(query)}&sort=created`,
      {
        method: 'GET',
        headers: {
          Accept: 'application/vnd.github.v3+json',
          'Content-Type': 'application/json'
        }
      }
    );

    if (response.ok) {
      const data = await response.json();
      if (data.items) {
        const issues = {};
        for (const issue of data.items) {
          if (issue.title.includes(issueTitle) && !issues[issue.state]) {
            issues[issue.state] = issue;
          }
        }

        return issues.open || issues.closed;
      }
    }
  }

  async shortenURL(url) {
    let encodedUrl = encodeURIComponent(url).substr(0, 5000); // is.gd has 5000 char limit
    let incompletePercentEncoding = encodedUrl.indexOf(
      '%',
      encodedUrl.length - 2
    );
    if (incompletePercentEncoding >= 0) {
      // Handle an incomplete % encoding cut-off
      encodedUrl = encodedUrl.substr(0, incompletePercentEncoding);
    }

    let result = await fetch('https://is.gd/create.php?format=simple', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `url=${encodedUrl}`
    });

    return result.text();
  }

  getRepoURL(packageName) {
    const loadedPackage = atom.packages.getLoadedPackage(packageName);
    if (
      loadedPackage &&
      loadedPackage.metadata &&
      loadedPackage.metadata.repository
    ) {
      const url =
        loadedPackage.metadata.repository.url ||
        loadedPackage.metadata.repository;
      return url.replace(/\.git$/, '');
    } else {
      return null;
    }
  }

  getDeprecatedCallsByPackageName() {
    const deprecatedCalls = Grim.getDeprecations();
    deprecatedCalls.sort((a, b) => b.getCallCount() - a.getCallCount());
    const deprecatedCallsByPackageName = {};
    for (const deprecation of deprecatedCalls) {
      const stacks = deprecation.getStacks();
      stacks.sort((a, b) => b.callCount - a.callCount);
      for (const stack of stacks) {
        let packageName = null;
        if (stack.metadata && stack.metadata.packageName) {
          packageName = stack.metadata.packageName;
        } else {
          packageName = (this.getPackageName(stack) || '').toLowerCase();
        }

        deprecatedCallsByPackageName[packageName] =
          deprecatedCallsByPackageName[packageName] || [];
        deprecatedCallsByPackageName[packageName].push({ deprecation, stack });
      }
    }
    return deprecatedCallsByPackageName;
  }

  getDeprecatedSelectorsByPackageName() {
    const deprecatedSelectorsByPackageName = {};
    if (atom.styles.getDeprecations) {
      const deprecatedSelectorsBySourcePath = atom.styles.getDeprecations();
      for (const sourcePath of Object.keys(deprecatedSelectorsBySourcePath)) {
        const deprecation = deprecatedSelectorsBySourcePath[sourcePath];
        const components = sourcePath.split(path.sep);
        const packagesComponentIndex = components.indexOf('packages');
        let packageName = null;
        let packagePath = null;
        if (packagesComponentIndex === -1) {
          packageName = 'Other'; // could be Atom Core or the personal style sheet
          packagePath = '';
        } else {
          packageName = components[packagesComponentIndex + 1];
          packagePath = components
            .slice(0, packagesComponentIndex + 1)
            .join(path.sep);
        }

        deprecatedSelectorsByPackageName[packageName] =
          deprecatedSelectorsByPackageName[packageName] || [];
        deprecatedSelectorsByPackageName[packageName].push({
          packagePath,
          sourcePath,
          deprecation
        });
      }
    }

    return deprecatedSelectorsByPackageName;
  }

  getPackageName(stack) {
    const packagePaths = this.getPackagePathsByPackageName();
    for (const [packageName, packagePath] of packagePaths) {
      if (
        packagePath.includes('.atom/dev/packages') ||
        packagePath.includes('.atom/packages')
      ) {
        packagePaths.set(packageName, fs.absolute(packagePath));
      }
    }

    for (let i = 1; i < stack.length; i++) {
      const { fileName } = stack[i];

      // Empty when it was run from the dev console
      if (!fileName) {
        return null;
      }

      // Continue to next stack entry if call is in node_modules
      if (fileName.includes(`${path.sep}node_modules${path.sep}`)) {
        continue;
      }

      for (const [packageName, packagePath] of packagePaths) {
        const relativePath = path.relative(packagePath, fileName);
        if (!/^\.\./.test(relativePath)) {
          return packageName;
        }
      }

      if (atom.getUserInitScriptPath() === fileName) {
        return `Your local ${path.basename(fileName)} file`;
      }
    }

    return null;
  }

  getPackagePathsByPackageName() {
    if (this.packagePathsByPackageName) {
      return this.packagePathsByPackageName;
    } else {
      this.packagePathsByPackageName = new Map();
      for (const pack of atom.packages.getLoadedPackages()) {
        this.packagePathsByPackageName.set(pack.name, pack.path);
      }
      return this.packagePathsByPackageName;
    }
  }

  checkForUpdates() {
    atom.workspace.open('atom://config/updates');
  }

  disablePackage(packageName) {
    if (packageName) {
      atom.packages.disablePackage(packageName);
    }
  }

  openLocation(location) {
    let pathToOpen = location.replace('file://', '');
    if (process.platform === 'win32') {
      pathToOpen = pathToOpen.replace(/^\//, '');
    }
    atom.open({ pathsToOpen: [pathToOpen] });
  }

  getURI() {
    return this.uri;
  }

  getTitle() {
    return 'Deprecation Cop';
  }

  getIconName() {
    return 'alert';
  }

  scrollUp() {
    this.element.scrollTop -= document.body.offsetHeight / 20;
  }

  scrollDown() {
    this.element.scrollTop += document.body.offsetHeight / 20;
  }

  pageUp() {
    this.element.scrollTop -= this.element.offsetHeight;
  }

  pageDown() {
    this.element.scrollTop += this.element.offsetHeight;
  }

  scrollToTop() {
    this.element.scrollTop = 0;
  }

  scrollToBottom() {
    this.element.scrollTop = this.element.scrollHeight;
  }
}
