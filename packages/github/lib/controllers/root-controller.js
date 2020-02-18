import fs from 'fs-extra';
import path from 'path';
import {remote} from 'electron';

import React, {Fragment} from 'react';
import PropTypes from 'prop-types';
import {CompositeDisposable} from 'event-kit';
import yubikiri from 'yubikiri';

import StatusBar from '../atom/status-bar';
import PaneItem from '../atom/pane-item';
import {openIssueishItem} from '../views/open-issueish-dialog';
import {openCommitDetailItem} from '../views/open-commit-dialog';
import {createRepository, publishRepository} from '../views/create-dialog';
import ObserveModel from '../views/observe-model';
import Commands, {Command} from '../atom/commands';
import ChangedFileItem from '../items/changed-file-item';
import IssueishDetailItem from '../items/issueish-detail-item';
import CommitDetailItem from '../items/commit-detail-item';
import CommitPreviewItem from '../items/commit-preview-item';
import GitTabItem from '../items/git-tab-item';
import GitHubTabItem from '../items/github-tab-item';
import ReviewsItem from '../items/reviews-item';
import CommentDecorationsContainer from '../containers/comment-decorations-container';
import DialogsController, {dialogRequests} from './dialogs-controller';
import StatusBarTileController from './status-bar-tile-controller';
import RepositoryConflictController from './repository-conflict-controller';
import RelayNetworkLayerManager from '../relay-network-layer-manager';
import GitCacheView from '../views/git-cache-view';
import GitTimingsView from '../views/git-timings-view';
import Conflict from '../models/conflicts/conflict';
import {getEndpoint} from '../models/endpoint';
import Switchboard from '../switchboard';
import {WorkdirContextPoolPropType} from '../prop-types';
import {destroyFilePatchPaneItems, destroyEmptyFilePatchPaneItems, autobind} from '../helpers';
import {GitError} from '../git-shell-out-strategy';
import {incrementCounter, addEvent} from '../reporter-proxy';

export default class RootController extends React.Component {
  static propTypes = {
    // Atom enviornment
    workspace: PropTypes.object.isRequired,
    commands: PropTypes.object.isRequired,
    deserializers: PropTypes.object.isRequired,
    notificationManager: PropTypes.object.isRequired,
    tooltips: PropTypes.object.isRequired,
    keymaps: PropTypes.object.isRequired,
    grammars: PropTypes.object.isRequired,
    config: PropTypes.object.isRequired,
    project: PropTypes.object.isRequired,
    confirm: PropTypes.func.isRequired,
    currentWindow: PropTypes.object.isRequired,

    // Models
    loginModel: PropTypes.object.isRequired,
    workdirContextPool: WorkdirContextPoolPropType.isRequired,
    repository: PropTypes.object.isRequired,
    resolutionProgress: PropTypes.object.isRequired,
    statusBar: PropTypes.object,
    switchboard: PropTypes.instanceOf(Switchboard),
    pipelineManager: PropTypes.object,

    currentWorkDir: PropTypes.string,

    // Git actions
    initialize: PropTypes.func.isRequired,
    clone: PropTypes.func.isRequired,

    // Control
    contextLocked: PropTypes.bool.isRequired,
    changeWorkingDirectory: PropTypes.func.isRequired,
    setContextLock: PropTypes.func.isRequired,
    startOpen: PropTypes.bool,
    startRevealed: PropTypes.bool,
  }

  static defaultProps = {
    switchboard: new Switchboard(),
    startOpen: false,
    startRevealed: false,
  }

  constructor(props, context) {
    super(props, context);
    autobind(
      this,
      'installReactDevTools', 'clearGithubToken',
      'showWaterfallDiagnostics', 'showCacheDiagnostics',
      'destroyFilePatchPaneItems', 'destroyEmptyFilePatchPaneItems',
      'quietlySelectItem', 'viewUnstagedChangesForCurrentFile',
      'viewStagedChangesForCurrentFile', 'openFiles', 'getUnsavedFiles', 'ensureNoUnsavedFiles',
      'discardWorkDirChangesForPaths', 'discardLines', 'undoLastDiscard', 'refreshResolutionProgress',
    );

    this.state = {
      dialogRequest: dialogRequests.null,
    };

    this.gitTabTracker = new TabTracker('git', {
      uri: GitTabItem.buildURI(),
      getWorkspace: () => this.props.workspace,
    });

    this.githubTabTracker = new TabTracker('github', {
      uri: GitHubTabItem.buildURI(),
      getWorkspace: () => this.props.workspace,
    });

    this.subscription = new CompositeDisposable(
      this.props.repository.onPullError(this.gitTabTracker.ensureVisible),
    );

    this.props.commands.onDidDispatch(event => {
      if (event.type && event.type.startsWith('github:')
        && event.detail && event.detail[0] && event.detail[0].contextCommand) {
        addEvent('context-menu-action', {
          package: 'github',
          command: event.type,
        });
      }
    });
  }

