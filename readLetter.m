function letter = readLetter(snap)
%READLETTER Recognise a single character image by template matching.
%   LETTER = READLETTER(SNAP) compares SNAP, an image of one character
%   (binary, grayscale or RGB), with every template stored in
%   NewTemplates.mat and returns the label of the best match.
%
%   NewTemplates.mat must contain a cell array NewTemplates of equally
%   sized template images. If it also contains TemplateLabels (a char
%   vector with one label per template, as written by createTemplates),
%   those labels are used. Otherwise the label order of the original
%   48-template set is assumed, with any extra templates read as '0'.
%
%   Returns '?' when SNAP cannot be matched (for example, a blank image).

persistent templates labels
if isempty(templates)
    [templates, labels] = loadTemplates();
end

if size(snap, 3) == 3
    snap = rgb2gray(snap);
end
if ~islogical(snap)
    snap = imbinarize(snap);
    if mean(snap(:)) > 0.5    % make the character the foreground
        snap = ~snap;
    end
end
snap = double(normalizeCharacter(snap, size(templates{1})));

scores = -inf(1, numel(templates));
for n = 1:numel(templates)
    c = corr2(double(templates{n}), snap);
    if ~isnan(c)              % corr2 is NaN when either image is flat
        scores(n) = c;
    end
end

[best, ind] = max(scores);   % always a single index, even on ties
if isinf(best)
    letter = '?';
else
    letter = labels(ind);
end
end

function [templates, labels] = loadTemplates()
file = 'NewTemplates.mat';
if ~isfile(file)
    error('readLetter:noTemplates', ...
        ['%s not found. Run createTemplates to build it from a folder ' ...
         'of character images.'], file);
end
data = load(file);
if ~isfield(data, 'NewTemplates') || isempty(data.NewTemplates)
    error('readLetter:badTemplates', ...
        '%s does not contain a non-empty NewTemplates cell array.', file);
end
templates = data.NewTemplates(:)';

if isfield(data, 'TemplateLabels')
    labels = char(data.TemplateLabels);
else
    % Label order of the original NewTemplates set (indices 1-48),
    % with any remaining templates being zeros.
    labels = ['AABBCDDEFGHIJKLMNOOPPQQRRSTUVWXYZ' '123445666788999'];
    labels(end+1:numel(templates)) = '0';
end

if numel(labels) ~= numel(templates)
    error('readLetter:labelMismatch', ...
        '%d templates but %d labels in %s.', ...
        numel(templates), numel(labels), file);
end
end
