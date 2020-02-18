import React from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';
import cx from 'classnames';
import Select from 'react-select';

import Tooltip from '../atom/tooltip';
import AtomTextEditor from '../atom/atom-text-editor';
import CoAuthorForm from './co-author-form';
import RecentCommitsView from './recent-commits-view';
import StagingView from './staging-view';
import Commands, {Command} from '../atom/commands';
import RefHolder from '../models/ref-holder';
import Author from '../models/author';
import ObserveModel from './observe-model';
import {LINE_ENDING_REGEX, autobind} from '../helpers';
import {AuthorPropType, UserStorePropType} from '../prop-types';
import {incrementCounter} from '../reporter-proxy';

const TOOLTIP_DELAY = 200;

// CustomEvent is a DOM primitive, which v8 can't access
// so we're essentially lazy loading to keep snapshotting from breaking.
let FakeKeyDownEvent;

export default class CommitView extends React.Component {
  static focus = {
    COMMIT_PREVIEW_BUTTON: Symbol('commit-preview-button'),
    EDITOR: Symbol('commit-editor'),
    COAUTHOR_INPUT: Symbol('coauthor-input'),
    ABORT_MERGE_BUTTON: Symbol('commit-abort-merge-button'),
    COMMIT_BUTTON: Symbol('commit-button'),
  };

  static firstFocus = CommitView.focus.COMMIT_PREVIEW_BUTTON;

  static lastFocus = Symbol('last-focus');

  static propTypes = {
    workspace: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,

    lastCommit: PropTypes.object.isRequired,
    currentBranch: PropTypes.object.isRequired,
    isMerging: PropTypes.bool.isRequired,
    mergeConflictsExist: PropTypes.bool.isRequired,
    stagedChangesExist: PropTypes.bool.isRequired,
    isCommitting: PropTypes.bool.isRequired,
    commitPreviewActive: PropTypes.bool.isRequired,
    deactivateCommitBox: PropTypes.bool.isRequired,
    maximumCharacterLimit: PropTypes.number.isRequired,
    messageBuffer: PropTypes.object.isRequired, // FIXME more specific proptype
    userStore: UserStorePropType.isRequired,
    selectedCoAuthors: PropTypes.arrayOf(AuthorPropType),
    updateSelectedCoAuthors: PropTypes.func,
    commit: PropTypes.func.isRequired,
    abortMerge: PropTypes.func.isRequired,
    prepareToCommit: PropTypes.func.isRequired,
    toggleExpandedCommitMessageEditor: PropTypes.func.isRequired,
    toggleCommitPreview: PropTypes.func.isRequired,
    activateCommitPreview: PropTypes.func.isRequired,
  };

  constructor(props, context) {
    super(props, context);
    autobind(
      this,
      'submitNewCoAuthor', 'cancelNewCoAuthor', 'didMoveCursor', 'toggleHardWrap',
      'toggleCoAuthorInput', 'abortMerge', 'commit', 'amendLastCommit', 'toggleExpandedCommitMessageEditor',
      'renderCoAuthorListItem', 'onSelectedCoAuthorsChanged', 'excludeCoAuthor',
    );

    this.state = {
      showWorking: false,
      showCoAuthorInput: false,
      showCoAuthorForm: false,
      coAuthorInput: '',
    };

    this.timeoutHandle = null;
    this.subscriptions = new CompositeDisposable();

    this.refRoot = new RefHolder();
    this.refCommitPreviewButton = new RefHolder();
    this.refExpandButton = new RefHolder();
    this.refCommitButton = new RefHolder();
    this.refHardWrapButton = new RefHolder();
    this.refAbortMergeButton = new RefHolder();
    this.refCoAuthorToggle = new RefHolder();
    this.refCoAuthorSelect = new RefHolder();
    this.refCoAuthorForm = new RefHolder();
    this.refEditorComponent = new RefHolder();
    this.refEditorModel = new RefHolder();

    this.subs = new CompositeDisposable();
  }

  proxyKeyCode(keyCode) {
    return e => {
      if (this.refCoAuthorSelect.isEmpty()) {
        return;
      }

      if (!FakeKeyDownEvent) {
        FakeKeyDownEvent = class extends CustomEvent {
          constructor(kCode) {
            super('keydown');
            this.keyCode = kCode;
          }
        };
      }

      const fakeEvent = new FakeKeyDownEvent(keyCode);
      this.refCoAuthorSelect.get().handleKeyDown(fakeEvent);

      if (!fakeEvent.defaultPrevented) {
        e.abortKeyBinding();
      }
    };
  }

