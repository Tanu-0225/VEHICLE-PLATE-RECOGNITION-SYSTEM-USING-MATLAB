function run_tests(repoDir)
%RUN_TESTS Unit and end-to-end checks for the plate recognition code.
%   RUN_TESTS runs every check against the code in the repository root.
%   It generates its own car images and character templates in a
%   temporary folder, so no data files are needed.
if nargin < 1
    repoDir = fileparts(fileparts(mfilename('fullpath')));
end
addpath(repoDir);
work = tempname; mkdir(work); cd(work);
cleanup = onCleanup(@() cd(tempdir));
fails = 0;

% ---- 1. Build templates from rendered glyphs ----
mkdir('templates');
alphabet = ['A':'Z' '0':'9'];
for c = alphabet
    imwrite(renderText(c, 60), fullfile('templates', [c '.png']));
end
createTemplates('templates');
clear readLetter   % reset persistent cache

% ---- 2. readLetter on each glyph, after segmenting it like a plate ----
wrong = '';
for c = alphabet
    g = renderText(c, 60);
    bw = ~imbinarize(g); bw = bwareaopen(bw, 5);
    s = regionprops(bw, 'Image', 'Area'); [~, i] = max([s.Area]);
    got = readLetter(s(i).Image);
    if got ~= c, wrong(end+1) = c; end %#ok<AGROW>
end
fails = fails + check(isempty(wrong), sprintf('readLetter glyphs (wrong: %s)', wrong));

% ---- 3. Blank input returns '?' rather than crashing ----
fails = fails + check(readLetter(false(42, 24)) == '?', 'blank input -> ?');
fails = fails + check(readLetter(true(42, 24)) == '?', 'solid input -> ?');

% ---- 4. Ties return one answer, not an error ----
t = load('NewTemplates.mat');
NewTemplates = [t.NewTemplates t.NewTemplates(1)];
TemplateLabels = [t.TemplateLabels t.TemplateLabels(1)];
save('NewTemplates.mat', 'NewTemplates', 'TemplateLabels');
clear readLetter
fails = fails + check(readLetter(t.NewTemplates{1}) == t.TemplateLabels(1), 'duplicate template tie');

% ---- 5. Old-format file (no labels, 48+ templates) uses legacy order ----
NewTemplates = repmat({false(42, 24)}, 1, 52);
NewTemplates{9} = t.NewTemplates{t.TemplateLabels == 'F'};   % index 9 = 'F'
NewTemplates{50} = t.NewTemplates{t.TemplateLabels == '0'};  % >48 = '0'
save('NewTemplates.mat', 'NewTemplates');
clear readLetter
fails = fails + check(readLetter(NewTemplates{9}) == 'F', 'legacy index 9 -> F');
fails = fails + check(readLetter(NewTemplates{50}) == '0', 'legacy index 50 -> 0');

% ---- 6. 1-bit (logical) template images are accepted ----
mkdir('bitTemplates');
for c = alphabet
    imwrite(imbinarize(renderText(c, 60)), fullfile('bitTemplates', [c '.png']));
end
try
    evalc('createTemplates(''bitTemplates'', ''bit.mat'')'); ok = true;
catch
    ok = false;
end
fails = fails + check(ok, '1-bit template images');

% ---- 7. Full pipeline on synthetic car images ----
movefile('NewTemplates.mat', 'old.mat'); createTemplates('templates'); clear readLetter
plates = {'MH12AB3456', 'KA05MN2024', 'DL8CX9137'};
sizes = [480 640; 768 1024; 300 400];
for k = 1:numel(plates)
    img = makeCar(plates{k}, sizes(k, :));
    imageFile = sprintf('car%d.png', k);
    imwrite(img, imageFile);
    out = evalc('runMain(imageFile)');
    got = strtrim(regexprep(out, '.*Number plate:\s*', ''));
    fails = fails + check(strcmp(got, plates{k}), ...
        sprintf('pipeline %dx%d: expected %s, got %s', sizes(k, 2), sizes(k, 1), plates{k}, got));
end

% ---- 8. Grayscale input no longer crashes ----
imwrite(rgb2gray(makeCar('AB12CD3456', [480 640])), 'gray.png');
out = evalc('runMain(''gray.png'')');
fails = fails + check(contains(out, 'AB12CD3456'), 'grayscale input');

% ---- 9. Missing image gives a clear error ----
try
    runMain('missing.png'); ok = false;
catch e
    ok = strcmp(e.identifier, 'PBL_No_Plate:noImage');
end
fails = fails + check(ok, 'missing image error');

close all force
fprintf('\n%d failure(s)\n', fails);
if fails
    error('run_tests:failed', '%d test(s) failed.', fails);
end
end

function runMain(imageFile) %#ok<INUSD>
PBL_No_Plate
end

function f = check(ok, name)
if ok, fprintf('PASS  %s\n', name); else, fprintf('FAIL  %s\n', name); end
f = ~ok;
end

function g = renderText(str, h)
% Render black text on white as a grayscale image, height ~h px.
w = round(h * 0.75 * numel(str)) + h;
fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 w h * 1.6], 'Color', 'w');
ax = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
text(ax, 0.5, 0.5, str, 'FontName', 'Arial', 'FontWeight', 'bold', 'FontUnits', 'pixels', ...
    'FontSize', h, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'Color', 'k');
fr = getframe(fig); close(fig);
g = rgb2gray(fr.cdata);
[r, c] = find(g < 128);
pad = round(h * 0.15);
g = g(max(1, min(r) - pad):min(end, max(r) + pad), max(1, min(c) - pad):min(end, max(c) + pad));
end

function img = makeCar(plateText, sz)
H = sz(1); W = sz(2);
rng(1);
img = uint8(150 + 20 * randn(H, W, 3));                       % noisy scene
body = [round(H * 0.3) round(H * 0.9) round(W * 0.15) round(W * 0.85)];
img(body(1):body(2), body(3):body(4), 1) = 140;               % red car body
img(body(1):body(2), body(3):body(4), 2) = 30;
img(body(1):body(2), body(3):body(4), 3) = 30;
txt = renderText(plateText, round(H * 0.06));
pl = 255 * ones(size(txt, 1) + 8, size(txt, 2) + 8, 'uint8');  % white plate
pl(5:end-4, 5:end-4) = txt;
pl([1:2 end-1:end], :) = 0; pl(:, [1:2 end-1:end]) = 0;        % black frame
r0 = round(H * 0.7); c0 = round(W / 2 - size(pl, 2) / 2);
img(r0:r0 + size(pl, 1) - 1, c0:c0 + size(pl, 2) - 1, :) = repmat(pl, 1, 1, 3);
end
