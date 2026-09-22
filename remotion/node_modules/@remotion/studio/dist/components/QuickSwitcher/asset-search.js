"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.filterAssetsByType = void 0;
const get_preview_file_type_1 = require("../../helpers/get-preview-file-type");
const typeFilterRegex = /(^|\s)type:([^\s]+)/gi;
const filterAssetsByType = ({ assets, query, }) => {
    const typeFilters = [];
    const queryWithoutTypeFilters = query
        .replace(typeFilterRegex, (_match, whitespace, type) => {
        typeFilters.push(type.toLowerCase());
        return whitespace;
    })
        .replace(/\s+/g, ' ')
        .trim();
    if (typeFilters.length === 0) {
        return {
            assets,
            query: queryWithoutTypeFilters,
        };
    }
    return {
        assets: assets.filter((asset) => {
            return typeFilters.includes((0, get_preview_file_type_1.getPreviewFileType)(asset.name));
        }),
        query: queryWithoutTypeFilters,
    };
};
exports.filterAssetsByType = filterAssetsByType;
