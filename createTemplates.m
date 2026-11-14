function createTemplates(folder, outFile)
%CREATETEMPLATES Build NewTemplates.mat from a folder of character images.
%   CREATETEMPLATES(FOLDER) reads every image in FOLDER and saves the
%   templates to NewTemplates.mat in the current folder.
%   CREATETEMPLATES(FOLDER, OUTFILE) saves to OUTFILE instead.
%
%   Each file name must start with the character it shows. Add a suffix
%   for extra variants of the same character, e.g.
%       A.png  A_2.png  B.png  7.png  7_alt.png
%
%   Each image is binarised (character white on black, matching the
%   output of segmentCharacters), cropped to the character and resized
%   to 42x24 pixels.

if nargin < 1, folder = 'templates'; end
if nargin < 2, outFile = 'NewTemplates.mat'; end

TEMPLATE_SIZE = [42 24];
files = [dir(fullfile(folder, '*.png')); dir(fullfile(folder, '*.bmp')); ...
         dir(fullfile(folder, '*.jpg')); dir(fullfile(folder, '*.tif'))];
if isempty(files)
    error('createTemplates:empty', 'No images found in "%s".', folder);
end

NewTemplates = cell(1, numel(files));
TemplateLabels = blanks(numel(files));
for k = 1:numel(files)
    img = imread(fullfile(folder, files(k).name));
    if size(img, 3) == 3
        img = rgb2gray(img);
    end
    if islogical(img)         % 1-bit images are already black and white
        bw = img;
    else
        bw = imbinarize(img);
    end
    % The image border is background. If it is mostly white, the
    % character is dark on light, so invert to make it the foreground.
    border = [bw(1, :) bw(end, :) bw(:, 1)' bw(:, end)'];
    if mean(border) > 0.5
        bw = ~bw;
    end
    if ~any(bw(:))
        error('createTemplates:blank', '"%s" has no character in it.', files(k).name);
    end
    NewTemplates{k} = normalizeCharacter(bw, TEMPLATE_SIZE);
    TemplateLabels(k) = upper(files(k).name(1));
end

save(outFile, 'NewTemplates', 'TemplateLabels');
fprintf('Saved %d templates (%s) to %s\n', numel(files), ...
    unique(TemplateLabels), outFile);
end
