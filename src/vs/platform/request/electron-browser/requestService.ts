/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { IRequestOptions, IRequestContext, IRequestFunction } from 'vs/base/node/request';
import { Readable } from 'stream';
import { RequestService as NodeRequestService } from 'vs/platform/request/node/requestService';
import { CancellationToken } from 'vscode';
import { canceled } from 'vs/base/common/errors';

/**
 * This service exposes the `request` API, while using the global
 * or configured proxy settings.
 */
export class RequestService extends NodeRequestService {
	request(options: IRequestOptions, token: CancellationToken): Promise<IRequestContext> {
		return super.request(options, token, xhrRequest);
	}
}

export const xhrRequest: IRequestFunction = (options: IRequestOptions, token: CancellationToken): Promise<IRequestContext> => {

	const xhr = new XMLHttpRequest();
	return new Promise<IRequestContext>((resolve, reject) => {

		xhr.open(options.type || 'GET', options.url || '', true, options.user, options.password);
		setRequestHeaders(xhr, options);

		xhr.responseType = 'arraybuffer';
		xhr.onerror = e => reject(new Error(xhr.statusText && ('XHR failed: ' + xhr.statusText)));
		xhr.onload = (e) => {
			resolve({
				res: {
					statusCode: xhr.status,
					headers: getResponseHeaders(xhr)
				},
				stream: new class ArrayBufferStream extends Readable {

					private _buffer: Buffer;
					private _offset: number;
					private _length: number;

					constructor(arraybuffer: ArrayBuffer) {
						super();
						this._buffer = Buffer.from(new Uint8Array(arraybuffer));
						this._offset = 0;
						this._length = this._buffer.length;
					}

					_read(size: number) {
						if (this._offset < this._length) {
							this.push(this._buffer.slice(this._offset, (this._offset + size)));
							this._offset += size;
						} else {
							this.push(null);
						}
					}

				}(xhr.response)
			});
		};
		xhr.ontimeout = e => reject(new Error(`XHR timeout: ${options.timeout}ms`));

		if (options.timeout) {
			xhr.timeout = options.timeout;
		}

		// TODO: remove any
		xhr.send(options.data as any);

		// cancel
		token.onCancellationRequested(() => {
			xhr.abort();
			reject(canceled());
		});
	});
};

function setRequestHeaders(xhr: XMLHttpRequest, options: IRequestOptions): void {
	if (options.headers) {
		outer: for (let k in options.headers) {
			switch (k) {
				case 'User-Agent':
				case 'Accept-Encoding':
				case 'Content-Length':
					// unsafe headers
					continue outer;
			}
			xhr.setRequestHeader(k, options.headers[k]);

		}
	}
}

function getResponseHeaders(xhr: XMLHttpRequest): { [name: string]: string } {
	const headers: { [name: string]: string } = Object.create(null);
	for (const line of xhr.getAllResponseHeaders().split(/\r\n|\n|\r/g)) {
		if (line) {
			const idx = line.indexOf(':');
			headers[line.substr(0, idx).trim().toLowerCase()] = line.substr(idx + 1).trim();
		}
	}
	return headers;
}
