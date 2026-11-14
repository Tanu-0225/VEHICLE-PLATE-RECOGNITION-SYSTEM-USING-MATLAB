function [plate, bbox, steps] = detectPlate(img)
%DETECTPLATE Locate and crop the number plate in a vehicle image.
%   [PLATE, BBOX] = DETECTPLATE(IMG) returns the grayscale crop of the
%   number plate in IMG and its bounding box [x y width height].
%   PLATE is empty if no candidate region is found.
%
%   [PLATE, BBOX, STEPS] = DETECTPLATE(IMG) also returns the intermediate
%   images (for display) as a struct.
%
%   Method: Sobel edges -> remove small edge fragments -> dilate -> fill
%   holes -> erode -> rank the connected regions by how plate-shaped they
%   are. Grilles, lights and signs can look as plate-shaped as the plate,
%   so the best-ranked regions are then checked in order, and the first
%   one that splits into a plausible number of characters is chosen.

MAX_CANDIDATES = 10;   % how many top-ranked regions to check
MIN_CHARS = 4;         % a plate must split into this many characters...
MAX_CHARS = 9;         % ...and no more than this

if size(img, 3) == 3
    gray = rgb2gray(img);
else
    gray = img;
end
gray = im2uint8(gray);

enhanced = histeq(medfilt2(gray));   % remove noise, then boost contrast

edges = edge(enhanced, 'sobel', 'horizontal') | ...
        edge(enhanced, 'sobel', 'vertical');

% Thresholds scale with image size so the same code works at any
% resolution (the original fixed value of 900 px suited only one image).
nPixels = numel(gray);
cleaned = bwareaopen(edges, max(20, round(nPixels * 0.0005)));

dilated = imdilate(cleaned, strel('line', 3, 90));   % vertical gaps
dilated = imdilate(dilated, strel('line', 3, 0));    % horizontal gaps
filled  = imfill(dilated, 'holes');

eroded = imerode(bwmorph(filled, 'thin', 1), strel('line', 5, 90));
eroded = imerode(eroded, strel('line', 5, 90));
candidates = bwareaopen(eroded, max(50, round(nPixels * 0.001)));

% Rank regions by shape: plates are wide rectangles that fill most of
% their bounding box. Typical width:height ratios are about 2 to 6.
stats = regionprops(candidates, 'BoundingBox', 'Area', 'Extent');
boxes = zeros(0, 4);
scores = zeros(0, 1);
for k = 1:numel(stats)
    w = stats(k).BoundingBox(3);
    h = stats(k).BoundingBox(4);
    ratio = w / h;
    if ratio < 1.5 || ratio > 8
        continue
    end
    boxes(end + 1, :) = stats(k).BoundingBox; %#ok<AGROW>
    scores(end + 1, 1) = stats(k).Extent * sqrt(stats(k).Area) / ...
        (1 + abs(ratio - 4) / 4); %#ok<AGROW>
end
[~, order] = sort(scores, 'descend');
boxes = boxes(order, :);

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
