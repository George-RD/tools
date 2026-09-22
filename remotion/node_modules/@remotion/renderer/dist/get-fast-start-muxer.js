"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getFastStartMuxer = void 0;
const getFastStartMuxer = (outputExtension) => {
    const normalizedExtension = outputExtension.toLowerCase();
    if (normalizedExtension === 'mp4' || normalizedExtension === 'mov') {
        return normalizedExtension;
    }
    return null;
};
exports.getFastStartMuxer = getFastStartMuxer;
