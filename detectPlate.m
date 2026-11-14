function [plate, bbox, steps] = detectPlate(img)
%DETECTPLATE Locate and crop the number plate in a vehicle image.
%   [PLATE, BBOX] = DETECTPLATE(IMG) returns the grayscale crop of the
%   number plate in IMG and its bounding box [x y width height].
%   PLATE is empty if no candidate region is found.
%
%   [PLATE, BBOX, STEPS] = DETECTPLATE(IMG) also returns the intermediate
%   images (for display) as a struct.
%
%   Method: candidate regions come from two sources, both computed on a
%   copy of the image scaled to a fixed width:
%     1. Sobel edges -> remove small fragments -> dilate -> fill holes ->
%        erode: finds regions enclosed by edges, such as the plate frame.
%     2. Dense vertical edges: plate characters make many vertical strokes
%        close together, while grilles and body lines are mostly
%        horizontal. Joining nearby vertical edges finds text-like blocks.
%   Regions are ranked by how plate-shaped they are, then checked in
%   order. The first that splits into a plausible number of characters is
%   chosen, and the plate is cropped from the full-resolution image.

WORK_WIDTH = 640;      % detection runs at this width (larger images shrink)
MAX_CANDIDATES = 15;   % how many top-ranked regions to check
MIN_CHARS = 4;         % a plate must split into this many characters...
MAX_CHARS = 9;         % ...and no more than this
MARGIN = [0.08 0.25];  % crop margin as a fraction of [width height]

if size(img, 3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end
gray = im2uint8(gray);

% Shrink large images so the fixed-size shapes below suit every photo.
scale = min(1, WORK_WIDTH / size(gray, 2));
small = imresize(gray, scale);
[H, W] = size(small);
nPixels = H * W;

enhanced = histeq(medfilt2(small));   % remove noise, then boost contrast

% ---- Source 1: regions enclosed by edges ----
edges = edge(enhanced, 'sobel', 'horizontal') | ...
        edge(enhanced, 'sobel', 'vertical');
cleaned = bwareaopen(edges, max(20, round(nPixels * 0.0005)));
dilated = imdilate(cleaned, strel('line', 3, 90));   % vertical gaps
dilated = imdilate(dilated, strel('line', 3, 0));    % horizontal gaps
filled  = imfill(dilated, 'holes');
eroded = imerode(bwmorph(filled, 'thin', 1), strel('line', 5, 90));
eroded = imerode(eroded, strel('line', 5, 90));
enclosed = bwareaopen(eroded, max(50, round(nPixels * 0.001)));

% ---- Source 2: dense vertical edges (text-like blocks) ----
vEdges = edge(enhanced, 'sobel', 'vertical');
joined = imclose(vEdges, strel('rectangle', [3, max(5, round(W / 15))]));
textBlocks = imopen(joined, strel('rectangle', ...
    [max(2, round(H / 80)), max(2, round(W / 80))]));
textBlocks = bwareaopen(textBlocks, max(30, round(nPixels * 0.0005)));

candidates = enclosed | textBlocks;   % shown in the figure

% Rank regions by shape: plates are wide rectangles that fill most of
% their bounding box. Typical width:height ratios are about 2 to 6.
[boxes1, scores1] = rankRegions(enclosed);
[boxes2, scores2] = rankRegions(textBlocks);
boxes = [boxes1; boxes2];
[~, order] = sort([scores1; scores2], 'descend');
boxes = boxes(order, :);

% Map boxes back to full resolution and add a margin so characters at
% the edge of a region are not cut off.
boxes = boxes / scale;
pad = boxes(:, 3:4) .* MARGIN;
boxes = [boxes(:, 1:2) - pad, boxes(:, 3:4) + 2 * pad];
boxes = clampBoxes(boxes, size(gray));

% Check the best-ranked regions; keep the first that contains a
% plausible number of characters. Fall back to the best-shaped region.
plate = [];
bbox = [];
for k = 1:min(MAX_CANDIDATES, size(boxes, 1))
    crop = imcrop(gray, boxes(k, :));
    nChars = numel(segmentCharacters(crop));
    if nChars >= MIN_CHARS && nChars <= MAX_CHARS
        plate = crop;
        bbox = boxes(k, :);
        break
    end
end
if isempty(bbox) && ~isempty(boxes)
    bbox = boxes(1, :);
    plate = imcrop(gray, bbox);
end

steps = struct('enhanced', enhanced, 'edges', edges, ...
    'filled', filled, 'candidates', candidates);
end

function [boxes, scores] = rankRegions(mask)
stats = regionprops(mask, 'BoundingBox', 'Area', 'Extent');
boxes = zeros(0, 4);
scores = zeros(0, 1);
for k = 1:numel(stats)
    ratio = stats(k).BoundingBox(3) / stats(k).BoundingBox(4);
    if ratio < 1.5 || ratio > 8
        continue
    end
    boxes(end + 1, :) = stats(k).BoundingBox; %#ok<AGROW>
    scores(end + 1, 1) = stats(k).Extent * sqrt(stats(k).Area) / ...
        (1 + abs(ratio - 4) / 4); %#ok<AGROW>
end
end

function boxes = clampBoxes(boxes, imgSize)
x1 = max(1, boxes(:, 1));
y1 = max(1, boxes(:, 2));
x2 = min(imgSize(2), boxes(:, 1) + boxes(:, 3));
y2 = min(imgSize(1), boxes(:, 2) + boxes(:, 4));
boxes = [x1, y1, x2 - x1, y2 - y1];
end
