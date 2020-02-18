import {Emitter} from 'event-kit';

/*
 * Allow child components to operate on refs captured by a parent component.
 *
 * React does not guarantee that refs are available until the component has finished mounting (before
 * componentDidMount() is called), but a component does not finish mounting until all of its children are mounted. This
 * causes problems when a child needs to consume a DOM node from its parent to interact with the Atom API, like we do in
 * the `Tooltip` and `Commands` components.
 *
 * To pass a ref to a child, capture it in a RefHolder in the parent, and pass the RefHolder to the child:
 *
 *   class Parent extends React.Component {
 *     constructor() {
 *       this.theRef = new RefHolder();
 *     }
 *
 *     render() {
 *       return (
 *         <div ref={this.theRef.setter}>
 *           <Child theRef={this.theRef} />
 *         </div>
 *       )
 *     }
 *   }
 *
 * In the child, use the `observe()` method to defer operations that need the DOM node to proceed:
 *
 *   class Child extends React.Component {
 *
 *     componentDidMount() {
 *       this.props.theRef.observe(domNode => this.register(domNode))
 *     }
 *
 *     render() {
 *       return null;
 *     }
 *
 *     register(domNode) {
 *       console.log('Hey look I have a real DOM node', domNode);
 *     }
 *   }
 */
export default class RefHolder {
  constructor() {
    this.emitter = new Emitter();
    this.value = undefined;
  }

  isEmpty() {
    return this.value === undefined || this.value === null;
  }

  get() {
    if (this.isEmpty()) {
      throw new Error('RefHolder is empty');
    }
    return this.value;
  }

  getOr(def) {
    if (this.isEmpty()) {
      return def;
    }
    return this.value;
  }

  getPromise() {
    if (this.isEmpty()) {
      return new Promise(resolve => {
        const sub = this.observe(value => {
          resolve(value);
          sub.dispose();
        });
      });
    }

    return Promise.resolve(this.get());
  }

  map(present, absent = () => this) {
    return RefHolder.on(this.isEmpty() ? absent() : present(this.get()));
  }

  setter = value => {
    const oldValue = this.value;
    this.value = value;
    if (value !== oldValue && value !== null && value !== undefined) {
      this.emitter.emit('did-update', value);
    }
  }

  observe(callback) {
    if (!this.isEmpty()) {
      callback(this.value);
    }
    return this.emitter.on('did-update', callback);
  }

  static on(valueOrHolder) {
    if (valueOrHolder instanceof this) {
      return valueOrHolder;
    } else {
      const holder = new this();
      holder.setter(valueOrHolder);
      return holder;
    }
  }
}
