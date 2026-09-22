"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.validateCaptionOutputName = exports.getDefaultCaptionOutputName = void 0;
const public_output_name_1 = require("../public-output-name");
const getDefaultCaptionOutputName = (src, displayName = 'captions') => {
    return `${(0, public_output_name_1.getDefaultOutputBaseName)(src, displayName, 'captions')}-captions.json`;
};
exports.getDefaultCaptionOutputName = getDefaultCaptionOutputName;
const validateCaptionOutputName = (outName) => (0, public_output_name_1.validatePublicOutputName)({ extension: '.json', outName });
exports.validateCaptionOutputName = validateCaptionOutputName;
