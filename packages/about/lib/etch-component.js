const etch = require('etch');

/*
  Public: Abstract class for handling the initialization
  boilerplate of an Etch component.
*/
module.exports = class EtchComponent {
  constructor(props) {
    this.props = props;

    etch.initialize(this);
    EtchComponent.setScheduler(atom.views);
  }

  /*
    Public: Gets the scheduler Etch uses for coordinating DOM updates.

    Returns a {Scheduler}
  */
  static getScheduler() {
    return etch.getScheduler();
  }

  /*
    Public: Sets the scheduler Etch uses for coordinating DOM updates.

    * `scheduler` {Scheduler}
  */
  static setScheduler(scheduler) {
    etch.setScheduler(scheduler);
  }

  /*
    Public: Updates the component's properties and re-renders it. Only the
    properties you specify in this object will update – any other properties
    the component stores will be unaffected.

    * `props` an {Object} representing the properties you want to update
  */
  update(props) {
    let oldProps = this.props;
    this.props = Object.assign({}, oldProps, props);
    return etch.update(this);
  }

  /*
    Public: Destroys the component, removing it from the DOM.
  */
  destroy() {
    etch.destroy(this);
  }

  render() {
    throw new Error('Etch components must implement a `render` method');
  }
};