  componentDidMount() {
    this.openTabs();
  }

  render() {
    return (
      <Fragment>
        {this.renderCommands()}
        {this.renderStatusBarTile()}
        {this.renderPaneItems()}
        {this.renderDialogs()}
        {this.renderConflictResolver()}
        {this.renderCommentDecorations()}
      </Fragment>
    );
  }

  renderCommands() {
    const devMode = global.atom && global.atom.inDevMode();

    return (
      <Fragment>
        <Commands registry={this.props.commands} target="atom-workspace">
          {devMode && <Command command="github:install-react-dev-tools" callback={this.installReactDevTools} />}
          <Command command="github:toggle-commit-preview" callback={this.toggleCommitPreviewItem} />
          <Command command="github:logout" callback={this.clearGithubToken} />
          <Command command="github:show-waterfall-diagnostics" callback={this.showWaterfallDiagnostics} />
          <Command command="github:show-cache-diagnostics" callback={this.showCacheDiagnostics} />
          <Command command="github:toggle-git-tab" callback={this.gitTabTracker.toggle} />
          <Command command="github:toggle-git-tab-focus" callback={this.gitTabTracker.toggleFocus} />
          <Command command="github:toggle-github-tab" callback={this.githubTabTracker.toggle} />
          <Command command="github:toggle-github-tab-focus" callback={this.githubTabTracker.toggleFocus} />
          <Command command="github:initialize" callback={() => this.openInitializeDialog()} />
          <Command command="github:clone" callback={() => this.openCloneDialog()} />
          <Command command="github:open-issue-or-pull-request" callback={() => this.openIssueishDialog()} />
          <Command command="github:open-commit" callback={() => this.openCommitDialog()} />
          <Command command="github:create-repository" callback={() => this.openCreateDialog()} />
          <Command
            command="github:view-unstaged-changes-for-current-file"
            callback={this.viewUnstagedChangesForCurrentFile}
          />
          <Command
            command="github:view-staged-changes-for-current-file"
            callback={this.viewStagedChangesForCurrentFile}
          />
          <Command
            command="github:close-all-diff-views"
            callback={this.destroyFilePatchPaneItems}
          />
          <Command
            command="github:close-empty-diff-views"
            callback={this.destroyEmptyFilePatchPaneItems}
          />
        </Commands>
        <ObserveModel model={this.props.repository} fetchData={this.fetchData}>
          {data => {
            if (!data || !data.isPublishable || !data.remotes.filter(r => r.isGithubRepo()).isEmpty()) {
              return null;
            }

            return (
              <Commands registry={this.props.commands} target="atom-workspace">
                <Command
                  command="github:publish-repository"
                  callback={() => this.openPublishDialog(this.props.repository)}
                />
              </Commands>
            );
          }}
        </ObserveModel>
      </Fragment>
    );
  }

  renderStatusBarTile() {
    return (
      <StatusBar
        statusBar={this.props.statusBar}
        onConsumeStatusBar={sb => this.onConsumeStatusBar(sb)}
        className="github-StatusBarTileController">
        <StatusBarTileController
          pipelineManager={this.props.pipelineManager}
          workspace={this.props.workspace}
          repository={this.props.repository}
          commands={this.props.commands}
          notificationManager={this.props.notificationManager}
          tooltips={this.props.tooltips}
          confirm={this.props.confirm}
          toggleGitTab={this.gitTabTracker.toggle}
          toggleGithubTab={this.githubTabTracker.toggle}
        />
      </StatusBar>
    );
  }

  renderDialogs() {
    return (
      <DialogsController
        loginModel={this.props.loginModel}
        request={this.state.dialogRequest}

        currentWindow={this.props.currentWindow}
        workspace={this.props.workspace}
        commands={this.props.commands}
        config={this.props.config}
      />
    );
  }

  renderCommentDecorations() {
    if (!this.props.repository) {
      return null;
    }
    return (
      <CommentDecorationsContainer
        workspace={this.props.workspace}
        commands={this.props.commands}
        localRepository={this.props.repository}
        loginModel={this.props.loginModel}
        reportRelayError={this.reportRelayError}
      />
    );
  }

  renderConflictResolver() {
    if (!this.props.repository) {
      return null;
    }

    return (
      <RepositoryConflictController
        workspace={this.props.workspace}
        config={this.props.config}
        repository={this.props.repository}
        resolutionProgress={this.props.resolutionProgress}
        refreshResolutionProgress={this.refreshResolutionProgress}
        commands={this.props.commands}
      />
    );
  }

