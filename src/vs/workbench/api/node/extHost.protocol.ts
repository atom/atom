/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { CancellationToken } from 'vs/base/common/cancellation';
import { SerializedError } from 'vs/base/common/errors';
import { IDisposable } from 'vs/base/common/lifecycle';
import Severity from 'vs/base/common/severity';
import { URI, UriComponents } from 'vs/base/common/uri';
import { TextEditorCursorStyle } from 'vs/editor/common/config/editorOptions';
import { IPosition } from 'vs/editor/common/core/position';
import { IRange } from 'vs/editor/common/core/range';
import { ISelection, Selection } from 'vs/editor/common/core/selection';
import * as editorCommon from 'vs/editor/common/editorCommon';
import { ISingleEditOperation } from 'vs/editor/common/model';
import { IModelChangedEvent } from 'vs/editor/common/model/mirrorTextModel';
import * as modes from 'vs/editor/common/modes';
import { CharacterPair, CommentRule, EnterAction } from 'vs/editor/common/modes/languageConfiguration';
import { ICommandHandlerDescription } from 'vs/platform/commands/common/commands';
import { ConfigurationTarget, IConfigurationData, IConfigurationModel } from 'vs/platform/configuration/common/configuration';
import { ConfigurationScope } from 'vs/platform/configuration/common/configurationRegistry';
import { FileChangeType, FileDeleteOptions, FileOverwriteOptions, FileSystemProviderCapabilities, FileType, FileWriteOptions, IStat, IWatchOptions } from 'vs/platform/files/common/files';
import { LabelRules } from 'vs/platform/label/common/label';
import { LogLevel } from 'vs/platform/log/common/log';
import { IMarkerData } from 'vs/platform/markers/common/markers';
import { IPickOptions, IQuickInputButton, IQuickPickItem } from 'vs/platform/quickinput/common/quickInput';
import { IPatternInfo, IRawFileMatch2, IRawQuery, IRawTextQuery, ISearchCompleteStats } from 'vs/platform/search/common/search';
import { StatusbarAlignment as MainThreadStatusBarAlignment } from 'vs/platform/statusbar/common/statusbar';
import { ITelemetryInfo } from 'vs/platform/telemetry/common/telemetry';
import { ThemeColor } from 'vs/platform/theme/common/themeService';
import { EndOfLine, IFileOperationOptions, TextEditorLineNumbersStyle } from 'vs/workbench/api/node/extHostTypes';
import { EditorViewColumn } from 'vs/workbench/api/shared/editor';
import { TaskDTO, TaskExecutionDTO, TaskFilterDTO, TaskHandleDTO, TaskProcessEndedDTO, TaskProcessStartedDTO, TaskSystemInfoDTO } from 'vs/workbench/api/shared/tasks';
import { ITreeItem, IRevealOptions } from 'vs/workbench/common/views';
import { IAdapterDescriptor, IConfig, ITerminalSettings } from 'vs/workbench/parts/debug/common/debug';
import { ITextQueryBuilderOptions } from 'vs/workbench/parts/search/common/queryBuilder';
import { TaskSet } from 'vs/workbench/parts/tasks/common/tasks';
import { ITerminalDimensions } from 'vs/workbench/parts/terminal/common/terminal';
import { IExtensionDescription } from 'vs/workbench/services/extensions/common/extensions';
import { IRPCProtocol, ProxyIdentifier, createExtHostContextProxyIdentifier as createExtId, createMainContextProxyIdentifier as createMainId } from 'vs/workbench/services/extensions/node/proxyIdentifier';
import { IProgressOptions, IProgressStep } from 'vs/platform/progress/common/progress';
import { SaveReason } from 'vs/workbench/services/textfile/common/textfiles';
import * as vscode from 'vscode';
import { IMarkdownString } from 'vs/base/common/htmlContent';

export interface IEnvironment {
	isExtensionDevelopmentDebug: boolean;
	appRoot: URI;
	appSettingsHome: URI;
	extensionDevelopmentLocationURI: URI;
	extensionTestsPath: string;
}

export interface IWorkspaceData {
	id: string;
	name: string;
	folders: { uri: UriComponents, name: string, index: number }[];
	configuration?: UriComponents;
}

export interface IInitData {
	commit: string;
	parentPid: number;
	environment: IEnvironment;
	workspace: IWorkspaceData;
	extensions: IExtensionDescription[];
	configuration: IConfigurationInitData;
	telemetryInfo: ITelemetryInfo;
	logLevel: LogLevel;
	logsLocation: URI;
	remoteAuthority?: string | null;
}

export interface IConfigurationInitData extends IConfigurationData {
	configurationScopes: { [key: string]: ConfigurationScope };
}

export interface IWorkspaceConfigurationChangeEventData {
	changedConfiguration: IConfigurationModel;
	changedConfigurationByResource: { [folder: string]: IConfigurationModel };
}

export interface IExtHostContext extends IRPCProtocol {
	remoteAuthority: string;
}

export interface IMainContext extends IRPCProtocol {
}

// --- main thread

export interface MainThreadClipboardShape extends IDisposable {
	$readText(): Promise<string>;
	$writeText(value: string): Promise<void>;
}

export interface MainThreadCommandsShape extends IDisposable {
	$registerCommand(id: string): void;
	$unregisterCommand(id: string): void;
	$executeCommand<T>(id: string, args: any[]): Thenable<T>;
	$getCommands(): Thenable<string[]>;
}

export interface MainThreadCommentsShape extends IDisposable {
	$registerDocumentCommentProvider(handle: number): void;
	$unregisterDocumentCommentProvider(handle: number): void;
	$registerWorkspaceCommentProvider(handle: number, extensionId: string): void;
	$unregisterWorkspaceCommentProvider(handle: number): void;
	$onDidCommentThreadsChange(handle: number, event: modes.CommentThreadChangedEvent): void;
}

export interface MainThreadConfigurationShape extends IDisposable {
	$updateConfigurationOption(target: ConfigurationTarget, key: string, value: any, resource: UriComponents): Thenable<void>;
	$removeConfigurationOption(target: ConfigurationTarget, key: string, resource: UriComponents): Thenable<void>;
}

export interface MainThreadDiagnosticsShape extends IDisposable {
	$changeMany(owner: string, entries: [UriComponents, IMarkerData[]][]): void;
	$clear(owner: string): void;
}

export interface MainThreadDialogOpenOptions {
	defaultUri?: UriComponents;
	openLabel?: string;
	canSelectFiles?: boolean;
	canSelectFolders?: boolean;
	canSelectMany?: boolean;
	filters?: { [name: string]: string[] };
}

export interface MainThreadDialogSaveOptions {
	defaultUri?: UriComponents;
	saveLabel?: string;
	filters?: { [name: string]: string[] };
}

