/** @babel */
/** @jsx etch.dom */

import etch from 'etch';

import VIEW_URI from './view-uri';
const REBUILDING = 'rebuilding';
const REBUILD_FAILED = 'rebuild-failed';
const REBUILD_SUCCEEDED = 'rebuild-succeeded';

export default class IncompatiblePackagesComponent {
  constructor(packageManager) {
    this.rebuildStatuses = new Map();
    this.rebuildFailureOutputs = new Map();
    this.rebuildInProgress = false;
    this.rebuiltPackageCount = 0;
    this.packageManager = packageManager;
    this.loaded = false;
    etch.initialize(this);

    if (this.packageManager.getActivePackages().length > 0) {
      this.populateIncompatiblePackages();
    } else {
      global.setImmediate(this.populateIncompatiblePackages.bind(this));
    }

    this.element.addEventListener('click', event => {
      if (event.target === this.refs.rebuildButton) {
        this.rebuildIncompatiblePackages();
      } else if (event.target === this.refs.reloadButton) {
        atom.reload();
      } else if (event.target.classList.contains('view-settings')) {
        atom.workspace.open(
          `atom://config/packages/${event.target.package.name}`
        );
      }
    });
  }

  update() {}

  render() {
    if (!this.loaded) {
      return <div className="incompatible-packages padded">Loading...</div>;
    }

    return (
      <div
        className="incompatible-packages padded native-key-bindings"
        tabIndex="-1"
      >
        {this.renderHeading()}
        {this.renderIncompatiblePackageList()}
      </div>
    );
  }

  renderHeading() {
    if (this.incompatiblePackages.length > 0) {
      if (this.rebuiltPackageCount > 0) {
        let alertClass =
          this.rebuiltPackageCount === this.incompatiblePackages.length
            ? 'alert-success icon-check'
            : 'alert-warning icon-bug';

        return (
          <div className={'alert icon ' + alertClass}>
            {this.rebuiltPackageCount} of {this.incompatiblePackages.length}{' '}
            packages were rebuilt successfully. Reload Atom to activate them.
            <button ref="reloadButton" className="btn pull-right">
              Reload Atom
            </button>
          </div>
        );
      } else {
        return (
          <div className="alert alert-danger icon icon-bug">
            Some installed packages could not be loaded because they contain
            native modules that were compiled for an earlier version of Atom.
            <button
              ref="rebuildButton"
              className="btn pull-right"
              disabled={this.rebuildInProgress}
            >
              Rebuild Packages
            </button>
          </div>
        );
      }
    } else {
      return (
        <div className="alert alert-success icon icon-check">
          None of your packages contain incompatible native modules.
        </div>
      );
    }
  }

  renderIncompatiblePackageList() {
    return (
      <div>
        {this.incompatiblePackages.map(
          this.renderIncompatiblePackage.bind(this)
        )}
      </div>
    );
  }

  renderIncompatiblePackage(pack) {
    let rebuildStatus = this.rebuildStatuses.get(pack);

    return (
      <div className={'incompatible-package'}>
        {this.renderRebuildStatusIndicator(rebuildStatus)}
        <button
          className="btn view-settings icon icon-gear pull-right"
          package={pack}
        >
          Package Settings
        </button>
        <h4 className="heading">
          {pack.name} {pack.metadata.version}
        </h4>
        {rebuildStatus
          ? this.renderRebuildOutput(pack)
          : this.renderIncompatibleModules(pack)}
      </div>
    );
  }

  renderRebuildStatusIndicator(rebuildStatus) {
    if (rebuildStatus === REBUILDING) {
      return (
        <div className="badge badge-info pull-right icon icon-gear">
          Rebuilding
        </div>
      );
    } else if (rebuildStatus === REBUILD_SUCCEEDED) {
      return (
        <div className="badge badge-success pull-right icon icon-check">
          Rebuild Succeeded
        </div>
      );
    } else if (rebuildStatus === REBUILD_FAILED) {
      return (
        <div className="badge badge-error pull-right icon icon-x">
          Rebuild Failed
        </div>
      );
    } else {
      return '';
    }
  }

  renderRebuildOutput(pack) {
    if (this.rebuildStatuses.get(pack) === REBUILD_FAILED) {
      return <pre>{this.rebuildFailureOutputs.get(pack)}</pre>;
    } else {
      return '';
    }
  }

  renderIncompatibleModules(pack) {
    return (
      <ul>
        {pack.incompatibleModules.map(nativeModule => (
          <li>
            <div className="icon icon-file-binary">
              {nativeModule.name}@{nativeModule.version || 'unknown'} –{' '}
              <span className="text-warning">{nativeModule.error}</span>
            </div>
          </li>
        ))}
      </ul>
    );
  }

  populateIncompatiblePackages() {
    this.incompatiblePackages = this.packageManager
      .getLoadedPackages()
      .filter(pack => !pack.isCompatible());

    for (let pack of this.incompatiblePackages) {
      let buildFailureOutput = pack.getBuildFailureOutput();
      if (buildFailureOutput) {
        this.setPackageStatus(pack, REBUILD_FAILED);
        this.setRebuildFailureOutput(pack, buildFailureOutput);
      }
    }

    this.loaded = true;
    etch.update(this);
  }

  async rebuildIncompatiblePackages() {
    this.rebuildInProgress = true;
    let rebuiltPackageCount = 0;
    for (let pack of this.incompatiblePackages) {
      this.setPackageStatus(pack, REBUILDING);
      let { code, stderr } = await pack.rebuild();
      if (code === 0) {
        this.setPackageStatus(pack, REBUILD_SUCCEEDED);
        rebuiltPackageCount++;
      } else {
        this.setRebuildFailureOutput(pack, stderr);
        this.setPackageStatus(pack, REBUILD_FAILED);
      }
    }
    this.rebuildInProgress = false;
    this.rebuiltPackageCount = rebuiltPackageCount;
    etch.update(this);
  }

  setPackageStatus(pack, status) {
    this.rebuildStatuses.set(pack, status);
    etch.update(this);
  }

  setRebuildFailureOutput(pack, output) {
    this.rebuildFailureOutputs.set(pack, output);
    etch.update(this);
  }

  getTitle() {
    return 'Incompatible Packages';
  }

  getURI() {
    return VIEW_URI;
  }

  getIconName() {
    return 'package';
  }

  serialize() {
    return { deserializer: 'IncompatiblePackagesComponent' };
  }
}
