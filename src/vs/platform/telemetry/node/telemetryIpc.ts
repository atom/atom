/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IChannel, IServerChannel } from 'vs/base/parts/ipc/node/ipc';
import { ITelemetryAppender } from 'vs/platform/telemetry/common/telemetryUtils';
import { Event } from 'vs/base/common/event';

export interface ITelemetryLog {
	eventName: string;
	data?: any;
}

export class TelemetryAppenderChannel implements IServerChannel {

	constructor(private appender: ITelemetryAppender) { }

	listen<T>(_, event: string): Event<T> {
		throw new Error(`Event not found: ${event}`);
	}

	call(_, command: string, { eventName, data }: ITelemetryLog): Thenable<any> {
		this.appender.log(eventName, data);
		return Promise.resolve(null);
	}
}

export class TelemetryAppenderClient implements ITelemetryAppender {

	constructor(private channel: IChannel) { }

	log(eventName: string, data?: any): any {
		this.channel.call('log', { eventName, data })
			.then(undefined, err => `Failed to log telemetry: ${console.warn(err)}`);

		return Promise.resolve(null);
	}

	dispose(): any {
		// TODO
	}
}
