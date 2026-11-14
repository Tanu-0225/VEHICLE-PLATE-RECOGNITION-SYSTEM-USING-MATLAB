function [chars, bw] = segmentCharacters(plate)
%SEGMENTCHARACTERS Split a cropped number plate into character images.
%   CHARS = SEGMENTCHARACTERS(PLATE) returns a cell array of binary
%   character images (white character on black), ordered left to right.
%   [CHARS, BW] = SEGMENTCHARACTERS(PLATE) also returns the binarised plate.
%
%   Characters are found as a row of similar-sized shapes lined up
%   horizontally. The tallest such row with at least 4 shapes is used,
%   so smaller text on the plate (such as a state name) and parts of the
%   car around the plate are ignored.
%
%   Both dark-on-light and light-on-dark text are tried, and the
%   polarity that gives the better row of characters is kept. (Guessing
%   from overall brightness fails when the crop includes the car body.)

if size(plate, 3) == 3
    plate = rgb2gray(plate);
end

level = imbinarize(plate);
[charsDark, heightDark, bwDark] = findRow(~level);   % dark text
[charsLight, heightLight, bwLight] = findRow(level); % light text

if rowScore(charsDark, heightDark) >= rowScore(charsLight, heightLight)
    chars = charsDark;
    bw = bwDark;
else
    chars = charsLight;
    bw = bwLight;
end
end

function s = rowScore(chars, height)
% A full row (4+ characters) beats any partial one; among full rows the
% taller wins, otherwise the row with more characters wins.
MIN_CHARS = 4;
if numel(chars) >= MIN_CHARS
    s = 1e6 + height;
else
    s = numel(chars);
end
end

function [chars, rowHeight, bw] = findRow(bw)
MIN_CHARS = 4;        % a row needs at least this many characters
HEIGHT_TOL = 0.2;     % characters in a row differ in height by <= 20%
MIN_HEIGHT = 8;       % pixels; smaller shapes are noise
MAX_WIDTH_RATIO = 2;  % width / height; some plate fonts are very wide

bw = imclearborder(bw);   % drop the plate frame, car body and edge noise
bw = bwareaopen(bw, max(10, round(numel(bw) * 0.0005)));

chars = {};
rowHeight = 0;
stats = regionprops(bw, 'BoundingBox', 'Image');
if isempty(stats)
    return
end

% Keep shapes that could be characters: not too wide, not tiny, and not
% as tall as the whole crop.
boxes = vertcat(stats.BoundingBox);
w = boxes(:, 3);
h = boxes(:, 4);
isChar = h >= MIN_HEIGHT & h <= 0.95 * size(bw, 1) & w ./ h <= MAX_WIDTH_RATIO;
stats = stats(isChar);
boxes = boxes(isChar, :);
if isempty(stats)
    return
end

% Group shapes into rows of similar height and vertical position, and
% take the tallest row that has enough characters.
h = boxes(:, 4);
cy = boxes(:, 2) + h / 2;
[~, byHeight] = sort(h, 'descend');
best = [];
for i = byHeight'
    members = find(abs(h - h(i)) <= HEIGHT_TOL * h(i) & ...
                   abs(cy - cy(i)) <= 0.5 * h(i));
    if numel(members) >= MIN_CHARS
        best = members;
        break
    end
    if numel(members) > numel(best)
        best = members;   % fallback: the largest row found
    end
end

[~, order] = sort(boxes(best, 1));
chars = {stats(best(order)).Image};
rowHeight = median(h(best));
end
