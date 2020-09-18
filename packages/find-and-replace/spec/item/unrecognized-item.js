// An active workspace item that doesn't contain a TextEditor.

const etch = require('etch');
const $ = etch.dom;

class UnrecognizedItem {
  static opener(u) {
    if (u === UnrecognizedItem.uri) {
      return new UnrecognizedItem();
    } else {
      return undefined;
    }
  }

  constructor() {
    etch.initialize(this);
  }

  render() {
    return (
      $.div({className: 'wrapper'}, 'Some text')
    )
  }

  update() {}
}

UnrecognizedItem.uri = 'atom://find-and-replace/spec/unrecognized'

module.exports = UnrecognizedItem