  renderPaneItems() {
    const {workdirContextPool} = this.props;
    const getCurrentWorkDirs = workdirContextPool.getCurrentWorkDirs.bind(workdirContextPool);
    const onDidChangeWorkDirs = workdirContextPool.onDidChangePoolContexts.bind(workdirContextPool);

    return (
      <Fragment>
        <PaneItem
          workspace={this.props.workspace}
          uriPattern={GitTabItem.uriPattern}
          className="github-Git-root">
          {({itemHolder}) => (
            <GitTabItem
              ref={itemHolder.setter}
              workspace={this.props.workspace}
              commands={this.props.commands}
              notificationManager={this.props.notificationManager}
              tooltips={this.props.tooltips}
              grammars={this.props.grammars}
              project={this.props.project}
              confirm={this.props.confirm}
              config={this.props.config}
              repository={this.props.repository}
              loginModel={this.props.loginModel}
              openInitializeDialog={this.openInitializeDialog}
              resolutionProgress={this.props.resolutionProgress}
              ensureGitTab={this.gitTabTracker.ensureVisible}
              openFiles={this.openFiles}
              discardWorkDirChangesForPaths={this.discardWorkDirChangesForPaths}
              undoLastDiscard={this.undoLastDiscard}
              refreshResolutionProgress={this.refreshResolutionProgress}
              currentWorkDir={this.props.currentWorkDir}
              getCurrentWorkDirs={getCurrentWorkDirs}
              onDidChangeWorkDirs={onDidChangeWorkDirs}
              contextLocked={this.props.contextLocked}
              changeWorkingDirectory={this.props.changeWorkingDirectory}
              setContextLock={this.props.setContextLock}
            />
          )}
        </PaneItem>
        <PaneItem
          workspace={this.props.workspace}
          uriPattern={GitHubTabItem.uriPattern}
          className="github-GitHub-root">
          {({itemHolder}) => (
            <GitHubTabItem
              ref={itemHolder.setter}
              repository={this.props.repository}
              loginModel={this.props.loginModel}
              workspace={this.props.workspace}
              currentWorkDir={this.props.currentWorkDir}
              getCurrentWorkDirs={getCurrentWorkDirs}
              onDidChangeWorkDirs={onDidChangeWorkDirs}
              contextLocked={this.props.contextLocked}
              changeWorkingDirectory={this.props.changeWorkingDirectory}
              setContextLock={this.props.setContextLock}
              openCreateDialog={this.openCreateDialog}
              openPublishDialog={this.openPublishDialog}
              openCloneDialog={this.openCloneDialog}
              openGitTab={this.gitTabTracker.toggleFocus}
            />
          )}
        </PaneItem>
        <PaneItem
          workspace={this.props.workspace}
          uriPattern={ChangedFileItem.uriPattern}>
          {({itemHolder, params}) => (
            <ChangedFileItem
              ref={itemHolder.setter}

              workdirContextPool={this.props.workdirContextPool}
              relPath={path.join(...params.relPath)}
              workingDirectory={params.workingDirectory}
              stagingStatus={params.stagingStatus}

              tooltips={this.props.tooltips}
              commands={this.props.commands}
              keymaps={this.props.keymaps}
              workspace={this.props.workspace}
              config={this.props.config}

              discardLines={this.discardLines}
              undoLastDiscard={this.undoLastDiscard}
              surfaceFileAtPath={this.surfaceFromFileAtPath}
            />
          )}
        </PaneItem>
        <PaneItem
          workspace={this.props.workspace}
          uriPattern={CommitPreviewItem.uriPattern}
          className="github-CommitPreview-root">
          {({itemHolder, params}) => (
            <CommitPreviewItem
              ref={itemHolder.setter}

              workdirContextPool={this.props.workdirContextPool}
              workingDirectory={params.workingDirectory}
              workspace={this.props.workspace}
              commands={this.props.commands}
              keymaps={this.props.keymaps}
              tooltips={this.props.tooltips}
              config={this.props.config}

              discardLines={this.discardLines}
              undoLastDiscard={this.undoLastDiscard}
              surfaceToCommitPreviewButton={this.surfaceToCommitPreviewButton}
            />
          )}
        </PaneItem>
        <PaneItem
          workspace={this.props.workspace}
          uriPattern={CommitDetailItem.uriPattern}
          className="github-CommitDetail-root">
          {({itemHolder, params}) => (
            <CommitDetailItem
              ref={itemHolder.setter}

              workdirContextPool={this.props.workdirContextPool}
              workingDirectory={params.workingDirectory}
              workspace={this.props.workspace}
              commands={this.props.commands}
              keymaps={this.props.keymaps}
              tooltips={this.props.tooltips}
              config={this.props.config}

              sha={params.sha}
              surfaceCommit={this.surfaceToRecentCommit}
            />
          )}
        </PaneItem>
        <PaneItem workspace={this.props.workspace} uriPattern={IssueishDetailItem.uriPattern}>
          {({itemHolder, params, deserialized}) => (
            <IssueishDetailItem
              ref={itemHolder.setter}

              host={params.host}
              owner={params.owner}
              repo={params.repo}
              issueishNumber={parseInt(params.issueishNumber, 10)}

              workingDirectory={params.workingDirectory}
              workdirContextPool={this.props.workdirContextPool}
              loginModel={this.props.loginModel}
              initSelectedTab={deserialized.initSelectedTab}

              workspace={this.props.workspace}
              commands={this.props.commands}
              keymaps={this.props.keymaps}
              tooltips={this.props.tooltips}
              config={this.props.config}

              reportRelayError={this.reportRelayError}
            />
          )}
        </PaneItem>
        <PaneItem workspace={this.props.workspace} uriPattern={ReviewsItem.uriPattern}>
          {({itemHolder, params}) => (
            <ReviewsItem
              ref={itemHolder.setter}

              host={params.host}
              owner={params.owner}
              repo={params.repo}
              number={parseInt(params.number, 10)}

              workdir={params.workdir}
              workdirContextPool={this.props.workdirContextPool}
              loginModel={this.props.loginModel}
              workspace={this.props.workspace}
              tooltips={this.props.tooltips}
              config={this.props.config}
              commands={this.props.commands}
              confirm={this.props.confirm}
              reportRelayError={this.reportRelayError}
            />
          )}
        </PaneItem>
        <PaneItem workspace={this.props.workspace} uriPattern={GitTimingsView.uriPattern}>
          {({itemHolder}) => <GitTimingsView ref={itemHolder.setter} />}
        </PaneItem>
        <PaneItem workspace={this.props.workspace} uriPattern={GitCacheView.uriPattern}>
          {({itemHolder}) => <GitCacheView ref={itemHolder.setter} repository={this.props.repository} />}
        </PaneItem>
      </Fragment>
    );
  }

