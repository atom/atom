/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as vscode from 'vscode';
import * as Proto from '../protocol';
import Logger from './logger';

enum Trace {
	Off,
	Messages,
	Verbose,
}

namespace Trace {
	export function fromString(value: string): Trace {
		value = value.toLowerCase();
		switch (value) {
			case 'off':
				return Trace.Off;
			case 'messages':
				return Trace.Messages;
			case 'verbose':
				return Trace.Verbose;
			default:
				return Trace.Off;
		}
	}
}

export default class Tracer {
	private trace?: Trace;

	constructor(
		private readonly logger: Logger
	) {
		this.updateConfiguration();
	}

	public updateConfiguration() {
		this.trace = Tracer.readTrace();
	}

	private static readTrace(): Trace {
		let result: Trace = Trace.fromString(vscode.workspace.getConfiguration().get<string>('typescript.tsserver.trace', 'off'));
		if (result === Trace.Off && !!process.env.TSS_TRACE) {
			result = Trace.Messages;
		}
		return result;
	}

	public traceRequest(request: Proto.Request, responseExpected: boolean, queueLength: number): void {
		if (this.trace === Trace.Off) {
			return;
		}
		let data: string | undefined = undefined;
		if (this.trace === Trace.Verbose && request.arguments) {
			data = `Arguments: ${JSON.stringify(request.arguments, null, 4)}`;
		}
		this.logTrace(`Sending request: ${request.command} (${request.seq}). Response expected: ${responseExpected ? 'yes' : 'no'}. Current queue length: ${queueLength}`, data);
	}

	public traceResponse(response: Proto.Response, startTime: number): void {
		if (this.trace === Trace.Off) {
			return;
		}
		let data: string | undefined = undefined;
		if (this.trace === Trace.Verbose && response.body) {
			data = `Result: ${JSON.stringify(response.body, null, 4)}`;
		}
		this.logTrace(`Response received: ${response.command} (${response.request_seq}). Request took ${Date.now() - startTime} ms. Success: ${response.success} ${!response.success ? '. Message: ' + response.message : ''}`, data);
	}

	public traceRequestCompleted(command: string, request_seq: number, startTime: number): any {
		if (this.trace === Trace.Off) {
			return;
		}
		this.logTrace(`Async response received: ${command} (${request_seq}). Request took ${Date.now() - startTime} ms.`);
	}

	public traceEvent(event: Proto.Event): void {
		if (this.trace === Trace.Off) {
			return;
		}
		let data: string | undefined = undefined;
		if (this.trace === Trace.Verbose && event.body) {
			data = `Data: ${JSON.stringify(event.body, null, 4)}`;
		}
		this.logTrace(`Event received: ${event.event} (${event.seq}).`, data);
	}

	public logTrace(message: string, data?: any): void {
		if (this.trace !== Trace.Off) {
			this.logger.logLevel('Trace', message, data);
		}
	}
}