  // eslint-disable-next-line camelcase
  UNSAFE_componentWillMount() {
    this.scheduleShowWorking(this.props);

    this.subs.add(
      this.props.config.onDidChange('github.automaticCommitMessageWrapping', () => this.forceUpdate()),
      this.props.messageBuffer.onDidChange(() => this.forceUpdate()),
    );
  }

  render() {
    let remainingCharsClassName = '';
    const remainingCharacters = parseInt(this.getRemainingCharacters(), 10);
    if (remainingCharacters < 0) {
      remainingCharsClassName = 'is-error';
    } else if (remainingCharacters < this.props.maximumCharacterLimit / 4) {
      remainingCharsClassName = 'is-warning';
    }

    const showAbortMergeButton = this.props.isMerging || null;

    /* istanbul ignore next */
    const modKey = process.platform === 'darwin' ? 'Cmd' : 'Ctrl';

    return (
      <div className="github-CommitView" ref={this.refRoot.setter}>
        <Commands registry={this.props.commands} target="atom-workspace">
          <Command command="github:commit" callback={this.commit} />
          <Command command="github:amend-last-commit" callback={this.amendLastCommit} />
          <Command command="github:toggle-expanded-commit-message-editor"
            callback={this.toggleExpandedCommitMessageEditor}
          />
        </Commands>
        <Commands registry={this.props.commands} target=".github-CommitView-coAuthorEditor">
          <Command command="github:selectbox-down" callback={this.proxyKeyCode(40)} />
          <Command command="github:selectbox-up" callback={this.proxyKeyCode(38)} />
          <Command command="github:selectbox-enter" callback={this.proxyKeyCode(13)} />
          <Command command="github:selectbox-tab" callback={this.proxyKeyCode(9)} />
          <Command command="github:selectbox-backspace" callback={this.proxyKeyCode(8)} />
          <Command command="github:selectbox-pageup" callback={this.proxyKeyCode(33)} />
          <Command command="github:selectbox-pagedown" callback={this.proxyKeyCode(34)} />
          <Command command="github:selectbox-end" callback={this.proxyKeyCode(35)} />
          <Command command="github:selectbox-home" callback={this.proxyKeyCode(36)} />
          <Command command="github:selectbox-delete" callback={this.proxyKeyCode(46)} />
          <Command command="github:selectbox-escape" callback={this.proxyKeyCode(27)} />
          <Command command="github:co-author-exclude" callback={this.excludeCoAuthor} />
        </Commands>
        <Commands registry={this.props.commands} target=".github-CommitView-commitPreview">
          <Command command="github:dive" callback={this.props.activateCommitPreview} />
        </Commands>
        <div className="github-CommitView-buttonWrapper">
          <button
            ref={this.refCommitPreviewButton.setter}
            className="github-CommitView-commitPreview github-CommitView-button btn"
            disabled={!this.props.stagedChangesExist}
            onClick={this.props.toggleCommitPreview}>
            {this.props.commitPreviewActive ? 'Hide All Staged Changes' : 'See All Staged Changes'}
          </button>
        </div>
        <div className={cx('github-CommitView-editor', {'is-expanded': this.props.deactivateCommitBox})}>
          <AtomTextEditor
            ref={this.refEditorComponent.setter}
            refModel={this.refEditorModel}
            softWrapped={true}
            placeholderText="Commit message"
            lineNumberGutterVisible={false}
            showInvisibles={false}
            autoHeight={false}
            scrollPastEnd={false}
            buffer={this.props.messageBuffer}
            workspace={this.props.workspace}
            didChangeCursorPosition={this.didMoveCursor}
          />
          <button
            ref={this.refCoAuthorToggle.setter}
            className={cx('github-CommitView-coAuthorToggle', {focused: this.state.showCoAuthorInput})}
            onClick={this.toggleCoAuthorInput}>
            {this.renderCoAuthorToggleIcon()}
          </button>
          <Tooltip
            manager={this.props.tooltips}
            target={this.refCoAuthorToggle}
            title={`${this.state.showCoAuthorInput ? 'Remove' : 'Add'} co-authors`}
            showDelay={TOOLTIP_DELAY}
          />
          <button
            ref={this.refHardWrapButton.setter}
            onClick={this.toggleHardWrap}
            className="github-CommitView-hardwrap hard-wrap-icons">
            {this.renderHardWrapIcon()}
          </button>
          <Tooltip
            manager={this.props.tooltips}
            target={this.refHardWrapButton}
            className="github-CommitView-hardwrap-tooltip"
            title="Toggle hard wrap on commit"
            showDelay={TOOLTIP_DELAY}
          />
          <button
            ref={this.refExpandButton.setter}
            className="github-CommitView-expandButton icon icon-screen-full"
            onClick={this.toggleExpandedCommitMessageEditor}
          />
          <Tooltip
            manager={this.props.tooltips}
            target={this.refExpandButton}
            className="github-CommitView-expandButton-tooltip"
            title="Expand commit message editor"
            showDelay={TOOLTIP_DELAY}
          />
        </div>

        {this.renderCoAuthorForm()}
        {this.renderCoAuthorInput()}

        <footer className="github-CommitView-bar">
          {showAbortMergeButton &&
            <button
              ref={this.refAbortMergeButton.setter}
              className="btn github-CommitView-button github-CommitView-abortMerge is-secondary"
              onClick={this.abortMerge}>Abort Merge</button>
          }

          <button
            ref={this.refCommitButton.setter}
            className="github-CommitView-button github-CommitView-commit btn btn-primary native-key-bindings"
            onClick={this.commit}
            disabled={!this.commitIsEnabled(false)}>{this.commitButtonText()}</button>
          {this.commitIsEnabled(false) &&
            <Tooltip
              manager={this.props.tooltips}
              target={this.refCommitButton}
              className="github-CommitView-button-tooltip"
              title={`${modKey}-enter to commit`}
              showDelay={TOOLTIP_DELAY}
            />}
          <div className={`github-CommitView-remaining-characters ${remainingCharsClassName}`}>
            {this.getRemainingCharacters()}
          </div>
        </footer>
      </div>
    );
  }

