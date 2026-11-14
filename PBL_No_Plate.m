% PBL_NO_PLATE  Vehicle number plate recognition.
%   Set imageFile below (or define it in the workspace before running)
%   and run this script. It detects the plate, splits it into characters,
%   reads each character by template matching and prints the plate text.
%
%   Requires: Image Processing Toolbox, and NewTemplates.mat in the
%   current folder (build it with createTemplates if you don't have it).

if ~exist('imageFile', 'var')
    imageFile = fullfile('images', 'kerala_car.jpg');   % example photo
end
if ~isfile(imageFile)
    error('PBL_No_Plate:noImage', ...
        'Image "%s" not found. Set imageFile to a vehicle photo.', imageFile);
end

img = imread(imageFile);
[plate, bbox, steps] = detectPlate(img);

figure('Name', 'Number plate detection');
subplot(3, 2, 1); imshow(img);              title('Original image');
subplot(3, 2, 2); imshow(steps.edges);      title('Edge detection (Sobel)');
subplot(3, 2, 3); imshow(steps.filled);     title('Dilated and filled');
subplot(3, 2, 4); imshow(steps.candidates); title('Possible plate regions');

if isempty(plate)
    error('PBL_No_Plate:noPlate', 'No number plate found in "%s".', imageFile);
end

subplot(3, 2, 5); imshow(img); title('Detected plate');
rectangle('Position', bbox, 'EdgeColor', 'g', 'LineWidth', 2);

[chars, plateBW] = segmentCharacters(plate);
subplot(3, 2, 6); imshow(plateBW); title(sprintf('%d characters found', numel(chars)));

if isempty(chars)
    error('PBL_No_Plate:noChars', 'No characters found on the detected plate.');
end

plateText = blanks(numel(chars));
for k = 1:numel(chars)
    plateText(k) = readLetter(chars{k});
end

title(sprintf('Plate text: %s', plateText));
fprintf('Number plate: %s\n', plateText);
