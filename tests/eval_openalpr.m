function eval_openalpr(dataDir, outDir)
%EVAL_OPENALPR Measure accuracy on real photos from the OpenALPR benchmark.
%   EVAL_OPENALPR(DATADIR) evaluates on the dataset cloned into DATADIR:
%       git clone https://github.com/openalpr/benchmarks.git
%   EVAL_OPENALPR(DATADIR, OUTDIR) writes working files to OUTDIR
%   (default: a temporary folder).
%
%   For each region (eu, us, br), ~30% of the photos supply character
%   templates and the other ~70% are the test set. Each stage is scored
%   separately: plate found, characters split, characters read, and the
%   whole plate read end to end.
if nargin < 2
    outDir = tempname;
end
repoDir = fileparts(fileparts(mfilename('fullpath')));
addpath(repoDir);
if ~isfolder(outDir), mkdir(outDir); end
oldDir = cd(outDir);
restore = onCleanup(@() cd(oldDir));
regions = {'eu', 'us', 'br'};
rows = {};
for ri = 1:numel(regions)
    reg = regions{ri};
    ann = readAnnotations(fullfile(dataDir, 'endtoend', reg));
    rng(42);
    order = randperm(numel(ann));
    nTpl = round(0.3 * numel(ann));
    tplSet = ann(order(1:nTpl));
    testSet = ann(order(nTpl + 1:end));

    % ---- Build templates from the template split (ground-truth crops) ----
    tplDir = fullfile(outDir, ['templates_' reg]);
    if isfolder(tplDir), rmdir(tplDir, 's'); end
    mkdir(tplDir);
    counts = containers.Map();
    for k = 1:numel(tplSet)
        a = tplSet(k);
        chars = segmentCharacters(cropGray(a));
        if numel(chars) ~= numel(a.text), continue, end
        for j = 1:numel(chars)
            ch = a.text(j);
            if ~isKey(counts, ch), counts(ch) = 0; end
            if counts(ch) >= 5, continue, end
            counts(ch) = counts(ch) + 1;
            imwrite(~padarray(chars{j}, [4 4], false), ...
                fullfile(tplDir, sprintf('%c_%d.png', ch, counts(ch))));
        end
    end
    evalc('createTemplates(tplDir, fullfile(outDir, ''NewTemplates.mat''))');
    clear readLetter
    tplChars = keys(counts); tplChars = [tplChars{:}];

    % ---- Score the test split ----
    n = numel(testSet);
    detOK = false(n, 1); segOK = false(n, 1); ocrOK = false(n, 1); e2eOK = false(n, 1);
    charTotal = 0; charRight = 0;
    for k = 1:n
        a = testSet(k);
        img = imread(a.file);
        % Stage 1: plate detection (IoU >= 0.5 with ground truth)
        try
            [plate, bbox] = detectPlate(img);
        catch
            plate = []; bbox = [];
        end
        detOK(k) = ~isempty(bbox) && iou(bbox, a.box) >= 0.5;
        % Stages 2-3: segmentation and OCR on the ground-truth crop
        chars = segmentCharacters(cropGray(a));
        segOK(k) = numel(chars) == numel(a.text);
        if segOK(k)
            txt = cellfun(@readLetter, chars);
            ocrOK(k) = strcmp(txt, a.text);
            charTotal = charTotal + numel(txt);
            charRight = charRight + sum(txt == a.text);
        end
        % End to end: detected plate -> text
        if ~isempty(plate)
            c2 = segmentCharacters(plate);
            if ~isempty(c2)
                e2eOK(k) = strcmp(cellfun(@readLetter, c2), a.text);
            end
        end
    end
    rows(end + 1, :) = {reg, n, numel(tplSet), tplChars, mean(detOK), mean(segOK), ...
        charRight / max(1, charTotal), mean(ocrOK), mean(e2eOK)}; %#ok<AGROW>
end

fprintf('\n%-4s %5s %5s  %-9s %-9s %-10s %-11s %-9s\n', 'reg', 'test', 'tpl', ...
    'plateDet', 'segCount', 'charAcc*', 'plateOCR*', 'endToEnd');
for r = 1:size(rows, 1)
    fprintf('%-4s %5d %5d  %8.1f%% %8.1f%% %9.1f%% %10.1f%% %8.1f%%\n', rows{r, 1}, rows{r, 2}, ...
        rows{r, 3}, 100 * [rows{r, 5:9}]);
end
end

function ann = readAnnotations(folder)
txts = dir(fullfile(folder, '*.txt'));
ann = struct('file', {}, 'box', {}, 'text', {});
for k = 1:numel(txts)
    line = strtrim(fileread(fullfile(folder, txts(k).name)));
    parts = strsplit(line, sprintf('\t'));
    if numel(parts) < 6, parts = strsplit(line); end
    if numel(parts) < 6, continue, end
    f = fullfile(folder, parts{1});
    if ~isfile(f), continue, end
    ann(end + 1) = struct('file', f, ...
        'box', str2double(parts(2:5)), 'text', upper(regexprep(parts{6}, '[^A-Za-z0-9]', ''))); %#ok<AGROW>
end
end

function g = cropGray(a)
img = imread(a.file);
if size(img, 3) == 3, img = rgb2gray(img); end
g = imcrop(img, a.box);
end

function v = iou(b1, b2)
x1 = max(b1(1), b2(1)); y1 = max(b1(2), b2(2));
x2 = min(b1(1) + b1(3), b2(1) + b2(3)); y2 = min(b1(2) + b1(4), b2(2) + b2(4));
inter = max(0, x2 - x1) * max(0, y2 - y1);
v = inter / (b1(3) * b1(4) + b2(3) * b2(4) - inter);
end