  renderCoAuthorToggleIcon() {
    /* eslint-disable max-len */
    const svgPath = 'M9.875 2.125H12v1.75H9.875V6h-1.75V3.875H6v-1.75h2.125V0h1.75v2.125zM6 6.5a.5.5 0 0 1-.5.5h-5a.5.5 0 0 1-.5-.5V6c0-1.316 2-2 2-2s.114-.204 0-.5c-.42-.31-.472-.795-.5-2C1.587.293 2.434 0 3 0s1.413.293 1.5 1.5c-.028 1.205-.08 1.69-.5 2-.114.295 0 .5 0 .5s2 .684 2 2v.5z';
    return (
      <svg className={cx('github-CommitView-coAuthorToggleIcon', {focused: this.state.showCoAuthorInput})} viewBox="0 0 12 7" xmlns="http://www.w3.org/2000/svg">
        <title>Add or remove co-authors</title>
        <path d={svgPath} />
      </svg>
    );
  }

  renderCoAuthorInput() {
    if (!this.state.showCoAuthorInput) {
      return null;
    }

    return (
      <ObserveModel model={this.props.userStore} fetchData={store => store.getUsers()}>
        {mentionableUsers => (
          <Select
            ref={this.refCoAuthorSelect.setter}
            className="github-CommitView-coAuthorEditor input-textarea native-key-bindings"
            placeholder="Co-Authors"
            arrowRenderer={null}
            options={mentionableUsers}
            labelKey="fullName"
            valueKey="email"
            filterOptions={this.matchAuthors}
            optionRenderer={this.renderCoAuthorListItem}
            valueRenderer={this.renderCoAuthorValue}
            onChange={this.onSelectedCoAuthorsChanged}
            value={this.props.selectedCoAuthors}
            multi={true}
            openOnClick={false}
            openOnFocus={false}
            tabIndex="5"
          />
        )}
      </ObserveModel>
    );
  }

