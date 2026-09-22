"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TIMELINE_ZOOM_SLIDER_PROPS = exports.sliderValueToTimelineZoom = exports.normalizedToTimelineZoom = exports.timelineZoomToSliderValue = exports.timelineZoomToNormalized = exports.getTimelineWidth = exports.getTimelineZoom = exports.clampTimelineZoom = exports.getTimelineMinZoom = exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM = void 0;
const timeline_layout_1 = require("./timeline-layout");
const TIMELINE_ZOOM_FALLBACK = 1;
exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM = 30;
const TIMELINE_ZOOM_SLIDER_MAX = 1000;
const getTimelineMinZoom = ({ durationInFrames, timelineViewportWidth, }) => {
    if (durationInFrames <= 0 || timelineViewportWidth <= 0) {
        return TIMELINE_ZOOM_FALLBACK;
    }
    return Math.min(exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM, Math.max(1, timelineViewportWidth - timeline_layout_1.TIMELINE_PADDING * 2) /
        durationInFrames);
};
exports.getTimelineMinZoom = getTimelineMinZoom;
const clampTimelineZoom = ({ zoom, durationInFrames, timelineViewportWidth, }) => {
    const minZoom = (0, exports.getTimelineMinZoom)({
        durationInFrames,
        timelineViewportWidth,
    });
    const clamped = Math.min(exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM, Math.max(minZoom, zoom));
    if (clamped === minZoom || clamped === exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM) {
        return clamped;
    }
    return Math.min(exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM, Math.max(minZoom, Math.round(clamped * 1000) / 1000));
};
exports.clampTimelineZoom = clampTimelineZoom;
const getTimelineZoom = ({ durationInFrames, timelineViewportWidth, zoom, }) => {
    return (0, exports.clampTimelineZoom)({
        durationInFrames,
        timelineViewportWidth,
        zoom: zoom !== null && zoom !== void 0 ? zoom : (0, exports.getTimelineMinZoom)({ durationInFrames, timelineViewportWidth }),
    });
};
exports.getTimelineZoom = getTimelineZoom;
const getTimelineWidth = ({ durationInFrames, zoom, }) => {
    return durationInFrames * zoom + timeline_layout_1.TIMELINE_PADDING * 2;
};
exports.getTimelineWidth = getTimelineWidth;
const timelineZoomToNormalized = ({ zoom, minZoom, }) => {
    if (minZoom >= exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM) {
        return 0;
    }
    const clampedZoom = Math.min(exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM, Math.max(minZoom, zoom));
    const normalized = Math.log(clampedZoom / minZoom) /
        Math.log(exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM / minZoom);
    return (Math.round(normalized * TIMELINE_ZOOM_SLIDER_MAX) / TIMELINE_ZOOM_SLIDER_MAX);
};
exports.timelineZoomToNormalized = timelineZoomToNormalized;
const timelineZoomToSliderValue = ({ zoom, minZoom, }) => {
    return Math.round((0, exports.timelineZoomToNormalized)({ zoom, minZoom }) * TIMELINE_ZOOM_SLIDER_MAX);
};
exports.timelineZoomToSliderValue = timelineZoomToSliderValue;
const normalizedToTimelineZoom = ({ normalized, minZoom, }) => {
    if (minZoom >= exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM) {
        return exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM;
    }
    const t = Math.min(1, Math.max(0, normalized));
    return minZoom * (exports.TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM / minZoom) ** t;
};
exports.normalizedToTimelineZoom = normalizedToTimelineZoom;
const sliderValueToTimelineZoom = ({ sliderValue, minZoom, }) => {
    return (0, exports.normalizedToTimelineZoom)({
        normalized: sliderValue / TIMELINE_ZOOM_SLIDER_MAX,
        minZoom,
    });
};
exports.sliderValueToTimelineZoom = sliderValueToTimelineZoom;
exports.TIMELINE_ZOOM_SLIDER_PROPS = {
    min: 0,
    max: TIMELINE_ZOOM_SLIDER_MAX,
    step: 1,
};
