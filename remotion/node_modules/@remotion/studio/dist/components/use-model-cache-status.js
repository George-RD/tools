"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useModelCacheStatus = void 0;
const react_1 = require("react");
const useModelCacheStatus = ({ isModelCached, models, refreshKey, }) => {
    const [cachedModels, setCachedModels] = (0, react_1.useState)(new Set());
    (0, react_1.useEffect)(() => {
        let cancelled = false;
        Promise.all(models.map(async ({ name }) => ({
            cached: await isModelCached(name),
            name,
        })))
            .then((results) => {
            if (!cancelled) {
                const nextCachedModels = new Set();
                for (const result of results) {
                    if (result.cached) {
                        nextCachedModels.add(result.name);
                    }
                }
                setCachedModels(nextCachedModels);
            }
        })
            .catch(() => {
            if (!cancelled) {
                setCachedModels(new Set());
            }
        });
        return () => {
            cancelled = true;
        };
    }, [isModelCached, models, refreshKey]);
    return cachedModels;
};
exports.useModelCacheStatus = useModelCacheStatus;
