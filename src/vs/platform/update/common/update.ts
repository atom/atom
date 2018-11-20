/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Event, NodeEventEmitter } from 'vs/base/common/event';
import { createDecorator } from 'vs/platform/instantiation/common/instantiation';
import { TPromise } from 'vs/base/common/winjs.base';

export interface IUpdate {
	version: string;
	productVersion: string;
	date?: Date;
	releaseNotes?: string;
	supportsFastUpdate?: boolean;
	url?: string;
	hash?: string;
}

/**
 * Updates are run as a state machine:
 *
 *      Uninitialized
 *           ↓
 *          Idle
 *          ↓  ↑
 *   Checking for Updates  →  Available for Download
 *         ↓
 *     Downloading  →   Ready
 *         ↓               ↑
 *     Downloaded   →  Updating
 *
 * Available: There is an update available for download (linux).
 * Ready: Code will be updated as soon as it restarts (win32, darwin).
 * Donwloaded: There is an update ready to be installed in the background (win32).
 */

export const enum StateType {
	Uninitialized = 'uninitialized',
	Idle = 'idle',
	CheckingForUpdates = 'checking for updates',
	AvailableForDownload = 'available for download',
	Downloading = 'downloading',
	Downloaded = 'downloaded',
	Updating = 'updating',
	Ready = 'ready',
}

export const enum UpdateType {
	Setup,
	Archive,
	Snap
}

export type Uninitialized = { type: StateType.Uninitialized };
export type Idle = { type: StateType.Idle, updateType: UpdateType, error?: string; };
export type CheckingForUpdates = { type: StateType.CheckingForUpdates, context: any };
export type AvailableForDownload = { type: StateType.AvailableForDownload, update: IUpdate };
export type Downloading = { type: StateType.Downloading, update: IUpdate };
export type Downloaded = { type: StateType.Downloaded, update: IUpdate };
export type Updating = { type: StateType.Updating, update: IUpdate };
export type Ready = { type: StateType.Ready, update: IUpdate };

export type State = Uninitialized | Idle | CheckingForUpdates | AvailableForDownload | Downloading | Downloaded | Updating | Ready;

export const State = {
	Uninitialized: { type: StateType.Uninitialized } as Uninitialized,
	Idle: (updateType: UpdateType, error?: string) => ({ type: StateType.Idle, updateType, error }) as Idle,
	CheckingForUpdates: (context: any) => ({ type: StateType.CheckingForUpdates, context } as CheckingForUpdates),
	AvailableForDownload: (update: IUpdate) => ({ type: StateType.AvailableForDownload, update } as AvailableForDownload),
	Downloading: (update: IUpdate) => ({ type: StateType.Downloading, update } as Downloading),
	Downloaded: (update: IUpdate) => ({ type: StateType.Downloaded, update } as Downloaded),
	Updating: (update: IUpdate) => ({ type: StateType.Updating, update } as Updating),
	Ready: (update: IUpdate) => ({ type: StateType.Ready, update } as Ready),
};

export interface IAutoUpdater extends NodeEventEmitter {
	setFeedURL(url: string): void;
	checkForUpdates(): void;
	applyUpdate?(): TPromise<void>;
	quitAndInstall(): void;
}

export const IUpdateService = createDecorator<IUpdateService>('updateService');

export interface IUpdateService {
	_serviceBrand: any;

	readonly onStateChange: Event<State>;
	readonly state: State;

	checkForUpdates(context: any): TPromise<void>;
	downloadUpdate(): TPromise<void>;
	applyUpdate(): TPromise<void>;
	quitAndInstall(): TPromise<void>;

	isLatestVersion(): TPromise<boolean | undefined>;
}
