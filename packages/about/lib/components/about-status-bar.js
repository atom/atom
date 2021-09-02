const { CompositeDisposable } = require('atom');
const etch = require('etch');
const EtchComponent = require('../etch-component');

const $ = etch.dom;

module.exports = class AboutStatusBar extends EtchComponent {
  constructor() {
    super();
    this.subscriptions = new CompositeDisposable();

    this.subscriptions.add(
      atom.tooltips.add(this.element, {
        title:
          'An update will be installed the next time Atom is relaunched.<br/><br/>Click the squirrel icon for more information.'
      })
    );
  }

  handleClick() {
    atom.workspace.open('atom://about');
  }

  render() {
    return $.div(
      {
        className: 'about-release-notes inline-block',
        onclick: this.handleClick.bind(this)
      },
      $.span({ type: 'button', className: 'icon icon-squirrel' })
    );
  }

  destroy() {
    super.destroy();
    this.subscriptions.dispose();
  }
};
