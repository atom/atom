import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import {TextEditor} from 'atom';
import {CompositeDisposable} from 'event-kit';

import RefHolder from '../models/ref-holder';
import {RefHolderPropType} from '../prop-types';
import {extractProps} from '../helpers';

const editorUpdateProps = {
  mini: PropTypes.bool,
  readOnly: PropTypes.bool,
  placeholderText: PropTypes.string,
  lineNumberGutterVisible: PropTypes.bool,
  autoHeight: PropTypes.bool,
  autoWidth: PropTypes.bool,
  softWrapped: PropTypes.bool,
};

const editorCreationProps = {
  buffer: PropTypes.object,
  ...editorUpdateProps,
};

const EMPTY_CLASS = 'github-AtomTextEditor-empty';

export const TextEditorContext = React.createContext();

export default class AtomTextEditor extends React.Component {
  static propTypes = {
    ...editorCreationProps,

    didChangeCursorPosition: PropTypes.func,
    didAddSelection: PropTypes.func,
    didChangeSelectionRange: PropTypes.func,
    didDestroySelection: PropTypes.func,

    hideEmptiness: PropTypes.bool,
    preselect: PropTypes.bool,
    className: PropTypes.string,
    tabIndex: PropTypes.number,

    refModel: RefHolderPropType,
    refElement: RefHolderPropType,

    children: PropTypes.node,
  }

  static defaultProps = {
    didChangeCursorPosition: () => {},
    didAddSelection: () => {},
    didChangeSelectionRange: () => {},
    didDestroySelection: () => {},

    hideEmptiness: false,
    preselect: false,
    tabIndex: 0,
  }

  constructor(props) {
    super(props);

    this.subs = new CompositeDisposable();

    this.refParent = new RefHolder();
    this.refElement = null;
    this.refModel = null;
  }

  render() {
    return (
      <Fragment>
        <div className="github-AtomTextEditor-container" ref={this.refParent.setter} />
        <TextEditorContext.Provider value={this.getRefModel()}>
          {this.props.children}
        </TextEditorContext.Provider>
      </Fragment>
    );
  }

  componentDidMount() {
    const modelProps = extractProps(this.props, editorCreationProps);

    this.refParent.map(element => {
      const editor = new TextEditor(modelProps);
      editor.getElement().tabIndex = this.props.tabIndex;
      if (this.props.className) {
        editor.getElement().classList.add(this.props.className);
      }
      if (this.props.preselect) {
        editor.selectAll();
      }
      element.appendChild(editor.getElement());
      this.getRefModel().setter(editor);
      this.getRefElement().setter(editor.getElement());

      this.subs.add(
        editor.onDidChangeCursorPosition(this.props.didChangeCursorPosition),
        editor.observeSelections(this.observeSelections),
        editor.onDidChange(this.observeEmptiness),
      );

      if (editor.isEmpty() && this.props.hideEmptiness) {
        editor.getElement().classList.add(EMPTY_CLASS);
      }

      return null;
    });
  }

  componentDidUpdate() {
    const modelProps = extractProps(this.props, editorUpdateProps);
    this.getRefModel().map(editor => editor.update(modelProps));

    // When you look into the abyss, the abyss also looks into you
    this.observeEmptiness();
  }

  componentWillUnmount() {
    this.getRefModel().map(editor => editor.destroy());
    this.subs.dispose();
  }

  observeSelections = selection => {
    const selectionSubs = new CompositeDisposable(
      selection.onDidChangeRange(this.props.didChangeSelectionRange),
      selection.onDidDestroy(() => {
        selectionSubs.dispose();
        this.subs.remove(selectionSubs);
        this.props.didDestroySelection(selection);
      }),
    );
    this.subs.add(selectionSubs);
    this.props.didAddSelection(selection);
  }

  observeEmptiness = () => {
    this.getRefModel().map(editor => {
      if (editor.isEmpty() && this.props.hideEmptiness) {
        this.getRefElement().map(element => element.classList.add(EMPTY_CLASS));
      } else {
        this.getRefElement().map(element => element.classList.remove(EMPTY_CLASS));
      }
      return null;
    });
  }

  contains(element) {
    return this.getRefElement().map(e => e.contains(element)).getOr(false);
  }

  focus() {
    this.getRefElement().map(e => e.focus());
  }

  getRefModel() {
    if (this.props.refModel) {
      return this.props.refModel;
    }

    if (!this.refModel) {
      this.refModel = new RefHolder();
    }

    return this.refModel;
  }

  getRefElement() {
    if (this.props.refElement) {
      return this.props.refElement;
    }

    if (!this.refElement) {
      this.refElement = new RefHolder();
    }

    return this.refElement;
  }

  getModel() {
    return this.getRefModel().getOr(undefined);
  }
}