export interface MainThreadDiaglogsShape extends IDisposable {
	$showOpenDialog(options: MainThreadDialogOpenOptions): Thenable<UriComponents[]>;
	$showSaveDialog(options: MainThreadDialogSaveOptions): Thenable<UriComponents>;
}

export interface MainThreadDecorationsShape extends IDisposable {
	$registerDecorationProvider(handle: number, label: string): void;
	$unregisterDecorationProvider(handle: number): void;
	$onDidChange(handle: number, resources: UriComponents[]): void;
}

export interface MainThreadDocumentContentProvidersShape extends IDisposable {
	$registerTextContentProvider(handle: number, scheme: string): void;
	$unregisterTextContentProvider(handle: number): void;
	$onVirtualDocumentChange(uri: UriComponents, value: string): void;
}

export interface MainThreadDocumentsShape extends IDisposable {
	$tryCreateDocument(options?: { language?: string; content?: string; }): Thenable<UriComponents>;
	$tryOpenDocument(uri: UriComponents): Thenable<void>;
	$trySaveDocument(uri: UriComponents): Thenable<boolean>;
}

export interface ITextEditorConfigurationUpdate {
	tabSize?: number | 'auto';
	insertSpaces?: boolean | 'auto';
	cursorStyle?: TextEditorCursorStyle;
	lineNumbers?: TextEditorLineNumbersStyle;
}

export interface IResolvedTextEditorConfiguration {
	tabSize: number;
	insertSpaces: boolean;
	cursorStyle: TextEditorCursorStyle;
	lineNumbers: TextEditorLineNumbersStyle;
}

export enum TextEditorRevealType {
	Default = 0,
	InCenter = 1,
	InCenterIfOutsideViewport = 2,
	AtTop = 3
}

export interface IUndoStopOptions {
	undoStopBefore: boolean;
	undoStopAfter: boolean;
}

export interface IApplyEditsOptions extends IUndoStopOptions {
	setEndOfLine: EndOfLine;
}

export interface ITextDocumentShowOptions {
	position?: EditorViewColumn;
	preserveFocus?: boolean;
	pinned?: boolean;
	selection?: IRange;
}

export interface MainThreadTextEditorsShape extends IDisposable {
	$tryShowTextDocument(resource: UriComponents, options: ITextDocumentShowOptions): Thenable<string>;
	$registerTextEditorDecorationType(key: string, options: editorCommon.IDecorationRenderOptions): void;
	$removeTextEditorDecorationType(key: string): void;
	$tryShowEditor(id: string, position: EditorViewColumn): Thenable<void>;
	$tryHideEditor(id: string): Thenable<void>;
	$trySetOptions(id: string, options: ITextEditorConfigurationUpdate): Thenable<void>;
	$trySetDecorations(id: string, key: string, ranges: editorCommon.IDecorationOptions[]): Thenable<void>;
	$trySetDecorationsFast(id: string, key: string, ranges: number[]): Thenable<void>;
	$tryRevealRange(id: string, range: IRange, revealType: TextEditorRevealType): Thenable<void>;
	$trySetSelections(id: string, selections: ISelection[]): Thenable<void>;
	$tryApplyEdits(id: string, modelVersionId: number, edits: ISingleEditOperation[], opts: IApplyEditsOptions): Thenable<boolean>;
	$tryApplyWorkspaceEdit(workspaceEditDto: WorkspaceEditDto): Thenable<boolean>;
	$tryInsertSnippet(id: string, template: string, selections: IRange[], opts: IUndoStopOptions): Thenable<boolean>;
	$getDiffInformation(id: string): Thenable<editorCommon.ILineChange[]>;
}

export interface MainThreadTreeViewsShape extends IDisposable {
	$registerTreeViewDataProvider(treeViewId: string, options: { showCollapseAll: boolean }): void;
	$refresh(treeViewId: string, itemsToRefresh?: { [treeItemHandle: string]: ITreeItem }): Thenable<void>;
	$reveal(treeViewId: string, treeItem: ITreeItem, parentChain: ITreeItem[], options: IRevealOptions): Thenable<void>;
	$setMessage(treeViewId: string, message: string | IMarkdownString): void;
}

export interface MainThreadErrorsShape extends IDisposable {
	$onUnexpectedError(err: any | SerializedError): void;
}

export interface ISerializedRegExp {
	pattern: string;
	flags?: string;
}
export interface ISerializedIndentationRule {
	decreaseIndentPattern: ISerializedRegExp;
	increaseIndentPattern: ISerializedRegExp;
	indentNextLinePattern?: ISerializedRegExp;
	unIndentedLinePattern?: ISerializedRegExp;
}
export interface ISerializedOnEnterRule {
	beforeText: ISerializedRegExp;
	afterText?: ISerializedRegExp;
	oneLineAboveText?: ISerializedRegExp;
	action: EnterAction;
}
export interface ISerializedLanguageConfiguration {
	comments?: CommentRule;
	brackets?: CharacterPair[];
	wordPattern?: ISerializedRegExp;
	indentationRules?: ISerializedIndentationRule;
	onEnterRules?: ISerializedOnEnterRule[];
	__electricCharacterSupport?: {
		brackets?: any;
		docComment?: {
			scope: string;
			open: string;
			lineStart: string;
			close?: string;
		};
	};
	__characterPairSupport?: {
		autoClosingPairs: {
			open: string;
			close: string;
			notIn?: string[];
		}[];
	};
}

export interface ISerializedDocumentFilter {
	$serialized: true;
	language?: string;
	scheme?: string;
	pattern?: vscode.GlobPattern;
	exclusive?: boolean;
}

export interface ISerializedSignatureHelpProviderMetadata {
	readonly triggerCharacters: ReadonlyArray<string>;
	readonly retriggerCharacters: ReadonlyArray<string>;
}

