.pragma library

// Snap/clamp helpers for the free desktop-widget layer. Coordinates are
// fractional grid cells; `step` is the snap step in cells (0 means no
// snapping). Kept as plain functions so the widget layer stays testable.

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(value, maximum));
}

// Rounds `value` to the nearest multiple of `step`. A step of 0 (or less)
// returns the value untouched, which is the "free" placement mode.
function quantize(value, step) {
    if (!(step > 0))
        return value;
    return Math.round(value / step) * step;
}

// Accumulated snap: moves in whole `step`s from `anchor` so a slow drag does
// not jitter around the threshold. Returns the new anchor and the snapped
// value, both clamped.
function advanceGrid(rawValue, anchor, gridValue, step, minimum, maximum) {
    if (!(step > 0))
        return { anchor: rawValue, value: clamp(rawValue, minimum, maximum) };

    const delta = rawValue - anchor;
    let steps = 0;
    if (delta >= step)
        steps = Math.floor(delta / step);
    else if (delta <= -step)
        steps = Math.ceil(delta / step);

    if (steps === 0)
        return { anchor, value: gridValue };

    return { anchor: anchor + steps * step, value: clamp(gridValue + steps * step, minimum, maximum) };
}

function shouldHoldSnap(rawValue, snapTarget, releaseThreshold) {
    return Math.abs(rawValue - snapTarget) <= releaseThreshold;
}

function nearestValidCandidate(candidates, minimum, maximum, enterThreshold) {
    let nearest = null;

    for (let i = 0; i < candidates.length; i++) {
        const candidate = candidates[i];
        if (!candidate || !Number.isFinite(candidate.target) || !Number.isFinite(candidate.distance))
            continue;
        if (candidate.target < minimum || candidate.target > maximum)
            continue;
        if (candidate.distance > enterThreshold)
            continue;
        if (nearest === null || candidate.distance < nearest.distance)
            nearest = candidate;
    }

    return nearest;
}