  fetchData = repository => yubikiri({
    isPublishable: repository.isPublishable(),
    remotes: repository.getRemotes(),
  });

  async openTabs() {
    if (this.props.startOpen) {
      await Promise.all([
        this.gitTabTracker.ensureRendered(false),
        this.githubTabTracker.ensureRendered(false),
      ]);
    }

    if (this.props.startRevealed) {
      const docks = new Set(
        [GitTabItem.buildURI(), GitHubTabItem.buildURI()]
          .map(uri => this.props.workspace.paneContainerForURI(uri))
          .filter(container => container && (typeof container.show) === 'function'),
      );

      for (const dock of docks) {
        dock.show();
      }
    }
  }

  async installReactDevTools() {
    // Prevent electron-link from attempting to descend into electron-devtools-installer, which is not available
    // when we're bundled in Atom.
    const devToolsName = 'electron-devtools-installer';
    const devTools = require(devToolsName);

    await Promise.all([
      this.installExtension(devTools.REACT_DEVELOPER_TOOLS.id),
      // relay developer tools extension id
      this.installExtension('ncedobpgnmkhcmnnkcimnobpfepidadl'),
    ]);

    this.props.notificationManager.addSuccess('🌈 Reload your window to start using the React/Relay dev tools!');
  }

  async installExtension(id) {
    const devToolsName = 'electron-devtools-installer';
    const devTools = require(devToolsName);

    const crossUnzipName = 'cross-unzip';
    const unzip = require(crossUnzipName);

    const url =
      'https://clients2.google.com/service/update2/crx?' +
      `response=redirect&x=id%3D${id}%26uc&prodversion=32`;
    const extensionFolder = path.resolve(remote.app.getPath('userData'), `extensions/${id}`);
    const extensionFile = `${extensionFolder}.crx`;
    await fs.ensureDir(path.dirname(extensionFile));
    const response = await fetch(url, {method: 'GET'});
    const body = Buffer.from(await response.arrayBuffer());
    await fs.writeFile(extensionFile, body);

    await new Promise((resolve, reject) => {
      unzip(extensionFile, extensionFolder, async err => {
        if (err && !await fs.exists(path.join(extensionFolder, 'manifest.json'))) {
          reject(err);
        }

        resolve();
      });
    });

    await fs.ensureDir(extensionFolder, 0o755);
    await devTools.default(id);
  }

  componentWillUnmount() {
    this.subscription.dispose();
  }