  renderHardWrapIcon() {
    const singleLineMessage = this.props.messageBuffer.getText().split(LINE_ENDING_REGEX).length === 1;
    const hardWrap = this.props.config.get('github.automaticCommitMessageWrapping');
    const notApplicable = this.props.deactivateCommitBox || singleLineMessage;

    /* eslint-disable max-len */
    const svgPaths = {
      hardWrapEnabled: {
        path1: 'M7.058 10.2h-.975v2.4L2 9l4.083-3.6v2.4h.97l1.202 1.203L7.058 10.2zm2.525-4.865V4.2h2.334v1.14l-1.164 1.165-1.17-1.17z', // eslint-disable-line max-len
        path2: 'M7.842 6.94l2.063 2.063-2.122 2.12.908.91 2.123-2.123 1.98 1.98.85-.848L11.58 8.98l2.12-2.123-.824-.825-2.122 2.12-2.062-2.06z', // eslint-disable-line max-len
      },
      hardWrapDisabled: {
        path1: 'M11.917 8.4c0 .99-.788 1.8-1.75 1.8H6.083v2.4L2 9l4.083-3.6v2.4h3.5V4.2h2.334v4.2z',
      },
    };
    /* eslint-enable max-len */

    if (notApplicable) {
      return null;
    }

    if (hardWrap) {
      return (
        <div className={cx('icon', 'hardwrap', 'icon-hardwrap-enabled', {hidden: notApplicable || !hardWrap})}>
          <svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
            <path d={svgPaths.hardWrapDisabled.path1} fillRule="evenodd" />
          </svg>
        </div>
      );
    } else {
      return (
        <div className={cx('icon', 'no-hardwrap', 'icon-hardwrap-disabled', {hidden: notApplicable || hardWrap})}>
          <svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
            <g fillRule="evenodd">
              <path d={svgPaths.hardWrapEnabled.path1} />
              <path fillRule="nonzero" d={svgPaths.hardWrapEnabled.path2} />
            </g>
          </svg>
        </div>
      );
    }
  }

  renderCoAuthorForm() {
    if (!this.state.showCoAuthorForm) {
      return null;
    }

    return (
      <CoAuthorForm
        ref={this.refCoAuthorForm.setter}
        commands={this.props.commands}
        onSubmit={this.submitNewCoAuthor}
        onCancel={this.cancelNewCoAuthor}
        name={this.state.coAuthorInput}
      />
    );
  }

  submitNewCoAuthor(newAuthor) {
    this.props.updateSelectedCoAuthors(this.props.selectedCoAuthors, newAuthor);
    this.hideNewAuthorForm();
  }

  cancelNewCoAuthor() {
    this.hideNewAuthorForm();
  }

  hideNewAuthorForm() {
    this.setState({showCoAuthorForm: false}, () => {
      this.refCoAuthorSelect.map(c => c.focus());
    });
  }

  // eslint-disable-next-line camelcase
  UNSAFE_componentWillReceiveProps(nextProps) {
    this.scheduleShowWorking(nextProps);
  }

  componentWillUnmount() {
    this.subs.dispose();
  }

  didMoveCursor() {
    this.forceUpdate();
  }

  toggleHardWrap() {
    const currentSetting = this.props.config.get('github.automaticCommitMessageWrapping');
    this.props.config.set('github.automaticCommitMessageWrapping', !currentSetting);
  }

  toggleCoAuthorInput() {
    this.setState({
      showCoAuthorInput: !this.state.showCoAuthorInput,
    }, () => {
      if (this.state.showCoAuthorInput) {
        incrementCounter('show-co-author-input');
        this.refCoAuthorSelect.map(c => c.focus());
      } else {
        // if input is closed, remove all co-authors
        this.props.updateSelectedCoAuthors([]);
        incrementCounter('hide-co-author-input');
      }
    });
  }

  excludeCoAuthor() {
    const author = this.refCoAuthorSelect.map(c => c.getFocusedOption()).getOr(null);
    if (!author || author.isNew()) {
      return;
    }

    let excluded = this.props.config.get('github.excludedUsers');
    if (excluded && excluded !== '') {
      excluded += ', ';
    }
    excluded += author.getEmail();
    this.props.config.set('github.excludedUsers', excluded);
  }

  abortMerge() {
    this.props.abortMerge();
  }

  async commit(event, amend) {
    if (await this.props.prepareToCommit() && this.commitIsEnabled(amend)) {
      try {
        await this.props.commit(this.props.messageBuffer.getText(), this.props.selectedCoAuthors, amend);
      } catch (e) {
        // do nothing - error was taken care of in pipeline manager
        if (!atom.isReleasedVersion()) {
          throw e;
        }
      }
    } else {
      this.setFocus(CommitView.focus.EDITOR);
    }
  }

  amendLastCommit() {
    incrementCounter('amend');
    this.commit(null, true);
  }

  getRemainingCharacters() {
    return this.refEditorModel.map(editor => {
      if (editor.getCursorBufferPosition().row === 0) {
        return (this.props.maximumCharacterLimit - editor.lineTextForBufferRow(0).length).toString();
      } else {
        return '∞';
      }
    }).getOr(this.props.maximumCharacterLimit || '');
  }

