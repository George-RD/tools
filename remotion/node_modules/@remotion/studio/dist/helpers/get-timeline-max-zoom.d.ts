export declare const TIMELINE_FRAME_WIDTH_AT_MAX_ZOOM = 30;
export declare const getTimelineMinZoom: ({ durationInFrames, timelineViewportWidth, }: {
    readonly durationInFrames: number;
    readonly timelineViewportWidth: number;
}) => number;
export declare const clampTimelineZoom: ({ zoom, durationInFrames, timelineViewportWidth, }: {
    readonly zoom: number;
    readonly durationInFrames: number;
    readonly timelineViewportWidth: number;
}) => number;
export declare const getTimelineZoom: ({ durationInFrames, timelineViewportWidth, zoom, }: {
    readonly durationInFrames: number;
    readonly timelineViewportWidth: number;
    readonly zoom: number | null;
}) => number;
export declare const getTimelineWidth: ({ durationInFrames, zoom, }: {
    readonly durationInFrames: number;
    readonly zoom: number;
}) => number;
export declare const timelineZoomToNormalized: ({ zoom, minZoom, }: {
    readonly zoom: number;
    readonly minZoom: number;
}) => number;
export declare const timelineZoomToSliderValue: ({ zoom, minZoom, }: {
    readonly zoom: number;
    readonly minZoom: number;
}) => number;
export declare const normalizedToTimelineZoom: ({ normalized, minZoom, }: {
    readonly normalized: number;
    readonly minZoom: number;
}) => number;
export declare const sliderValueToTimelineZoom: ({ sliderValue, minZoom, }: {
    readonly sliderValue: number;
    readonly minZoom: number;
}) => number;
export declare const TIMELINE_ZOOM_SLIDER_PROPS: {
    readonly min: 0;
    readonly max: 1000;
    readonly step: 1;
};
