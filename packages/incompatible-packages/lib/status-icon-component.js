/** @babel */
/** @jsx etch.dom */

import etch from 'etch';

export default class StatusIconComponent {
  constructor({ count }) {
    this.count = count;
    etch.initialize(this);
  }

  update() {}

  render() {
    return (
      <div className="incompatible-packages-status inline-block text text-error">
        <span className="icon icon-bug" />
        <span className="incompatible-packages-count">{this.count}</span>
      </div>
    );
  }
}