  // We don't want the user to see the UI flicker in the case
  // the commit takes a very small time to complete. Instead we
  // will only show the working message if we are working for longer
  // than 1 second as per https://www.nngroup.com/articles/response-times-3-important-limits/
  //
  // The closure is created to restrict variable access
  scheduleShowWorking(props) {
    if (props.isCommitting) {
      if (!this.state.showWorking && this.timeoutHandle === null) {
        this.timeoutHandle = setTimeout(() => {
          this.timeoutHandle = null;
          this.setState({showWorking: true});
        }, 1000);
      }
    } else {
      clearTimeout(this.timeoutHandle);
      this.timeoutHandle = null;
      this.setState({showWorking: false});
    }
  }

  isValidMessage() {
    // ensure that there are at least some non-comment lines in the commit message.
    // Commented lines are stripped out of commit messages by git, by default configuration.
    return this.props.messageBuffer.getText().replace(/^#.*$/gm, '').trim().length !== 0;
  }

  commitIsEnabled(amend) {
    return !this.props.isCommitting &&
      (amend || this.props.stagedChangesExist) &&
      !this.props.mergeConflictsExist &&
      this.props.lastCommit.isPresent() &&
      (this.props.deactivateCommitBox || (amend || this.isValidMessage()));
  }

  commitButtonText() {
    if (this.state.showWorking) {
      return 'Working...';
    } else if (this.props.currentBranch.isDetached()) {
      return 'Create detached commit';
    } else if (this.props.currentBranch.isPresent()) {
      return `Commit to ${this.props.currentBranch.getName()}`;
    } else {
      return 'Commit';
    }
  }

  toggleExpandedCommitMessageEditor() {
    return this.props.toggleExpandedCommitMessageEditor(this.props.messageBuffer.getText());
  }

  matchAuthors(authors, filterText, selectedAuthors) {
    const matchedAuthors = authors.filter((author, index) => {
      const isAlreadySelected = selectedAuthors && selectedAuthors.find(selected => selected.matches(author));
      const matchesFilter = [
        author.getLogin(),
        author.getFullName(),
        author.getEmail(),
      ].some(field => field && field.toLowerCase().indexOf(filterText.toLowerCase()) !== -1);

      return !isAlreadySelected && matchesFilter;
    });
    matchedAuthors.push(Author.createNew('Add new author', filterText));
    return matchedAuthors;
  }

  renderCoAuthorListItemField(fieldName, value) {
    if (!value || value.length === 0) {
      return null;
    }

    return (
      <span className={`github-CommitView-coAuthorEditor-${fieldName}`}>{value}</span>
    );
  }

  renderCoAuthorListItem(author) {
    return (
      <div className={cx('github-CommitView-coAuthorEditor-selectListItem', {'new-author': author.isNew()})}>
        {this.renderCoAuthorListItemField('name', author.getFullName())}
        {author.hasLogin() && this.renderCoAuthorListItemField('login', '@' + author.getLogin())}
        {this.renderCoAuthorListItemField('email', author.getEmail())}
      </div>
    );
  }

  renderCoAuthorValue(author) {
    const fullName = author.getFullName();
    if (fullName && fullName.length > 0) {
      return <span>{author.getFullName()}</span>;
    }
    if (author.hasLogin()) {
      return <span>@{author.getLogin()}</span>;
    }

    return <span>{author.getEmail()}</span>;
  }

  onSelectedCoAuthorsChanged(selectedCoAuthors) {
    incrementCounter('selected-co-authors-changed');
    const newAuthor = selectedCoAuthors.find(author => author.isNew());

    if (newAuthor) {
      this.setState({coAuthorInput: newAuthor.getFullName(), showCoAuthorForm: true});
    } else {
      this.props.updateSelectedCoAuthors(selectedCoAuthors);
    }
  }

  hasFocus() {
    return this.refRoot.map(element => element.contains(document.activeElement)).getOr(false);
  }

  getFocus(element) {
    if (this.refCommitPreviewButton.map(button => button.contains(element)).getOr(false)) {
      return CommitView.focus.COMMIT_PREVIEW_BUTTON;
    }

    if (this.refEditorComponent.map(editor => editor.contains(element)).getOr(false)) {
      return CommitView.focus.EDITOR;
    }

    if (this.refAbortMergeButton.map(e => e.contains(element)).getOr(false)) {
      return CommitView.focus.ABORT_MERGE_BUTTON;
    }

    if (this.refCommitButton.map(e => e.contains(element)).getOr(false)) {
      return CommitView.focus.COMMIT_BUTTON;
    }

    if (this.refCoAuthorSelect.map(c => c.wrapper && c.wrapper.contains(element)).getOr(false)) {
      return CommitView.focus.COAUTHOR_INPUT;
    }

    return null;
  }

  setFocus(focus) {
    let fallback = false;
    const focusElement = element => {
      element.focus();
      return true;
    };

    if (focus === CommitView.focus.COMMIT_PREVIEW_BUTTON) {
      if (this.refCommitPreviewButton.map(focusElement).getOr(false)) {
        return true;
      }
    }

    if (focus === CommitView.focus.EDITOR) {
      if (this.refEditorComponent.map(focusElement).getOr(false)) {
        if (this.props.messageBuffer.getText().length > 0 && !this.isValidMessage()) {
          // there is likely a commit message template present
          // we want the cursor to be at the beginning, not at the and of the template
          this.refEditorComponent.get().getModel().setCursorBufferPosition([0, 0]);
        }
        return true;
      }
    }

    if (focus === CommitView.focus.ABORT_MERGE_BUTTON) {
      if (this.refAbortMergeButton.map(focusElement).getOr(false)) {
        return true;
      }
      fallback = true;
    }

    if (focus === CommitView.focus.COMMIT_BUTTON) {
      if (this.refCommitButton.map(focusElement).getOr(false)) {
        return true;
      }
      fallback = true;
    }

    if (focus === CommitView.focus.COAUTHOR_INPUT) {
      if (this.refCoAuthorSelect.map(focusElement).getOr(false)) {
        return true;
      }
      fallback = true;
    }

    if (focus === CommitView.lastFocus) {
      if (this.commitIsEnabled(false)) {
        return this.setFocus(CommitView.focus.COMMIT_BUTTON);
      } else if (this.props.isMerging) {
        return this.setFocus(CommitView.focus.ABORT_MERGE_BUTTON);
      } else if (this.state.showCoAuthorInput) {
        return this.setFocus(CommitView.focus.COAUTHOR_INPUT);
      } else {
        return this.setFocus(CommitView.focus.EDITOR);
      }
    }

    if (fallback && this.refEditorComponent.map(focusElement).getOr(false)) {
      return true;
    }

    return false;
  }

  advanceFocusFrom(focus) {
    const f = this.constructor.focus;

    let next = null;
    switch (focus) {
    case f.COMMIT_PREVIEW_BUTTON:
      next = f.EDITOR;
      break;
    case f.EDITOR:
      if (this.state.showCoAuthorInput) {
        next = f.COAUTHOR_INPUT;
      } else if (this.props.isMerging) {
        next = f.ABORT_MERGE_BUTTON;
      } else if (this.commitIsEnabled(false)) {
        next = f.COMMIT_BUTTON;
      } else {
        next = RecentCommitsView.firstFocus;
      }
      break;
    case f.COAUTHOR_INPUT:
      if (this.props.isMerging) {
        next = f.ABORT_MERGE_BUTTON;
      } else if (this.commitIsEnabled(false)) {
        next = f.COMMIT_BUTTON;
      } else {
        next = RecentCommitsView.firstFocus;
      }
      break;
    case f.ABORT_MERGE_BUTTON:
      next = this.commitIsEnabled(false) ? f.COMMIT_BUTTON : RecentCommitsView.firstFocus;
      break;
    case f.COMMIT_BUTTON:
      next = RecentCommitsView.firstFocus;
      break;
    }

    return Promise.resolve(next);
  }

  retreatFocusFrom(focus) {
    const f = this.constructor.focus;

    let previous = null;
    switch (focus) {
    case f.COMMIT_BUTTON:
      if (this.props.isMerging) {
        previous = f.ABORT_MERGE_BUTTON;
      } else if (this.state.showCoAuthorInput) {
        previous = f.COAUTHOR_INPUT;
      } else {
        previous = f.EDITOR;
      }
      break;
    case f.ABORT_MERGE_BUTTON:
      previous = this.state.showCoAuthorInput ? f.COAUTHOR_INPUT : f.EDITOR;
      break;
    case f.COAUTHOR_INPUT:
      previous = f.EDITOR;
      break;
    case f.EDITOR:
      previous = f.COMMIT_PREVIEW_BUTTON;
      break;
    case f.COMMIT_PREVIEW_BUTTON:
      previous = StagingView.lastFocus;
      break;
    }

    return Promise.resolve(previous);
  }
}