export interface MainThreadLanguageFeaturesShape extends IDisposable {
	$unregister(handle: number): void;
	$registerOutlineSupport(handle: number, selector: ISerializedDocumentFilter[], label: string): void;
	$registerCodeLensSupport(handle: number, selector: ISerializedDocumentFilter[], eventHandle: number): void;
	$emitCodeLensEvent(eventHandle: number, event?: any): void;
	$registerDefinitionSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerDeclarationSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerImplementationSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerTypeDefinitionSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerHoverProvider(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerDocumentHighlightProvider(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerReferenceSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerQuickFixSupport(handle: number, selector: ISerializedDocumentFilter[], supportedKinds?: string[]): void;
	$registerDocumentFormattingSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerRangeFormattingSupport(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerOnTypeFormattingSupport(handle: number, selector: ISerializedDocumentFilter[], autoFormatTriggerCharacters: string[]): void;
	$registerNavigateTypeSupport(handle: number): void;
	$registerRenameSupport(handle: number, selector: ISerializedDocumentFilter[], supportsResolveInitialValues: boolean): void;
	$registerSuggestSupport(handle: number, selector: ISerializedDocumentFilter[], triggerCharacters: string[], supportsResolveDetails: boolean): void;
	$registerSignatureHelpProvider(handle: number, selector: ISerializedDocumentFilter[], metadata: ISerializedSignatureHelpProviderMetadata): void;
	$registerDocumentLinkProvider(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerDocumentColorProvider(handle: number, selector: ISerializedDocumentFilter[]): void;
	$registerFoldingRangeProvider(handle: number, selector: ISerializedDocumentFilter[]): void;
	$setLanguageConfiguration(handle: number, languageId: string, configuration: ISerializedLanguageConfiguration): void;
}

export interface MainThreadLanguagesShape extends IDisposable {
	$getLanguages(): Thenable<string[]>;
	$changeLanguage(resource: UriComponents, languageId: string): Thenable<void>;
}

export interface MainThreadMessageOptions {
	extension?: IExtensionDescription;
	modal?: boolean;
}

export interface MainThreadMessageServiceShape extends IDisposable {
	$showMessage(severity: Severity, message: string, options: MainThreadMessageOptions, commands: { title: string; isCloseAffordance: boolean; handle: number; }[]): Thenable<number>;
}

export interface MainThreadOutputServiceShape extends IDisposable {
	$register(label: string, log: boolean, file?: UriComponents): Thenable<string>;
	$append(channelId: string, value: string): Thenable<void>;
	$update(channelId: string): Thenable<void>;
	$clear(channelId: string, till: number): Thenable<void>;
	$reveal(channelId: string, preserveFocus: boolean): Thenable<void>;
	$close(channelId: string): Thenable<void>;
	$dispose(channelId: string): Thenable<void>;
}

export interface MainThreadProgressShape extends IDisposable {

	$startProgress(handle: number, options: IProgressOptions): void;
	$progressReport(handle: number, message: IProgressStep): void;
	$progressEnd(handle: number): void;
}

export interface MainThreadTerminalServiceShape extends IDisposable {
	$createTerminal(name?: string, shellPath?: string, shellArgs?: string[], cwd?: string, env?: { [key: string]: string }, waitOnExit?: boolean): Thenable<number>;
	$createTerminalRenderer(name: string): Thenable<number>;
	$dispose(terminalId: number): void;
	$hide(terminalId: number): void;
	$sendText(terminalId: number, text: string, addNewLine: boolean): void;
	$show(terminalId: number, preserveFocus: boolean): void;
	$registerOnDataListener(terminalId: number): void;

	// Process
	$sendProcessTitle(terminalId: number, title: string): void;
	$sendProcessData(terminalId: number, data: string): void;
	$sendProcessPid(terminalId: number, pid: number): void;
	$sendProcessExit(terminalId: number, exitCode: number): void;

	// Renderer
	$terminalRendererSetName(terminalId: number, name: string): void;
	$terminalRendererSetDimensions(terminalId: number, dimensions: ITerminalDimensions): void;
	$terminalRendererWrite(terminalId: number, text: string): void;
	$terminalRendererRegisterOnInputListener(terminalId: number): void;
}

export interface TransferQuickPickItems extends IQuickPickItem {
	handle: number;
}

export interface TransferQuickInputButton extends IQuickInputButton {
	handle: number;
}

export type TransferQuickInput = TransferQuickPick | TransferInputBox;

export interface BaseTransferQuickInput {

	id: number;

	type?: 'quickPick' | 'inputBox';

	enabled?: boolean;

	busy?: boolean;

	visible?: boolean;
}

export interface TransferQuickPick extends BaseTransferQuickInput {

	type?: 'quickPick';

	value?: string;

	placeholder?: string;

	buttons?: TransferQuickInputButton[];

	items?: TransferQuickPickItems[];

	activeItems?: number[];

	selectedItems?: number[];

	canSelectMany?: boolean;

	ignoreFocusOut?: boolean;

	matchOnDescription?: boolean;

	matchOnDetail?: boolean;
}

export interface TransferInputBox extends BaseTransferQuickInput {

	type?: 'inputBox';

	value?: string;

	placeholder?: string;

	password?: boolean;

	buttons?: TransferQuickInputButton[];

	prompt?: string;

	validationMessage?: string;
}

export interface MainThreadQuickOpenShape extends IDisposable {
	$show(instance: number, options: IPickOptions<TransferQuickPickItems>, token: CancellationToken): Thenable<number | number[]>;
	$setItems(instance: number, items: TransferQuickPickItems[]): Thenable<void>;
	$setError(instance: number, error: Error): Thenable<void>;
	$input(options: vscode.InputBoxOptions, validateInput: boolean, token: CancellationToken): Thenable<string>;
	$createOrUpdate(params: TransferQuickInput): Thenable<void>;
	$dispose(id: number): Thenable<void>;
}

export interface MainThreadStatusBarShape extends IDisposable {
	$setEntry(id: number, extensionId: string, text: string, tooltip: string, command: string, color: string | ThemeColor, alignment: MainThreadStatusBarAlignment, priority: number): void;
	$dispose(id: number): void;
}

export interface MainThreadStorageShape extends IDisposable {
	$getValue<T>(shared: boolean, key: string): Thenable<T>;
	$setValue(shared: boolean, key: string, value: object): Thenable<void>;
}

export interface MainThreadTelemetryShape extends IDisposable {
	$publicLog(eventName: string, data?: any): void;
}

export type WebviewPanelHandle = string;

export interface WebviewPanelShowOptions {
	readonly viewColumn?: EditorViewColumn;
	readonly preserveFocus?: boolean;
}

export interface MainThreadWebviewsShape extends IDisposable {
	$createWebviewPanel(handle: WebviewPanelHandle, viewType: string, title: string, showOptions: WebviewPanelShowOptions, options: vscode.WebviewPanelOptions & vscode.WebviewOptions, extensionId: string, extensionLocation: UriComponents): void;
	$disposeWebview(handle: WebviewPanelHandle): void;
	$reveal(handle: WebviewPanelHandle, showOptions: WebviewPanelShowOptions): void;
	$setTitle(handle: WebviewPanelHandle, value: string): void;
	$setIconPath(handle: WebviewPanelHandle, value: { light: UriComponents, dark: UriComponents } | undefined): void;
	$setHtml(handle: WebviewPanelHandle, value: string): void;
	$setOptions(handle: WebviewPanelHandle, options: vscode.WebviewOptions): void;
	$postMessage(handle: WebviewPanelHandle, value: any): Thenable<boolean>;

	$registerSerializer(viewType: string): void;
	$unregisterSerializer(viewType: string): void;
}

export interface WebviewPanelViewState {
	readonly active: boolean;
	readonly visible: boolean;
	readonly position: EditorViewColumn;
}

export interface ExtHostWebviewsShape {
	$onMessage(handle: WebviewPanelHandle, message: any): void;
	$onDidChangeWebviewPanelViewState(handle: WebviewPanelHandle, newState: WebviewPanelViewState): void;
	$onDidDisposeWebviewPanel(handle: WebviewPanelHandle): Thenable<void>;
	$deserializeWebviewPanel(newWebviewHandle: WebviewPanelHandle, viewType: string, title: string, state: any, position: EditorViewColumn, options: vscode.WebviewOptions): Thenable<void>;
}

export interface MainThreadUrlsShape extends IDisposable {
	$registerUriHandler(handle: number, extensionId: string): Thenable<void>;
	$unregisterUriHandler(handle: number): Thenable<void>;
}

export interface ExtHostUrlsShape {
	$handleExternalUri(handle: number, uri: UriComponents): Thenable<void>;
}

export interface MainThreadWorkspaceShape extends IDisposable {
	$startFileSearch(includePattern: string, includeFolder: URI, excludePatternOrDisregardExcludes: string | false, maxResults: number, token: CancellationToken): Thenable<UriComponents[]>;
	$startTextSearch(query: IPatternInfo, options: ITextQueryBuilderOptions, requestId: number, token: CancellationToken): Thenable<vscode.TextSearchComplete>;
	$checkExists(includes: string[], token: CancellationToken): Thenable<boolean>;
	$saveAll(includeUntitled?: boolean): Thenable<boolean>;
	$updateWorkspaceFolders(extensionName: string, index: number, deleteCount: number, workspaceFoldersToAdd: { uri: UriComponents, name?: string }[]): Thenable<void>;
	$resolveProxy(url: string): Thenable<string>;
}

export interface IFileChangeDto {
	resource: UriComponents;
	type: FileChangeType;
}

export interface MainThreadFileSystemShape extends IDisposable {
	$registerFileSystemProvider(handle: number, scheme: string, capabilities: FileSystemProviderCapabilities): void;
	$unregisterProvider(handle: number): void;
	$setUriFormatter(scheme: string, formatter: LabelRules): void;
	$onFileSystemChange(handle: number, resource: IFileChangeDto[]): void;
}

export interface MainThreadSearchShape extends IDisposable {
	$registerFileSearchProvider(handle: number, scheme: string): void;
	$registerTextSearchProvider(handle: number, scheme: string): void;
	$registerFileIndexProvider(handle: number, scheme: string): void;
	$unregisterProvider(handle: number): void;
	$handleFileMatch(handle: number, session: number, data: UriComponents[]): void;
	$handleTextMatch(handle: number, session: number, data: IRawFileMatch2[]): void;
	$handleTelemetry(eventName: string, data: any): void;
}

export interface MainThreadTaskShape extends IDisposable {
	$registerTaskProvider(handle: number): Thenable<void>;
	$unregisterTaskProvider(handle: number): Thenable<void>;
	$fetchTasks(filter?: TaskFilterDTO): Thenable<TaskDTO[]>;
	$executeTask(task: TaskHandleDTO | TaskDTO): Thenable<TaskExecutionDTO>;
	$terminateTask(id: string): Thenable<void>;
	$registerTaskSystem(scheme: string, info: TaskSystemInfoDTO): void;
}

export interface MainThreadExtensionServiceShape extends IDisposable {
	$localShowMessage(severity: Severity, msg: string): void;
	$onExtensionActivated(extensionId: string, startup: boolean, codeLoadingTime: number, activateCallTime: number, activateResolvedTime: number, activationEvent: string): void;
	$onExtensionActivationFailed(extensionId: string): void;
	$onExtensionRuntimeError(extensionId: string, error: SerializedError): void;
	$addMessage(extensionId: string, severity: Severity, message: string): void;
}

export interface SCMProviderFeatures {
	hasQuickDiffProvider?: boolean;
	count?: number;
	commitTemplate?: string;
	acceptInputCommand?: modes.Command;
	statusBarCommands?: modes.Command[];
}

export interface SCMGroupFeatures {
	hideWhenEmpty?: boolean;
}

export type SCMRawResource = [
	number /*handle*/,
	UriComponents /*resourceUri*/,
	string[] /*icons: light, dark*/,
	string /*tooltip*/,
	boolean /*strike through*/,
	boolean /*faded*/,

	string | undefined /*source*/,
	string | undefined /*letter*/,
	ThemeColor | null /*color*/
];

export type SCMRawResourceSplice = [
	number /* start */,
	number /* delete count */,
	SCMRawResource[]
];

export type SCMRawResourceSplices = [
	number, /*handle*/
	SCMRawResourceSplice[]
];

export interface MainThreadSCMShape extends IDisposable {
	$registerSourceControl(handle: number, id: string, label: string, rootUri: UriComponents | undefined): void;
	$updateSourceControl(handle: number, features: SCMProviderFeatures): void;
	$unregisterSourceControl(handle: number): void;

	$registerGroup(sourceControlHandle: number, handle: number, id: string, label: string): void;
	$updateGroup(sourceControlHandle: number, handle: number, features: SCMGroupFeatures): void;
	$updateGroupLabel(sourceControlHandle: number, handle: number, label: string): void;
	$unregisterGroup(sourceControlHandle: number, handle: number): void;

	$spliceResourceStates(sourceControlHandle: number, splices: SCMRawResourceSplices[]): void;

	$setInputBoxValue(sourceControlHandle: number, value: string): void;
	$setInputBoxPlaceholder(sourceControlHandle: number, placeholder: string): void;
	$setInputBoxVisibility(sourceControlHandle: number, visible: boolean): void;
	$setValidationProviderIsEnabled(sourceControlHandle: number, enabled: boolean): void;
}

export type DebugSessionUUID = string;

export interface MainThreadDebugServiceShape extends IDisposable {
	$registerDebugTypes(debugTypes: string[]): void;
	$acceptDAMessage(handle: number, message: DebugProtocol.ProtocolMessage): void;
	$acceptDAError(handle: number, name: string, message: string, stack: string): void;
	$acceptDAExit(handle: number, code: number, signal: string): void;
	$registerDebugConfigurationProvider(type: string, hasProvideMethod: boolean, hasResolveMethod: boolean, hasProvideDaMethod: boolean, hasProvideTrackerMethod: boolean, handle: number): Thenable<void>;
	$registerDebugAdapterProvider(type: string, handle: number): Thenable<void>;
	$unregisterDebugConfigurationProvider(handle: number): void;
	$unregisterDebugAdapterProvider(handle: number): void;
	$startDebugging(folder: UriComponents | undefined, nameOrConfig: string | vscode.DebugConfiguration): Thenable<boolean>;
	$customDebugAdapterRequest(id: DebugSessionUUID, command: string, args: any): Thenable<any>;
	$appendDebugConsole(value: string): void;
	$startBreakpointEvents(): void;
	$registerBreakpoints(breakpoints: (ISourceMultiBreakpointDto | IFunctionBreakpointDto)[]): Thenable<void>;
	$unregisterBreakpoints(breakpointIds: string[], functionBreakpointIds: string[]): Thenable<void>;
}

export interface MainThreadWindowShape extends IDisposable {
	$getWindowVisibility(): Thenable<boolean>;
}

// -- extension host

export interface ExtHostCommandsShape {
	$executeContributedCommand<T>(id: string, ...args: any[]): Thenable<T>;
	$getContributedCommandHandlerDescriptions(): Thenable<{ [id: string]: string | ICommandHandlerDescription }>;
}

export interface ExtHostConfigurationShape {
	$acceptConfigurationChanged(data: IConfigurationData, eventData: IWorkspaceConfigurationChangeEventData): void;
}

export interface ExtHostDiagnosticsShape {

}

export interface ExtHostDocumentContentProvidersShape {
	$provideTextDocumentContent(handle: number, uri: UriComponents): Promise<string>;
}

export interface IModelAddedData {
	uri: UriComponents;
	versionId: number;
	lines: string[];
	EOL: string;
	modeId: string;
	isDirty: boolean;
}
export interface ExtHostDocumentsShape {
	$acceptModelModeChanged(strURL: UriComponents, oldModeId: string, newModeId: string): void;
	$acceptModelSaved(strURL: UriComponents): void;
	$acceptDirtyStateChanged(strURL: UriComponents, isDirty: boolean): void;
	$acceptModelChanged(strURL: UriComponents, e: IModelChangedEvent, isDirty: boolean): void;
}

export interface ExtHostDocumentSaveParticipantShape {
	$participateInSave(resource: UriComponents, reason: SaveReason): Thenable<boolean[]>;
}

export interface ITextEditorAddData {
	id: string;
	documentUri: UriComponents;
	options: IResolvedTextEditorConfiguration;
	selections: ISelection[];
	visibleRanges: IRange[];
	editorPosition: EditorViewColumn;
}
export interface ITextEditorPositionData {
	[id: string]: EditorViewColumn;
}
export interface IEditorPropertiesChangeData {
	options: IResolvedTextEditorConfiguration | null;
	selections: ISelectionChangeEvent | null;
	visibleRanges: IRange[] | null;
}
export interface ISelectionChangeEvent {
	selections: Selection[];
	source?: string;
}

export interface ExtHostEditorsShape {
	$acceptEditorPropertiesChanged(id: string, props: IEditorPropertiesChangeData): void;
	$acceptEditorPositionData(data: ITextEditorPositionData): void;
}

export interface IDocumentsAndEditorsDelta {
	removedDocuments?: UriComponents[];
	addedDocuments?: IModelAddedData[];
	removedEditors?: string[];
	addedEditors?: ITextEditorAddData[];
	newActiveEditor?: string;
}

export interface ExtHostDocumentsAndEditorsShape {
	$acceptDocumentsAndEditorsDelta(delta: IDocumentsAndEditorsDelta): void;
}

export interface ExtHostTreeViewsShape {
	$getChildren(treeViewId: string, treeItemHandle?: string): Thenable<ITreeItem[]>;
	$setExpanded(treeViewId: string, treeItemHandle: string, expanded: boolean): void;
	$setSelection(treeViewId: string, treeItemHandles: string[]): void;
	$setVisible(treeViewId: string, visible: boolean): void;
}

export interface ExtHostWorkspaceShape {
	$acceptWorkspaceData(workspace: IWorkspaceData): void;
	$handleTextSearchResult(result: IRawFileMatch2, requestId: number): void;
}

export interface ExtHostFileSystemShape {
	$stat(handle: number, resource: UriComponents): Thenable<IStat>;
	$readdir(handle: number, resource: UriComponents): Thenable<[string, FileType][]>;
	$readFile(handle: number, resource: UriComponents): Thenable<Buffer>;
	$writeFile(handle: number, resource: UriComponents, content: Buffer, opts: FileWriteOptions): Thenable<void>;
	$rename(handle: number, resource: UriComponents, target: UriComponents, opts: FileOverwriteOptions): Thenable<void>;
	$copy(handle: number, resource: UriComponents, target: UriComponents, opts: FileOverwriteOptions): Thenable<void>;
	$mkdir(handle: number, resource: UriComponents): Thenable<void>;
	$delete(handle: number, resource: UriComponents, opts: FileDeleteOptions): Thenable<void>;
	$watch(handle: number, session: number, resource: UriComponents, opts: IWatchOptions): void;
	$unwatch(handle: number, session: number): void;
	$open(handle: number, resource: UriComponents): Thenable<number>;
	$close(handle: number, fd: number): Thenable<void>;
	$read(handle: number, fd: number, pos: number, data: Buffer, offset: number, length: number): Thenable<number>;
	$write(handle: number, fd: number, pos: number, data: Buffer, offset: number, length: number): Thenable<number>;
}

export interface ExtHostSearchShape {
	$provideFileSearchResults(handle: number, session: number, query: IRawQuery, token: CancellationToken): Thenable<ISearchCompleteStats>;
	$provideTextSearchResults(handle: number, session: number, query: IRawTextQuery, token: CancellationToken): Thenable<ISearchCompleteStats>;
	$clearCache(cacheKey: string): Thenable<void>;
}

export interface ExtHostExtensionServiceShape {
	$activateByEvent(activationEvent: string): Thenable<void>;
}

export interface FileSystemEvents {
	created: UriComponents[];
	changed: UriComponents[];
	deleted: UriComponents[];
}
export interface ExtHostFileSystemEventServiceShape {
	$onFileEvent(events: FileSystemEvents): void;
	$onFileRename(oldUri: UriComponents, newUri: UriComponents): void;
	$onWillRename(oldUri: UriComponents, newUri: UriComponents): Thenable<any>;
}

export interface ObjectIdentifier {
	$ident: number;
}

export namespace ObjectIdentifier {
	export const name = '$ident';
	export function mixin<T>(obj: T, id: number): T & ObjectIdentifier {
		Object.defineProperty(obj, name, { value: id, enumerable: true });
		return <T & ObjectIdentifier>obj;
	}
	export function of(obj: any): number {
		return obj[name];
	}
}

export interface ExtHostHeapServiceShape {
	$onGarbageCollection(ids: number[]): void;
}
export interface IRawColorInfo {
	color: [number, number, number, number];
	range: IRange;
}

export class IdObject {
	_id?: number;
	private static _n = 0;
	static mixin<T extends object>(object: T): T & IdObject {
		(<any>object)._id = IdObject._n++;
		return <any>object;
	}
}

export interface SuggestionDto extends modes.CompletionItem {
	_id: number;
	_parentId: number;
}

export interface SuggestResultDto extends IdObject {
	suggestions: SuggestionDto[];
	incomplete?: boolean;
}

export interface LocationDto {
	uri: UriComponents;
	range: IRange;
}

export interface DefinitionLinkDto {
	origin?: IRange;
	uri: UriComponents;
	range: IRange;
	selectionRange?: IRange;
}

export interface WorkspaceSymbolDto extends IdObject {
	name: string;
	containerName?: string;
	kind: modes.SymbolKind;
	location: LocationDto;
}

export interface WorkspaceSymbolsDto extends IdObject {
	symbols: WorkspaceSymbolDto[];
}

export interface ResourceFileEditDto {
	oldUri: UriComponents;
	newUri: UriComponents;
	options: IFileOperationOptions;
}

export interface ResourceTextEditDto {
	resource: UriComponents;
	modelVersionId?: number;
	edits: modes.TextEdit[];
}

export interface WorkspaceEditDto {
	edits: (ResourceFileEditDto | ResourceTextEditDto)[];

	// todo@joh reject should go into rename
	rejectReason?: string;
}

export function reviveWorkspaceEditDto(data: WorkspaceEditDto): modes.WorkspaceEdit {
	if (data && data.edits) {
		for (const edit of data.edits) {
			if (typeof (<ResourceTextEditDto>edit).resource === 'object') {
				(<ResourceTextEditDto>edit).resource = URI.revive((<ResourceTextEditDto>edit).resource);
			} else {
				(<ResourceFileEditDto>edit).newUri = URI.revive((<ResourceFileEditDto>edit).newUri);
				(<ResourceFileEditDto>edit).oldUri = URI.revive((<ResourceFileEditDto>edit).oldUri);
			}
		}
	}
	return <modes.WorkspaceEdit>data;
}

export interface CodeActionDto {
	title: string;
	edit?: WorkspaceEditDto;
	diagnostics?: IMarkerData[];
	command?: modes.Command;
	kind?: string;
}

export interface ExtHostLanguageFeaturesShape {
	$provideDocumentSymbols(handle: number, resource: UriComponents, token: CancellationToken): Thenable<modes.DocumentSymbol[]>;
	$provideCodeLenses(handle: number, resource: UriComponents, token: CancellationToken): Thenable<modes.ICodeLensSymbol[]>;
	$resolveCodeLens(handle: number, resource: UriComponents, symbol: modes.ICodeLensSymbol, token: CancellationToken): Thenable<modes.ICodeLensSymbol>;
	$provideDefinition(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<DefinitionLinkDto[]>;
	$provideDeclaration(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<DefinitionLinkDto[]>;
	$provideImplementation(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<DefinitionLinkDto[]>;
	$provideTypeDefinition(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<DefinitionLinkDto[]>;
	$provideHover(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<modes.Hover>;
	$provideDocumentHighlights(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<modes.DocumentHighlight[]>;
	$provideReferences(handle: number, resource: UriComponents, position: IPosition, context: modes.ReferenceContext, token: CancellationToken): Thenable<LocationDto[]>;
	$provideCodeActions(handle: number, resource: UriComponents, rangeOrSelection: IRange | ISelection, context: modes.CodeActionContext, token: CancellationToken): Thenable<CodeActionDto[]>;
	$provideDocumentFormattingEdits(handle: number, resource: UriComponents, options: modes.FormattingOptions, token: CancellationToken): Thenable<ISingleEditOperation[]>;
	$provideDocumentRangeFormattingEdits(handle: number, resource: UriComponents, range: IRange, options: modes.FormattingOptions, token: CancellationToken): Thenable<ISingleEditOperation[]>;
	$provideOnTypeFormattingEdits(handle: number, resource: UriComponents, position: IPosition, ch: string, options: modes.FormattingOptions, token: CancellationToken): Thenable<ISingleEditOperation[]>;
	$provideWorkspaceSymbols(handle: number, search: string, token: CancellationToken): Thenable<WorkspaceSymbolsDto>;
	$resolveWorkspaceSymbol(handle: number, symbol: WorkspaceSymbolDto, token: CancellationToken): Thenable<WorkspaceSymbolDto>;
	$releaseWorkspaceSymbols(handle: number, id: number): void;
	$provideRenameEdits(handle: number, resource: UriComponents, position: IPosition, newName: string, token: CancellationToken): Thenable<WorkspaceEditDto>;
	$resolveRenameLocation(handle: number, resource: UriComponents, position: IPosition, token: CancellationToken): Thenable<modes.RenameLocation>;
	$provideCompletionItems(handle: number, resource: UriComponents, position: IPosition, context: modes.CompletionContext, token: CancellationToken): Thenable<SuggestResultDto>;
	$resolveCompletionItem(handle: number, resource: UriComponents, position: IPosition, suggestion: modes.CompletionItem, token: CancellationToken): Thenable<modes.CompletionItem>;
	$releaseCompletionItems(handle: number, id: number): void;
	$provideSignatureHelp(handle: number, resource: UriComponents, position: IPosition, context: modes.SignatureHelpContext, token: CancellationToken): Thenable<modes.SignatureHelp>;
	$provideDocumentLinks(handle: number, resource: UriComponents, token: CancellationToken): Thenable<modes.ILink[]>;
	$resolveDocumentLink(handle: number, link: modes.ILink, token: CancellationToken): Thenable<modes.ILink>;
	$provideDocumentColors(handle: number, resource: UriComponents, token: CancellationToken): Thenable<IRawColorInfo[]>;
	$provideColorPresentations(handle: number, resource: UriComponents, colorInfo: IRawColorInfo, token: CancellationToken): Thenable<modes.IColorPresentation[]>;
	$provideFoldingRanges(handle: number, resource: UriComponents, context: modes.FoldingContext, token: CancellationToken): Thenable<modes.FoldingRange[]>;
}

export interface ExtHostQuickOpenShape {
	$onItemSelected(handle: number): void;
	$validateInput(input: string): Thenable<string>;
	$onDidChangeActive(sessionId: number, handles: number[]): void;
	$onDidChangeSelection(sessionId: number, handles: number[]): void;
	$onDidAccept(sessionId: number): void;
	$onDidChangeValue(sessionId: number, value: string): void;
	$onDidTriggerButton(sessionId: number, handle: number): void;
	$onDidHide(sessionId: number): void;
}

export interface ShellLaunchConfigDto {
	name?: string;
	executable?: string;
	args?: string[] | string;
	cwd?: string;
	env?: { [key: string]: string };
}

export interface ExtHostTerminalServiceShape {
	$acceptTerminalClosed(id: number): void;
	$acceptTerminalOpened(id: number, name: string): void;
	$acceptActiveTerminalChanged(id: number | null): void;
	$acceptTerminalProcessId(id: number, processId: number): void;
	$acceptTerminalProcessData(id: number, data: string): void;
	$acceptTerminalRendererInput(id: number, data: string): void;
	$acceptTerminalTitleChange(id: number, name: string): void;
	$acceptTerminalRendererDimensions(id: number, cols: number, rows: number): void;
	$createProcess(id: number, shellLaunchConfig: ShellLaunchConfigDto, cols: number, rows: number): void;
	$acceptProcessInput(id: number, data: string): void;
	$acceptProcessResize(id: number, cols: number, rows: number): void;
	$acceptProcessShutdown(id: number, immediate: boolean): void;
}

export interface ExtHostSCMShape {
	$provideOriginalResource(sourceControlHandle: number, uri: UriComponents, token: CancellationToken): Thenable<UriComponents>;
	$onInputBoxValueChange(sourceControlHandle: number, value: string): void;
	$executeResourceCommand(sourceControlHandle: number, groupHandle: number, handle: number): Thenable<void>;
	$validateInput(sourceControlHandle: number, value: string, cursorPosition: number): Thenable<[string, number] | undefined>;
	$setSelectedSourceControls(selectedSourceControlHandles: number[]): Thenable<void>;
}

export interface ExtHostTaskShape {
	$provideTasks(handle: number, validTypes: { [key: string]: boolean; }): Thenable<TaskSet>;
	$onDidStartTask(execution: TaskExecutionDTO): void;
	$onDidStartTaskProcess(value: TaskProcessStartedDTO): void;
	$onDidEndTaskProcess(value: TaskProcessEndedDTO): void;
	$OnDidEndTask(execution: TaskExecutionDTO): void;
	$resolveVariables(workspaceFolder: UriComponents, toResolve: { process?: { name: string; cwd?: string }, variables: string[] }): Thenable<{ process?: string; variables: { [key: string]: string } }>;
}

export interface IBreakpointDto {
	type: string;
	id?: string;
	enabled: boolean;
	condition?: string;
	hitCondition?: string;
	logMessage?: string;
}

export interface IFunctionBreakpointDto extends IBreakpointDto {
	type: 'function';
	functionName: string;
}

export interface ISourceBreakpointDto extends IBreakpointDto {
	type: 'source';
	uri: UriComponents;
	line: number;
	character: number;
}

export interface IBreakpointsDeltaDto {
	added?: (ISourceBreakpointDto | IFunctionBreakpointDto)[];
	removed?: string[];
	changed?: (ISourceBreakpointDto | IFunctionBreakpointDto)[];
}

export interface ISourceMultiBreakpointDto {
	type: 'sourceMulti';
	uri: UriComponents;
	lines: {
		id: string;
		enabled: boolean;
		condition?: string;
		hitCondition?: string;
		logMessage?: string;
		line: number;
		character: number;
	}[];
}

export interface IDebugSessionFullDto {
	id: DebugSessionUUID;
	type: string;
	name: string;
	folderUri: UriComponents | undefined;
	configuration: IConfig;
}

export type IDebugSessionDto = IDebugSessionFullDto | DebugSessionUUID;

export interface ExtHostDebugServiceShape {
	$substituteVariables(folder: UriComponents | undefined, config: IConfig): Thenable<IConfig>;
	$runInTerminal(args: DebugProtocol.RunInTerminalRequestArguments, config: ITerminalSettings): Thenable<number | undefined>;
	$startDASession(handle: number, session: IDebugSessionDto): Thenable<void>;
	$stopDASession(handle: number): Thenable<void>;
	$sendDAMessage(handle: number, message: DebugProtocol.ProtocolMessage): void;
	$resolveDebugConfiguration(handle: number, folder: UriComponents | undefined, debugConfiguration: IConfig): Thenable<IConfig>;
	$provideDebugConfigurations(handle: number, folder: UriComponents | undefined): Thenable<IConfig[]>;
	$legacyDebugAdapterExecutable(handle: number, folderUri: UriComponents | undefined): Thenable<IAdapterDescriptor>; // TODO@AW legacy
	$provideDebugAdapter(handle: number, session: IDebugSessionDto): Thenable<IAdapterDescriptor>;
	$acceptDebugSessionStarted(session: IDebugSessionDto): void;
	$acceptDebugSessionTerminated(session: IDebugSessionDto): void;
	$acceptDebugSessionActiveChanged(session: IDebugSessionDto): void;
	$acceptDebugSessionCustomEvent(session: IDebugSessionDto, event: any): void;
	$acceptBreakpointsDelta(delta: IBreakpointsDeltaDto): void;
}


export interface DecorationRequest {
	readonly id: number;
	readonly handle: number;
	readonly uri: UriComponents;
}

export type DecorationData = [number, boolean, string, string, ThemeColor, string];
export type DecorationReply = { [id: number]: DecorationData };

export interface ExtHostDecorationsShape {
	$provideDecorations(requests: DecorationRequest[], token: CancellationToken): Thenable<DecorationReply>;
}

export interface ExtHostWindowShape {
	$onDidChangeWindowFocus(value: boolean): void;
}

export interface ExtHostLogServiceShape {
	$setLevel(level: LogLevel): void;
}

export interface ExtHostOutputServiceShape {
	$setVisibleChannel(channelId: string | null): void;
}

export interface ExtHostProgressShape {
	$acceptProgressCanceled(handle: number): void;
}

export interface ExtHostCommentsShape {
	$provideDocumentComments(handle: number, document: UriComponents): Thenable<modes.CommentInfo>;
	$createNewCommentThread(handle: number, document: UriComponents, range: IRange, text: string): Thenable<modes.CommentThread>;
	$replyToCommentThread(handle: number, document: UriComponents, range: IRange, commentThread: modes.CommentThread, text: string): Thenable<modes.CommentThread>;
	$editComment(handle: number, document: UriComponents, comment: modes.Comment, text: string): Thenable<void>;
	$deleteComment(handle: number, document: UriComponents, comment: modes.Comment): Thenable<void>;
	$provideWorkspaceComments(handle: number): Thenable<modes.CommentThread[]>;
}

export interface ExtHostStorageShape {
	$acceptValue(shared: boolean, key: string, value: object): void;
}

// --- proxy identifiers

export const MainContext = {
	MainThreadClipboard: <ProxyIdentifier<MainThreadClipboardShape>>createMainId<MainThreadClipboardShape>('MainThreadClipboard'),
	MainThreadCommands: <ProxyIdentifier<MainThreadCommandsShape>>createMainId<MainThreadCommandsShape>('MainThreadCommands'),
	MainThreadComments: createMainId<MainThreadCommentsShape>('MainThreadComments'),
	MainThreadConfiguration: createMainId<MainThreadConfigurationShape>('MainThreadConfiguration'),
	MainThreadDebugService: createMainId<MainThreadDebugServiceShape>('MainThreadDebugService'),
	MainThreadDecorations: createMainId<MainThreadDecorationsShape>('MainThreadDecorations'),
	MainThreadDiagnostics: createMainId<MainThreadDiagnosticsShape>('MainThreadDiagnostics'),
	MainThreadDialogs: createMainId<MainThreadDiaglogsShape>('MainThreadDiaglogs'),
	MainThreadDocuments: createMainId<MainThreadDocumentsShape>('MainThreadDocuments'),
	MainThreadDocumentContentProviders: createMainId<MainThreadDocumentContentProvidersShape>('MainThreadDocumentContentProviders'),
	MainThreadTextEditors: createMainId<MainThreadTextEditorsShape>('MainThreadTextEditors'),
	MainThreadErrors: createMainId<MainThreadErrorsShape>('MainThreadErrors'),
	MainThreadTreeViews: createMainId<MainThreadTreeViewsShape>('MainThreadTreeViews'),
	MainThreadLanguageFeatures: createMainId<MainThreadLanguageFeaturesShape>('MainThreadLanguageFeatures'),
	MainThreadLanguages: createMainId<MainThreadLanguagesShape>('MainThreadLanguages'),
	MainThreadMessageService: createMainId<MainThreadMessageServiceShape>('MainThreadMessageService'),
	MainThreadOutputService: createMainId<MainThreadOutputServiceShape>('MainThreadOutputService'),
	MainThreadProgress: createMainId<MainThreadProgressShape>('MainThreadProgress'),
	MainThreadQuickOpen: createMainId<MainThreadQuickOpenShape>('MainThreadQuickOpen'),
	MainThreadStatusBar: createMainId<MainThreadStatusBarShape>('MainThreadStatusBar'),
	MainThreadStorage: createMainId<MainThreadStorageShape>('MainThreadStorage'),
	MainThreadTelemetry: createMainId<MainThreadTelemetryShape>('MainThreadTelemetry'),
	MainThreadTerminalService: createMainId<MainThreadTerminalServiceShape>('MainThreadTerminalService'),
	MainThreadWebviews: createMainId<MainThreadWebviewsShape>('MainThreadWebviews'),
	MainThreadUrls: createMainId<MainThreadUrlsShape>('MainThreadUrls'),
	MainThreadWorkspace: createMainId<MainThreadWorkspaceShape>('MainThreadWorkspace'),
	MainThreadFileSystem: createMainId<MainThreadFileSystemShape>('MainThreadFileSystem'),
	MainThreadExtensionService: createMainId<MainThreadExtensionServiceShape>('MainThreadExtensionService'),
	MainThreadSCM: createMainId<MainThreadSCMShape>('MainThreadSCM'),
	MainThreadSearch: createMainId<MainThreadSearchShape>('MainThreadSearch'),
	MainThreadTask: createMainId<MainThreadTaskShape>('MainThreadTask'),
	MainThreadWindow: createMainId<MainThreadWindowShape>('MainThreadWindow'),
};

export const ExtHostContext = {
	ExtHostCommands: createExtId<ExtHostCommandsShape>('ExtHostCommands'),
	ExtHostConfiguration: createExtId<ExtHostConfigurationShape>('ExtHostConfiguration'),
	ExtHostDiagnostics: createExtId<ExtHostDiagnosticsShape>('ExtHostDiagnostics'),
	ExtHostDebugService: createExtId<ExtHostDebugServiceShape>('ExtHostDebugService'),
	ExtHostDecorations: createExtId<ExtHostDecorationsShape>('ExtHostDecorations'),
	ExtHostDocumentsAndEditors: createExtId<ExtHostDocumentsAndEditorsShape>('ExtHostDocumentsAndEditors'),
	ExtHostDocuments: createExtId<ExtHostDocumentsShape>('ExtHostDocuments'),
	ExtHostDocumentContentProviders: createExtId<ExtHostDocumentContentProvidersShape>('ExtHostDocumentContentProviders'),
	ExtHostDocumentSaveParticipant: createExtId<ExtHostDocumentSaveParticipantShape>('ExtHostDocumentSaveParticipant'),
	ExtHostEditors: createExtId<ExtHostEditorsShape>('ExtHostEditors'),
	ExtHostTreeViews: createExtId<ExtHostTreeViewsShape>('ExtHostTreeViews'),
	ExtHostFileSystem: createExtId<ExtHostFileSystemShape>('ExtHostFileSystem'),
	ExtHostFileSystemEventService: createExtId<ExtHostFileSystemEventServiceShape>('ExtHostFileSystemEventService'),
	ExtHostHeapService: createExtId<ExtHostHeapServiceShape>('ExtHostHeapMonitor'),
	ExtHostLanguageFeatures: createExtId<ExtHostLanguageFeaturesShape>('ExtHostLanguageFeatures'),
	ExtHostQuickOpen: createExtId<ExtHostQuickOpenShape>('ExtHostQuickOpen'),
	ExtHostExtensionService: createExtId<ExtHostExtensionServiceShape>('ExtHostExtensionService'),
	ExtHostLogService: createExtId<ExtHostLogServiceShape>('ExtHostLogService'),
	ExtHostTerminalService: createExtId<ExtHostTerminalServiceShape>('ExtHostTerminalService'),
	ExtHostSCM: createExtId<ExtHostSCMShape>('ExtHostSCM'),
	ExtHostSearch: createExtId<ExtHostSearchShape>('ExtHostSearch'),
	ExtHostTask: createExtId<ExtHostTaskShape>('ExtHostTask'),
	ExtHostWorkspace: createExtId<ExtHostWorkspaceShape>('ExtHostWorkspace'),
	ExtHostWindow: createExtId<ExtHostWindowShape>('ExtHostWindow'),
	ExtHostWebviews: createExtId<ExtHostWebviewsShape>('ExtHostWebviews'),
	ExtHostProgress: createMainId<ExtHostProgressShape>('ExtHostProgress'),
	ExtHostComments: createMainId<ExtHostCommentsShape>('ExtHostComments'),
	ExtHostStorage: createMainId<ExtHostStorageShape>('ExtHostStorage'),
	ExtHostUrls: createExtId<ExtHostUrlsShape>('ExtHostUrls'),
	ExtHostOutputService: createMainId<ExtHostOutputServiceShape>('ExtHostOutputService'),
};
