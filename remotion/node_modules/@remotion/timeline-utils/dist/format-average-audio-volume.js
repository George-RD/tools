"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.formatAverageAudioVolume = void 0;
const formatAverageAudioVolume = (volume) => {
    if (volume === null) {
        return 'Unavailable';
    }
    return volume === -Infinity
        ? '−∞ dBFS (silent)'
        : `${volume.toFixed(1)} dBFS`;
};
exports.formatAverageAudioVolume = formatAverageAudioVolume;
