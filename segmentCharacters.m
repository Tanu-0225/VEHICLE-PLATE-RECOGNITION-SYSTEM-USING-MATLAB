function [chars, bw] = segmentCharacters(plate)
%SEGMENTCHARACTERS Split a cropped number plate into character images.
%   CHARS = SEGMENTCHARACTERS(PLATE) returns a cell array of binary
%   character images (white character on black), ordered left to right.
%   [CHARS, BW] = SEGMENTCHARACTERS(PLATE) also returns the binarised plate.

if size(plate, 3) == 3
    plate = rgb2gray(plate);
end

bw = imbinarize(plate);
if mean(bw(:)) > 0.5      % plates are usually dark text on light
    bw = ~bw;             % make characters the foreground
end
bw = imclearborder(bw);   % drop the plate frame and edge noise
bw = bwareaopen(bw, max(10, round(numel(bw) * 0.002)));

plateHeight = size(bw, 1);
stats = regionprops(bw, 'BoundingBox', 'Image');

keep = false(1, numel(stats));
for k = 1:numel(stats)
    w = stats(k).BoundingBox(3);
    h = stats(k).BoundingBox(4);
    % Characters are taller than wide and span much of the plate height.
    keep(k) = h >= 0.3 * plateHeight && h <= 0.95 * plateHeight && w / h <= 1.2;
end
stats = stats(keep);

if isempty(stats)
    chars = {};
    return
end

boxes = vertcat(stats.BoundingBox);
[~, order] = sort(boxes(:, 1));
chars = {stats(order).Image};
end