  componentDidUpdate() {
    this.subscription.dispose();
    this.subscription = new CompositeDisposable(
      this.props.repository.onPullError(() => this.gitTabTracker.ensureVisible()),
    );
  }

  onConsumeStatusBar(statusBar) {
    if (statusBar.disableGitInfoTile) {
      statusBar.disableGitInfoTile();
    }
  }

  clearGithubToken() {
    return this.props.loginModel.removeToken('https://api.github.com');
  }

  closeDialog = () => new Promise(resolve => this.setState({dialogRequest: dialogRequests.null}, resolve));

  openInitializeDialog = async dirPath => {
    if (!dirPath) {
      const activeEditor = this.props.workspace.getActiveTextEditor();
      if (activeEditor) {
        const [projectPath] = this.props.project.relativizePath(activeEditor.getPath());
        if (projectPath) {
          dirPath = projectPath;
        }
      }
    }

    if (!dirPath) {
      const directories = this.props.project.getDirectories();
      const withRepositories = await Promise.all(
        directories.map(async d => [d, await this.props.project.repositoryForDirectory(d)]),
      );
      const firstUninitialized = withRepositories.find(([d, r]) => !r);
      if (firstUninitialized && firstUninitialized[0]) {
        dirPath = firstUninitialized[0].getPath();
      }
    }

    if (!dirPath) {
      dirPath = this.props.config.get('core.projectHome');
    }

    const dialogRequest = dialogRequests.init({dirPath});
    dialogRequest.onProgressingAccept(async chosenPath => {
      await this.props.initialize(chosenPath);
      await this.closeDialog();
    });
    dialogRequest.onCancel(this.closeDialog);

    return new Promise(resolve => this.setState({dialogRequest}, resolve));
  }

  openCloneDialog = opts => {
    const dialogRequest = dialogRequests.clone(opts);
    dialogRequest.onProgressingAccept(async (url, chosenPath) => {
      await this.props.clone(url, chosenPath);
      await this.closeDialog();
    });
    dialogRequest.onCancel(this.closeDialog);

    return new Promise(resolve => this.setState({dialogRequest}, resolve));
  }

  openCredentialsDialog = query => {
    return new Promise((resolve, reject) => {
      const dialogRequest = dialogRequests.credential(query);
      dialogRequest.onProgressingAccept(async result => {
        resolve(result);
        await this.closeDialog();
      });
      dialogRequest.onCancel(async () => {
        reject();
        await this.closeDialog();
      });

      this.setState({dialogRequest});
    });
  }

  openIssueishDialog = () => {
    const dialogRequest = dialogRequests.issueish();
    dialogRequest.onProgressingAccept(async url => {
      await openIssueishItem(url, {
        workspace: this.props.workspace,
        workdir: this.props.repository.getWorkingDirectoryPath(),
      });
      await this.closeDialog();
    });
    dialogRequest.onCancel(this.closeDialog);

    return new Promise(resolve => this.setState({dialogRequest}, resolve));
  }

  openCommitDialog = () => {
    const dialogRequest = dialogRequests.commit();
    dialogRequest.onProgressingAccept(async ref => {
      await openCommitDetailItem(ref, {
        workspace: this.props.workspace,
        repository: this.props.repository,
      });
      await this.closeDialog();
    });
    dialogRequest.onCancel(this.closeDialog);

    return new Promise(resolve => this.setState({dialogRequest}, resolve));
  }

  openCreateDialog = () => {
    const dialogRequest = dialogRequests.create();
    dialogRequest.onProgressingAccept(async result => {
      const dotcom = getEndpoint('github.com');
      const relayEnvironment = RelayNetworkLayerManager.getEnvironmentForHost(dotcom);

      await createRepository(result, {clone: this.props.clone, relayEnvironment});
      await this.closeDialog();
    });
    dialogRequest.onCancel(this.closeDialog);

    return new Promise(resolve => this.setState({dialogRequest}, resolve));
  }

  openPublishDialog = repository => {
    const dialogRequest = dialogRequests.publish({localDir: repository.getWorkingDirectoryPath()});
    dialogRequest.onProgressingAccept(async result => {
      const dotcom = getEndpoint('github.com');
      const relayEnvironment = RelayNetworkLayerManager.getEnvironmentForHost(dotcom);

      await publishRepository(result, {repository, relayEnvironment});
      await this.closeDialog();
    });
    dialogRequest.onCancel(this.closeDialog);

    return new Promise(resolve => this.setState({dialogRequest}, resolve));
  }

  toggleCommitPreviewItem = () => {
    const workdir = this.props.repository.getWorkingDirectoryPath();
    return this.props.workspace.toggle(CommitPreviewItem.buildURI(workdir));
  }

  showWaterfallDiagnostics() {
    this.props.workspace.open(GitTimingsView.buildURI());
  }

