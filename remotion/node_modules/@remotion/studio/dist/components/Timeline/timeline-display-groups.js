"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addTimelineDisplayGroups = void 0;
const timeline_node_path_key_1 = require("../../helpers/timeline-node-path-key");
const addTimelineDisplayGroups = (tracks) => {
    var _a, _b;
    const stacksBySequenceId = new Map();
    const resolvedNodePathKeysByStack = new Map();
    for (const track of tracks) {
        // Only controlled sequences can eventually resolve to a source node.
        const stack = track.sequence.controls === null ? null : track.sequence.getStack();
        stacksBySequenceId.set(track.sequence.id, stack);
        if (stack === null || track.nodePathInfo === null) {
            continue;
        }
        const nodePathKey = `node-path:${(0, timeline_node_path_key_1.timelineSequenceNodePathToKey)(track.nodePathInfo.sequenceSubscriptionKey)}`;
        const nodePathKeys = (_a = resolvedNodePathKeysByStack.get(stack)) !== null && _a !== void 0 ? _a : new Set();
        nodePathKeys.add(nodePathKey);
        resolvedNodePathKeysByStack.set(stack, nodePathKeys);
    }
    const displayKeys = tracks.map((track) => {
        var _a;
        if (track.nodePathInfo !== null) {
            return `node-path:${(0, timeline_node_path_key_1.timelineSequenceNodePathToKey)(track.nodePathInfo.sequenceSubscriptionKey)}`;
        }
        const stack = (_a = stacksBySequenceId.get(track.sequence.id)) !== null && _a !== void 0 ? _a : null;
        if (stack === null) {
            return null;
        }
        const resolvedNodePathKeys = resolvedNodePathKeysByStack.get(stack);
        if ((resolvedNodePathKeys === null || resolvedNodePathKeys === void 0 ? void 0 : resolvedNodePathKeys.size) === 1) {
            const resolvedNodePathKey = resolvedNodePathKeys.values().next().value;
            if (resolvedNodePathKey === undefined) {
                throw new Error('Expected a resolved timeline node path key');
            }
            return resolvedNodePathKey;
        }
        // This identity is display-only. Source operations continue to require
        // track.nodePathInfo.
        return `stack:${stack}`;
    });
    const counts = new Map();
    for (const key of displayKeys) {
        if (key !== null) {
            counts.set(key, ((_b = counts.get(key)) !== null && _b !== void 0 ? _b : 0) + 1);
        }
    }
    return tracks.map((track, index) => {
        const key = displayKeys[index];
        if (key === null) {
            return { ...track, displayGroup: null };
        }
        const numberOfSequences = counts.get(key);
        if (numberOfSequences === undefined) {
            throw new Error('Expected a timeline display group count');
        }
        return {
            ...track,
            displayGroup: {
                key,
                numberOfSequences,
            },
        };
    });
};
exports.addTimelineDisplayGroups = addTimelineDisplayGroups;
