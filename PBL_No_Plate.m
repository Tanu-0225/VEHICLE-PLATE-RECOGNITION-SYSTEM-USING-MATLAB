% Number Plate Detection
clc;
clear all;
close all;
img = imread('image1.png');
subplot(3,2,1);
imshow(img);
title('Original Image');
%figure;

img2 = rgb2gray(img);  
img2 = medfilt2(img2);% To smoothen the image(remove noise if any) -  median filter
img2 = histeq(img2);   % To enhance the constrast of the gray scale image - histogram eq.
%figure;
%imshow(img2);
%plot(img2);
imgX = edge(img2,'sobel','horizontal');     % Detects edges along rows
imgY = edge(img2,'sobel','vertical');       % Detects edges along columns
img3 = imgX|imgY;                   % Gives us a combination of edges detected along rows and columns
subplot(3,2,2);
imshow(img3);
title("edge detection(sobel)");
img3 = bwareaopen(img3, 900);       % Edges are filtered to attain the result using area opening 
se = strel('line',2,90);            % Structuring Element is created which is a [3x1] matrix with value 1
img3 = imdilate(img3,se);           % Image is dilated with respect to the created structuring element to get more precise edges along rows
subplot(3,2,3);
imshow(img3);
title("Image dilate");
se = strel('line',2,0);             % Another Structuring Element is generated here it is a [1x3] matrix with value 1
img3 = imdilate(img3,se);           % Image is dilated once again to get more precise edges along columns
% subplot(3,2,4);
%imshow(img3);
%title("a");
img4 = imfill(img3,'holes');        % This step highlights the areas which could be number plates in the image
subplot(3,2,4);
imshow(img4);
title("Posible no. plate position");
img4 = bwmorph(img4,'thin',1);      % morphology
se = strel('line',5,90);
img5 = imerode(img4,se);
img5 = imerode(img5,se);
%imshow(img5);
%title("erode")
img6 = immultiply(img2,img5);
subplot(3,2,5);
imshow(img6);
title("Multiplying with original image");
img7 = ~im2bw(img6);
subplot(3,2,6);
imshow(img7);
title("detected Number plate");