  showCacheDiagnostics() {
    this.props.workspace.open(GitCacheView.buildURI());
  }

  surfaceFromFileAtPath = (filePath, stagingStatus) => {
    const gitTab = this.gitTabTracker.getComponent();
    return gitTab && gitTab.focusAndSelectStagingItem(filePath, stagingStatus);
  }

  surfaceToCommitPreviewButton = () => {
    const gitTab = this.gitTabTracker.getComponent();
    return gitTab && gitTab.focusAndSelectCommitPreviewButton();
  }

  surfaceToRecentCommit = () => {
    const gitTab = this.gitTabTracker.getComponent();
    return gitTab && gitTab.focusAndSelectRecentCommit();
  }

  destroyFilePatchPaneItems() {
    destroyFilePatchPaneItems({onlyStaged: false}, this.props.workspace);
  }

  destroyEmptyFilePatchPaneItems() {
    destroyEmptyFilePatchPaneItems(this.props.workspace);
  }

  quietlySelectItem(filePath, stagingStatus) {
    const gitTab = this.gitTabTracker.getComponent();
    return gitTab && gitTab.quietlySelectItem(filePath, stagingStatus);
  }

  async viewChangesForCurrentFile(stagingStatus) {
    const editor = this.props.workspace.getActiveTextEditor();
    if (!editor.getPath()) { return; }

    const absFilePath = await fs.realpath(editor.getPath());
    const repoPath = this.props.repository.getWorkingDirectoryPath();
    if (repoPath === null) {
      const [projectPath] = this.props.project.relativizePath(editor.getPath());
      const notification = this.props.notificationManager.addInfo(
        "Hmm, there's nothing to compare this file to",
        {
          description: 'You can create a Git repository to track changes to the files in your project.',
          dismissable: true,
          buttons: [{
            className: 'btn btn-primary',
            text: 'Create a repository now',
            onDidClick: async () => {
              notification.dismiss();
              const createdPath = await this.initializeRepo(projectPath);
              // If the user confirmed repository creation for this project path,
              // retry the operation that got them here in the first place
              if (createdPath === projectPath) { this.viewChangesForCurrentFile(stagingStatus); }
            },
          }],
        },
      );
      return;
    }
    if (absFilePath.startsWith(repoPath)) {
      const filePath = absFilePath.slice(repoPath.length + 1);
      this.quietlySelectItem(filePath, stagingStatus);
      const splitDirection = this.props.config.get('github.viewChangesForCurrentFileDiffPaneSplitDirection');
      const pane = this.props.workspace.getActivePane();
      if (splitDirection === 'right') {
        pane.splitRight();
      } else if (splitDirection === 'down') {
        pane.splitDown();
      }
      const lineNum = editor.getCursorBufferPosition().row + 1;
      const item = await this.props.workspace.open(
        ChangedFileItem.buildURI(filePath, repoPath, stagingStatus),
        {pending: true, activatePane: true, activateItem: true},
      );
      await item.getRealItemPromise();
      await item.getFilePatchLoadedPromise();
      item.goToDiffLine(lineNum);
      item.focus();
    } else {
      throw new Error(`${absFilePath} does not belong to repo ${repoPath}`);
    }
  }

  viewUnstagedChangesForCurrentFile() {
    return this.viewChangesForCurrentFile('unstaged');
  }

  viewStagedChangesForCurrentFile() {
    return this.viewChangesForCurrentFile('staged');
  }

  openFiles(filePaths, repository = this.props.repository) {
    return Promise.all(filePaths.map(filePath => {
      const absolutePath = path.join(repository.getWorkingDirectoryPath(), filePath);
      return this.props.workspace.open(absolutePath, {pending: filePaths.length === 1});
    }));
  }

  getUnsavedFiles(filePaths, workdirPath) {
    const isModifiedByPath = new Map();
    this.props.workspace.getTextEditors().forEach(editor => {
      isModifiedByPath.set(editor.getPath(), editor.isModified());
    });
    return filePaths.filter(filePath => {
      const absFilePath = path.join(workdirPath, filePath);
      return isModifiedByPath.get(absFilePath);
    });
  }

  ensureNoUnsavedFiles(filePaths, message, workdirPath = this.props.repository.getWorkingDirectoryPath()) {
    const unsavedFiles = this.getUnsavedFiles(filePaths, workdirPath).map(filePath => `\`${filePath}\``).join('<br>');
    if (unsavedFiles.length) {
      this.props.notificationManager.addError(
        message,
        {
          description: `You have unsaved changes in:<br>${unsavedFiles}.`,
          dismissable: true,
        },
      );
      return false;
    } else {
      return true;
    }
  }

