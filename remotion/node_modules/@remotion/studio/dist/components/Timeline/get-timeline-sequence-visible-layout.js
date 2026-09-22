"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getTimelineSequenceVisibleLayout = void 0;
const getVisibleSection = ({ sectionStart, sectionEnd, cropStart, cropEnd, }) => {
    const start = Math.max(sectionStart, cropStart);
    const end = Math.min(sectionEnd, cropEnd);
    if (end <= start) {
        return null;
    }
    return {
        left: start - cropStart,
        width: end - start,
    };
};
const getTimelineSequenceVisibleLayout = ({ marginLeft, width, negativeStartWidth, premountWidth, postmountWidth, renderWindowLeft, renderWindowWidth, }) => {
    const itemStart = marginLeft;
    const itemEnd = marginLeft + width;
    const renderWindowEnd = renderWindowLeft + renderWindowWidth;
    const visibleStart = Math.max(itemStart, renderWindowLeft);
    const visibleEnd = Math.min(itemEnd, renderWindowEnd);
    if (visibleEnd <= visibleStart) {
        return null;
    }
    const cropStart = visibleStart - itemStart;
    const cropEnd = visibleEnd - itemStart;
    const premountStart = negativeStartWidth;
    const mediaStart = negativeStartWidth + premountWidth;
    const mediaEnd = Math.max(mediaStart, width - postmountWidth);
    const media = getVisibleSection({
        sectionStart: mediaStart,
        sectionEnd: mediaEnd,
        cropStart,
        cropEnd,
    });
    return {
        marginLeft: visibleStart,
        width: visibleEnd - visibleStart,
        cropLeft: cropStart,
        leftEdgeVisible: visibleStart === itemStart,
        rightEdgeVisible: visibleEnd === itemEnd,
        negativeStart: getVisibleSection({
            sectionStart: 0,
            sectionEnd: negativeStartWidth,
            cropStart,
            cropEnd,
        }),
        premount: getVisibleSection({
            sectionStart: premountStart,
            sectionEnd: premountStart + premountWidth,
            cropStart,
            cropEnd,
        }),
        postmount: getVisibleSection({
            sectionStart: Math.max(0, width - postmountWidth),
            sectionEnd: width,
            cropStart,
            cropEnd,
        }),
        media: media
            ? {
                ...media,
                offset: Math.max(0, cropStart - mediaStart),
                fullWidth: Math.max(0, mediaEnd - mediaStart),
            }
            : null,
    };
};
exports.getTimelineSequenceVisibleLayout = getTimelineSequenceVisibleLayout;
