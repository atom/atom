module.exports = class UpdatePackageDependenciesStatusView {
  constructor(statusBar) {
    this.statusBar = statusBar;
    this.element = document.createElement('update-package-dependencies-status');
    this.element.classList.add(
      'update-package-dependencies-status',
      'inline-block',
      'is-read-only'
    );
    this.spinner = document.createElement('span');
    this.spinner.classList.add(
      'loading',
      'loading-spinner-tiny',
      'inline-block'
    );
    this.element.appendChild(this.spinner);
  }

  attach() {
    this.tile = this.statusBar.addRightTile({ item: this.element });
    this.tooltip = atom.tooltips.add(this.element, {
      title: 'Updating package dependencies\u2026'
    });
  }

  detach() {
    if (this.tile) this.tile.destroy();
    if (this.tooltip) this.tooltip.dispose();
  }
};
