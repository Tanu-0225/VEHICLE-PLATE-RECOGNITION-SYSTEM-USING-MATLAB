# VEHICLE-PLATE-RECOGNITION-SYSTEM-USING-MATLAB

A vehicle plate recognition (VPR) system in MATLAB. It finds the number plate in a photo of a vehicle, splits the plate into characters and reads each character by template matching.

![Flow chart](https://user-images.githubusercontent.com/64573376/165761698-466eb643-e058-44a1-93ec-4318e60c5d0f.png)

## Requirements

- MATLAB with the **Image Processing Toolbox**
- `NewTemplates.mat`: one template image per character (see [Templates](#templates))

## Usage

```matlab
imageFile = 'car.jpg';   % path to a vehicle photo
PBL_No_Plate
```

The script shows each processing step in a figure and prints the result, for example:

```
Number plate: MH12AB3456
```

If `imageFile` is not set, the script looks for `image1.png` in the current folder.

## How it works

| Step | File | What it does |
|---|---|---|
| 1. Pre-processing | `detectPlate.m` | Grayscale, median filter (noise), histogram equalisation (contrast) |
| 2. Plate extraction | `detectPlate.m` | Sobel edges → remove small fragments → dilate → fill holes → erode, then rank regions by how plate-like their shape is (wide rectangle, width:height about 2–6). The top 10 are checked in order, and the first that splits into 4–9 characters is taken as the plate |
| 3. Character segmentation | `segmentCharacters.m` | Binarise the plate, remove the frame, keep regions that are character-sized, sort left to right |
| 4. Character recognition | `readLetter.m`, `normalizeCharacter.m` | Crop each character, pad narrow ones (like `I` and `1`), resize to the template size and pick the template with the highest 2-D correlation (`corr2`) |
| 5. Result | `PBL_No_Plate.m` | Runs steps 1–4, shows the intermediate images and prints the plate text |

Size thresholds are relative to the image size, so photos of different resolutions work without retuning.

## Templates

`readLetter` needs `NewTemplates.mat` in the current folder. To build it, put one image per character in a folder, named after the character it shows (add a suffix for extra variants of one character):

```
templates/
  A.png  A_2.png  B.png  ...  Z.png  0.png  ...  9.png
```

Then run:

```matlab
createTemplates('templates')
```

This saves `NewTemplates` (the images, 42×24 pixels) and `TemplateLabels` (which character each one is). Older `NewTemplates.mat` files without `TemplateLabels` still work and are read in the original 48-template order.

## Tests

```matlab
cd tests
run_tests
```

`run_tests` builds its own car images and templates, so it needs no data files. It checks each step and the full pipeline.

## Accuracy on real photos

Measured with `tests/eval_openalpr.m` on the [OpenALPR benchmark](https://github.com/openalpr/benchmarks) photos. For each region, 30% of the photos were used to build character templates and the other 70% (shown below) to test.

| Region | Test photos | Plate found | Whole plate read correctly |
|---|---|---|---|
| Europe | 76 | 65% | 9% |
| US | 155 | 33% | 1% |
| Brazil | 80 | 31% | 13% |

Accuracy is low on real photos. Given the exact plate location, characters are read correctly 73–89% of the time, but splitting plates into characters often fails, especially on US plates with state names and stickers. The edge-detection and template-matching method works best on clean, front-facing photos.

To reproduce:

```matlab
% after: git clone https://github.com/openalpr/benchmarks.git
cd tests
eval_openalpr('path/to/benchmarks')
```

## Limitations

- Works best on clear, front-facing photos where the plate is roughly horizontal.
- Template matching only recognises the fonts present in your templates.
- Database comparison of the recognised plate is not included.