  async discardWorkDirChangesForPaths(filePaths) {
    const destructiveAction = () => {
      return this.props.repository.discardWorkDirChangesForPaths(filePaths);
    };
    return await this.props.repository.storeBeforeAndAfterBlobs(
      filePaths,
      () => this.ensureNoUnsavedFiles(filePaths, 'Cannot discard changes in selected files.'),
      destructiveAction,
    );
  }

  async discardLines(multiFilePatch, lines, repository = this.props.repository) {
    // (kuychaco) For now we only support discarding rows for MultiFilePatches that contain a single file patch
    // The only way to access this method from the UI is to be in a ChangedFileItem, which only has a single file patch
    if (multiFilePatch.getFilePatches().length !== 1) {
      return Promise.resolve(null);
    }

    const filePath = multiFilePatch.getFilePatches()[0].getPath();
    const destructiveAction = async () => {
      const discardFilePatch = multiFilePatch.getUnstagePatchForLines(lines);
      await repository.applyPatchToWorkdir(discardFilePatch);
    };
    return await repository.storeBeforeAndAfterBlobs(
      [filePath],
      () => this.ensureNoUnsavedFiles([filePath], 'Cannot discard lines.', repository.getWorkingDirectoryPath()),
      destructiveAction,
      filePath,
    );
  }

  getFilePathsForLastDiscard(partialDiscardFilePath = null) {
    let lastSnapshots = this.props.repository.getLastHistorySnapshots(partialDiscardFilePath);
    if (partialDiscardFilePath) {
      lastSnapshots = lastSnapshots ? [lastSnapshots] : [];
    }
    return lastSnapshots.map(snapshot => snapshot.filePath);
  }

  async undoLastDiscard(partialDiscardFilePath = null, repository = this.props.repository) {
    const filePaths = this.getFilePathsForLastDiscard(partialDiscardFilePath);
    try {
      const results = await repository.restoreLastDiscardInTempFiles(
        () => this.ensureNoUnsavedFiles(filePaths, 'Cannot undo last discard.'),
        partialDiscardFilePath,
      );
      if (results.length === 0) { return; }
      await this.proceedOrPromptBasedOnResults(results, partialDiscardFilePath);
    } catch (e) {
      if (e instanceof GitError && e.stdErr.match(/fatal: Not a valid object name/)) {
        this.cleanUpHistoryForFilePaths(filePaths, partialDiscardFilePath);
      } else {
        // eslint-disable-next-line no-console
        console.error(e);
      }
    }
  }

  async proceedOrPromptBasedOnResults(results, partialDiscardFilePath = null) {
    const conflicts = results.filter(({conflict}) => conflict);
    if (conflicts.length === 0) {
      await this.proceedWithLastDiscardUndo(results, partialDiscardFilePath);
    } else {
      await this.promptAboutConflicts(results, conflicts, partialDiscardFilePath);
    }
  }

  async promptAboutConflicts(results, conflicts, partialDiscardFilePath = null) {
    const conflictedFiles = conflicts.map(({filePath}) => `\t${filePath}`).join('\n');
    const choice = this.props.confirm({
      message: 'Undoing will result in conflicts...',
      detailedMessage: `for the following files:\n${conflictedFiles}\n` +
        'Would you like to apply the changes with merge conflict markers, ' +
        'or open the text with merge conflict markers in a new file?',
      buttons: ['Merge with conflict markers', 'Open in new file', 'Cancel'],
    });
    if (choice === 0) {
      await this.proceedWithLastDiscardUndo(results, partialDiscardFilePath);
    } else if (choice === 1) {
      await this.openConflictsInNewEditors(conflicts.map(({resultPath}) => resultPath));
    }
  }

  cleanUpHistoryForFilePaths(filePaths, partialDiscardFilePath = null) {
    this.props.repository.clearDiscardHistory(partialDiscardFilePath);
    const filePathsStr = filePaths.map(filePath => `\`${filePath}\``).join('<br>');
    this.props.notificationManager.addError(
      'Discard history has expired.',
      {
        description: `Cannot undo discard for<br>${filePathsStr}<br>Stale discard history has been deleted.`,
        dismissable: true,
      },
    );
  }

  async proceedWithLastDiscardUndo(results, partialDiscardFilePath = null) {
    const promises = results.map(async result => {
      const {filePath, resultPath, deleted, conflict, theirsSha, commonBaseSha, currentSha} = result;
      const absFilePath = path.join(this.props.repository.getWorkingDirectoryPath(), filePath);
      if (deleted && resultPath === null) {
        await fs.remove(absFilePath);
      } else {
        await fs.copy(resultPath, absFilePath);
      }
      if (conflict) {
        await this.props.repository.writeMergeConflictToIndex(filePath, commonBaseSha, currentSha, theirsSha);
      }
    });
    await Promise.all(promises);
    await this.props.repository.popDiscardHistory(partialDiscardFilePath);
  }

