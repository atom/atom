const SelectListView = require('atom-select-list');

module.exports = class ReopenProjectListView {
  constructor(callback) {
    this.callback = callback;
    this.selectListView = new SelectListView({
      emptyMessage: 'No projects in history.',
      itemsClassList: ['mark-active'],
      items: [],
      filterKeyForItem: project => project.name,
      elementForItem: project => {
        let element = document.createElement('li');
        if (project.name === this.currentProjectName) {
          element.classList.add('active');
        }
        element.textContent = project.name;
        return element;
      },
      didConfirmSelection: project => {
        this.cancel();
        this.callback(project.value);
      },
      didCancelSelection: () => {
        this.cancel();
      }
    });
    this.selectListView.element.classList.add('reopen-project');
  }

  get element() {
    return this.selectListView.element;
  }

  dispose() {
    this.cancel();
    return this.selectListView.destroy();
  }

  cancel() {
    if (this.panel != null) {
      this.panel.destroy();
    }
    this.panel = null;
    this.currentProjectName = null;
    if (this.previouslyFocusedElement) {
      this.previouslyFocusedElement.focus();
      this.previouslyFocusedElement = null;
    }
  }

  attach() {
    this.previouslyFocusedElement = document.activeElement;
    if (this.panel == null) {
      this.panel = atom.workspace.addModalPanel({ item: this });
    }
    this.selectListView.focus();
    this.selectListView.reset();
  }

  async toggle() {
    if (this.panel != null) {
      this.cancel();
    } else {
      this.currentProjectName =
        atom.project != null ? this.makeName(atom.project.getPaths()) : null;
      const projects = atom.history
        .getProjects()
        .map(p => ({ name: this.makeName(p.paths), value: p.paths }));
      await this.selectListView.update({ items: projects });
      this.attach();
    }
  }

  makeName(paths) {
    return paths.join(', ');
  }
};
