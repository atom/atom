/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { Profile, ProfileNode } from 'v8-inspect-profiler';
import { TernarySearchTree } from 'vs/base/common/map';
import { realpathSync } from 'vs/base/node/extfs';
import { IExtensionDescription, IExtensionHostProfile, IExtensionService, ProfileSegmentId, ProfileSession } from 'vs/workbench/services/extensions/common/extensions';

export class ExtensionHostProfiler {

	constructor(private readonly _port: number, @IExtensionService private readonly _extensionService: IExtensionService) {
	}

	public async start(): Promise<ProfileSession> {
		const profiler = await import('v8-inspect-profiler');
		const session = await profiler.startProfiling({ port: this._port });
		return {
			stop: async () => {
				const profile = await session.stop();
				const extensions = await this._extensionService.getExtensions();
				return this.distill((profile as any).profile, extensions);
			}
		};
	}

	private distill(profile: Profile, extensions: IExtensionDescription[]): IExtensionHostProfile {
		let searchTree = TernarySearchTree.forPaths<IExtensionDescription>();
		for (let extension of extensions) {
			searchTree.set(realpathSync(extension.extensionLocation.fsPath), extension);
		}

		let nodes = profile.nodes;
		let idsToNodes = new Map<number, ProfileNode>();
		let idsToSegmentId = new Map<number, ProfileSegmentId>();
		for (let node of nodes) {
			idsToNodes.set(node.id, node);
		}

		function visit(node: ProfileNode, segmentId: ProfileSegmentId) {
			if (!segmentId) {
				switch (node.callFrame.functionName) {
					case '(root)':
						break;
					case '(program)':
						segmentId = 'program';
						break;
					case '(garbage collector)':
						segmentId = 'gc';
						break;
					default:
						segmentId = 'self';
						break;
				}
			} else if (segmentId === 'self' && node.callFrame.url) {
				let extension = searchTree.findSubstr(node.callFrame.url);
				if (extension) {
					segmentId = extension.id;
				}
			}
			idsToSegmentId.set(node.id, segmentId);

			if (node.children) {
				for (let child of node.children) {
					visit(idsToNodes.get(child), segmentId);
				}
			}
		}
		visit(nodes[0], null);

		let samples = profile.samples;
		let timeDeltas = profile.timeDeltas;
		let distilledDeltas: number[] = [];
		let distilledIds: ProfileSegmentId[] = [];

		let currSegmentTime = 0;
		let currSegmentId: string = void 0;
		for (let i = 0; i < samples.length; i++) {
			let id = samples[i];
			let segmentId = idsToSegmentId.get(id);
			if (segmentId !== currSegmentId) {
				if (currSegmentId) {
					distilledIds.push(currSegmentId);
					distilledDeltas.push(currSegmentTime);
				}
				currSegmentId = segmentId;
				currSegmentTime = 0;
			}
			currSegmentTime += timeDeltas[i];
		}
		if (currSegmentId) {
			distilledIds.push(currSegmentId);
			distilledDeltas.push(currSegmentTime);
		}
		idsToNodes = null;
		idsToSegmentId = null;
		searchTree = null;

		return {
			startTime: profile.startTime,
			endTime: profile.endTime,
			deltas: distilledDeltas,
			ids: distilledIds,
			data: profile,
			getAggregatedTimes: () => {
				let segmentsToTime = new Map<ProfileSegmentId, number>();
				for (let i = 0; i < distilledIds.length; i++) {
					let id = distilledIds[i];
					segmentsToTime.set(id, (segmentsToTime.get(id) || 0) + distilledDeltas[i]);
				}
				return segmentsToTime;
			}
		};
	}
}
