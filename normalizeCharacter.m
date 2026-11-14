function out = normalizeCharacter(bw, outSize)
%NORMALIZECHARACTER Prepare a character image for template matching.
%   OUT = NORMALIZECHARACTER(BW, OUTSIZE) crops the binary character
%   image BW to its foreground and resizes it to OUTSIZE ([rows cols]).
%
%   Very narrow characters such as 'I' and '1' are first padded to a
%   minimum width. Without this they stretch into a solid block, which
%   cannot be told apart from any other solid block.
%
%   Used by both createTemplates and readLetter so templates and plate
%   characters are always prepared the same way.

MIN_WIDTH_RATIO = 0.4;   % minimum width / height before resizing

[r, c] = find(bw);
if isempty(r)
    out = false(outSize);
    return
end
bw = bw(min(r):max(r), min(c):max(c));

[h, w] = size(bw);
minWidth = ceil(MIN_WIDTH_RATIO * h);
if w < minWidth
    left = floor((minWidth - w) / 2);
    bw = [false(h, left) bw false(h, minWidth - w - left)];
end

out = imresize(bw, outSize);
end