  async openConflictsInNewEditors(resultPaths) {
    const editorPromises = resultPaths.map(resultPath => {
      return this.props.workspace.open(resultPath);
    });
    return await Promise.all(editorPromises);
  }

  reportRelayError = (friendlyMessage, err) => {
    const opts = {dismissable: true};

    if (err.network) {
      // Offline
      opts.icon = 'alignment-unalign';
      opts.description = "It looks like you're offline right now.";
    } else if (err.responseText) {
      // Transient error like a 500 from the API
      opts.description = 'The GitHub API reported a problem.';
      opts.detail = err.responseText;
    } else if (err.errors) {
      // GraphQL errors
      opts.detail = err.errors.map(e => e.message).join('\n');
    } else {
      opts.detail = err.stack;
    }

    this.props.notificationManager.addError(friendlyMessage, opts);
  }

  /*
   * Asynchronously count the conflict markers present in a file specified by full path.
   */
  refreshResolutionProgress(fullPath) {
    const readStream = fs.createReadStream(fullPath, {encoding: 'utf8'});
    return new Promise(resolve => {
      Conflict.countFromStream(readStream).then(count => {
        this.props.resolutionProgress.reportMarkerCount(fullPath, count);
      });
    });
  }
}

class TabTracker {
  constructor(name, {getWorkspace, uri}) {
    autobind(this, 'toggle', 'toggleFocus', 'ensureVisible');
    this.name = name;

    this.getWorkspace = getWorkspace;
    this.uri = uri;
  }

  async toggle() {
    const focusToRestore = document.activeElement;
    let shouldRestoreFocus = false;

    // Rendered => the dock item is being rendered, whether or not the dock is visible or the item
    //   is visible within its dock.
    // Visible => the item is active and the dock item is active within its dock.
    const wasRendered = this.isRendered();
    const wasVisible = this.isVisible();

    if (!wasRendered || !wasVisible) {
      // Not rendered, or rendered but not an active item in a visible dock.
      await this.reveal();
      shouldRestoreFocus = true;
    } else {
      // Rendered and an active item within a visible dock.
      await this.hide();
      shouldRestoreFocus = false;
    }

    if (shouldRestoreFocus) {
      process.nextTick(() => focusToRestore.focus());
    }
  }

  async toggleFocus() {
    const hadFocus = this.hasFocus();
    await this.ensureVisible();

    if (hadFocus) {
      let workspace = this.getWorkspace();
      if (workspace.getCenter) {
        workspace = workspace.getCenter();
      }
      workspace.getActivePane().activate();
    } else {
      this.focus();
    }
  }

  async ensureVisible() {
    if (!this.isVisible()) {
      await this.reveal();
      return true;
    }
    return false;
  }

  ensureRendered() {
    return this.getWorkspace().open(this.uri, {searchAllPanes: true, activateItem: false, activatePane: false});
  }

  reveal() {
    incrementCounter(`${this.name}-tab-open`);
    return this.getWorkspace().open(this.uri, {searchAllPanes: true, activateItem: true, activatePane: true});
  }

  hide() {
    incrementCounter(`${this.name}-tab-close`);
    return this.getWorkspace().hide(this.uri);
  }

  focus() {
    this.getComponent().restoreFocus();
  }

  getItem() {
    const pane = this.getWorkspace().paneForURI(this.uri);
    if (!pane) {
      return null;
    }

    const paneItem = pane.itemForURI(this.uri);
    if (!paneItem) {
      return null;
    }

    return paneItem;
  }

  getComponent() {
    const paneItem = this.getItem();
    if (!paneItem) {
      return null;
    }
    if (((typeof paneItem.getRealItem) !== 'function')) {
      return null;
    }

    return paneItem.getRealItem();
  }

  getDOMElement() {
    const paneItem = this.getItem();
    if (!paneItem) {
      return null;
    }
    if (((typeof paneItem.getElement) !== 'function')) {
      return null;
    }

    return paneItem.getElement();
  }

  isRendered() {
    return !!this.getWorkspace().paneForURI(this.uri);
  }

  isVisible() {
    const workspace = this.getWorkspace();
    return workspace.getPaneContainers()
      .filter(container => container === workspace.getCenter() || container.isVisible())
      .some(container => container.getPanes().some(pane => {
        const item = pane.getActiveItem();
        return item && item.getURI && item.getURI() === this.uri;
      }));
  }

  hasFocus() {
    const root = this.getDOMElement();
    return root && root.contains(document.activeElement);
  }
}
