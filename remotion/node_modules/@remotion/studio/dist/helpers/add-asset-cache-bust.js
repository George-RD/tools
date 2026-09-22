"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.addAssetCacheBust = void 0;
const addAssetCacheBust = ({ fetchedAt, src, }) => {
    if (src.startsWith('blob:')) {
        return src;
    }
    return `${src}${src.includes('?') ? '&' : '?'}date=${fetchedAt}`;
};
exports.addAssetCacheBust = addAssetCacheBust;
