"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getWaveformCacheKey = void 0;
const trackIds = new WeakMap();
let nextTrackId = 0;
const getWaveformCacheKey = (src, waveformSampleRate) => {
    if (typeof src === 'string') {
        return `${waveformSampleRate}:url:${src}`;
    }
    let id = trackIds.get(src);
    if (id === undefined) {
        id = nextTrackId++;
        trackIds.set(src, id);
    }
    return `${waveformSampleRate}:track:${id}`;
};
exports.getWaveformCacheKey = getWaveformCacheKey;
