import React, {Fragment} from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';

import URIPattern, {nonURIMatch} from './uri-pattern';
import RefHolder from '../models/ref-holder';
import StubItem from '../items/stub-item';
import {createItem, autobind} from '../helpers';

/**
 * PaneItem registers an opener with the current Atom workspace as long as this component is mounted. The opener will
 * trigger on URIs that match a specified pattern and render a subtree returned by a render prop.
 *
 * The render prop can receive three arguments:
 *
 * * itemHolder: A RefHolder. If used as the target for a ref, the referenced component will be used as the "item" of
 *   the pane item - its `getTitle()`, `getIconName()`, and other methods will be used by the pane.
 * * params: An object containing the named parameters captured by the URI pattern.
 * * uri: The exact, matched URI used to launch this item.
 *
 * render() {
 *   return (
 *     <PaneItem workspace={this.props.workspace} uriPattern='atom-github://host/{id}'>
 *       {({itemHolder, params}) => (
 *         <ItemComponent ref={itemHolder.setter} id={params.id} />
 *       )}
 *     </PaneItem>
 *   );
 * }
 */
export default class PaneItem extends React.Component {
  static propTypes = {
    workspace: PropTypes.object.isRequired,
    children: PropTypes.func.isRequired,
    uriPattern: PropTypes.string.isRequired,
    className: PropTypes.string,
  }

  constructor(props) {
    super(props);
    autobind(this, 'opener');

    const uriPattern = new URIPattern(this.props.uriPattern);
    const currentlyOpen = this.props.workspace.getPaneItems()
      .reduce((arr, item) => {
        const element = item.getElement ? item.getElement() : null;
        const match = item.getURI ? uriPattern.matches(item.getURI()) : nonURIMatch;
        const stub = item.setRealItem ? item : null;

        if (element && match.ok()) {
          const openItem = new OpenItem(match, element, stub);
          arr.push(openItem);
        }

        return arr;
      }, []);

    this.subs = new CompositeDisposable();
    this.state = {uriPattern, currentlyOpen};
  }

  static getDerivedStateFromProps(nextProps, prevState) {
    if (prevState.uriPattern.getOriginal() === nextProps.uriPattern) {
      return null;
    }

    return {
      uriPattern: new URIPattern(nextProps.uriPattern),
    };
  }

  componentDidMount() {
    for (const openItem of this.state.currentlyOpen) {
      this.registerCloseListener(openItem.stubItem, openItem);

      openItem.hydrateStub({
        copy: () => this.copyOpenItem(openItem),
      });
      if (this.props.className) {
        openItem.addClassName(this.props.className);
      }
    }

    this.subs.add(this.props.workspace.addOpener(this.opener));
  }

  render() {
    return this.state.currentlyOpen.map(item => {
      return (
        <Fragment key={item.getKey()}>
          {item.renderPortal(this.props.children)}
        </Fragment>
      );
    });
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  opener(uri) {
    const m = this.state.uriPattern.matches(uri);
    if (!m.ok()) {
      return undefined;
    }

    const openItem = new OpenItem(m);
    if (this.props.className) {
      openItem.addClassName(this.props.className);
    }

    return new Promise(resolve => {
      this.setState(prevState => ({
        currentlyOpen: [...prevState.currentlyOpen, openItem],
      }), () => {
        const paneItem = openItem.create({
          copy: () => this.copyOpenItem(openItem),
        });
        this.registerCloseListener(paneItem, openItem);
        resolve(paneItem);
      });
    });
  }

  copyOpenItem(openItem) {
    const m = this.state.uriPattern.matches(openItem.getURI());
    if (!m.ok()) {
      return null;
    }

    const stub = StubItem.create('generic', openItem.getStubProps(), openItem.getURI());

    const copiedItem = new OpenItem(m, stub.getElement(), stub);
    this.setState(prevState => ({
      currentlyOpen: [...prevState.currentlyOpen, copiedItem],
    }), () => {
      this.registerCloseListener(stub, copiedItem);
      copiedItem.hydrateStub({
        copy: () => this.copyOpenItem(copiedItem),
      });
    });

    return stub;
  }

  registerCloseListener(paneItem, openItem) {
    const sub = this.props.workspace.onDidDestroyPaneItem(({item}) => {
      if (item === paneItem) {
        sub.dispose();
        this.subs.remove(sub);
        this.setState(prevState => ({
          currentlyOpen: prevState.currentlyOpen.filter(each => each !== openItem),
        }));
      }
    });

    this.subs.add(sub);
  }
}

/**
 * A subtree rendered through a portal onto a detached DOM node for use as the root as a PaneItem.
 */
class OpenItem {
  static nextID = 0

  constructor(match, element = null, stub = null) {
    this.id = this.constructor.nextID;
    this.constructor.nextID++;

    this.domNode = element || document.createElement('div');
    this.domNode.tabIndex = '-1';
    this.domNode.onfocus = this.onFocus.bind(this);
    this.stubItem = stub;
    this.stubProps = stub ? stub.props : {};
    this.match = match;
    this.itemHolder = new RefHolder();
  }

  getURI() {
    return this.match.getURI();
  }

  create(extra = {}) {
    const h = this.itemHolder.isEmpty() ? null : this.itemHolder;
    return createItem(this.domNode, h, this.match.getURI(), extra);
  }

  hydrateStub(extra = {}) {
    if (this.stubItem) {
      this.stubItem.setRealItem(this.create(extra));
      this.stubItem = null;
    }
  }

  addClassName(className) {
    this.domNode.classList.add(className);
  }

  getKey() {
    return this.id;
  }

  getStubProps() {
    const itemProps = this.itemHolder.map(item => ({
      title: item.getTitle ? item.getTitle() : null,
      iconName: item.getIconName ? item.getIconName() : null,
    }));

    return {
      ...this.stubProps,
      ...itemProps,
    };
  }

  onFocus() {
    return this.itemHolder.map(item => item.focus && item.focus());
  }

  renderPortal(renderProp) {
    return ReactDOM.createPortal(
      renderProp({
        deserialized: this.stubProps,
        itemHolder: this.itemHolder,
        params: this.match.getParams(),
        uri: this.match.getURI(),
      }),
      this.domNode,
    );
  }
}
