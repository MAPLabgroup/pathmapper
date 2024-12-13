function [ ] = Auto_Heat_Mapper_generalized(image,df)%,file)
%% Thackery Brown, 12/11/2024
%   adapted from Ulloa, Andres    Auto Heat Mapper    11/23/15
%   (https://github.com/aulloa/Auto_Heat_Mapper)

% The purpose of this script is to take tracking data from multiple
% participants looking at a single image (e.g., eyetracking) or navigating a single space (VR), smooth it using kernel density
% estimation assuming a normal distribution, and overlay it on the image

% to overlay paths nicely on an image you need the following information:
% you need the min and max X and Y (or Z, if unity; we'll still call it "Y"
% in the code) coordinates for the environment. NOT the min and max of the
% paths themselves, but the physical boundary of the space you want to plot
% the paths in. These coordinates should be the same scale/space as the
% path data, though.

% for example: if you have a path from (5,10) to (12,23), but the
% environment this path took place in was a box from (1,1) to (15,24), we
% need to know those box limit coordinates to line the path data up
% correctly in the visualization!


% Image and eye tracking data source
% [http://www.csc.kth.se/~kootstra/index.php?item=215&menu=200]

%clear all
close all

%% settings and flags
pdfscaler = 1000000000000000; % how much to scale the heat map by - note this increases the values in the data, so it shouldn't be used for stats, but it can be necessary for visualization
singlesub = 0; %1 = yes, load a single sub data and visualize a few ways
subnum = '02'; % only used if singlesub = 1(yes)
envid = 'of'; %of = open field, so = semiopen, cl = closed; adjust to whatever the env names are in your dataset's structure (e.g., "buildings_01" instead of "buildings_of")


%% Image and Eye Tracking Data Import
%load in the data
data = load(df);
navTrackData = data.navTrackData; %data.eyeTrackData;




%% single subject example...
if singlesub == 1

    % Define as X and Y tracking coordinates
    %NA  = '01' %file(1:2); % name of image itself, hard-coded right now
    Xstructname = strcat('buildings_',envid);
    d1  = getfield(navTrackData,'buildings',Xstructname,['subject_' subnum],'fixX');
    d2  = getfield(navTrackData,'buildings',Xstructname,['subject_' subnum],'fixY');
    d   = [d1;d2];
    p   = gkde2_custom(d);

    % first plot raw path
    figure(1)
    plot(d1,d2)

    % plot the path as a 3D surface
    figure(2)
    surf(p.x,p.y,p.pdf*pdfscaler)
    colormap(hot)
    %hold on

    % load image as underlay/overlay
    img    = imread(image);     %# Load a sample image

    %plot again using the image as a surface, allowing for 3D peaks to be
    %viewed relative to image topography
    figure(3)
    h = surf(p.x,p.y,p.pdf*pdfscaler, flipdim(img, 1), ...   % Plot surface (flips rows of C, if needed)
        'FaceColor', 'texturemap', ...
        'EdgeColor', 'none');


    % try to visualize surface as a transparent volume over background image
    figure(4)
    surf(p.x,p.y,p.pdf*pdfscaler,'FaceAlpha','interp',...
        'AlphaDataMapping','scaled',...
        'AlphaData',p.pdf*pdfscaler,...
        'FaceColor','interp','EdgeAlpha',0);
    colormap(jet)
    hold on

    %xoffset = 5; %this is a crude attempt to line the real internal environment up with the path data
    %yoffset = 3;%10; %this is a crude attempt to line the real internal environment up with the path data
    %x      = size(p(1).x); %note: we are using subject #1's x and y map here to define the space, but they shold be the same now due to adding mimax to everyone's path above
    %y      = size(p(1).y); %note: we are using subject #1's x and y map here to define the space, but they shold be the same now due to adding mimax to everyone's path above
    %xImage = [p(1).x(1,1)+xoffset p(1).x(1,x(1)); p(1).x(x(1),1)+xoffset p(1).x(x(1),x(1))];   %# The x data for the image corners
    %yImage = [p(1).y(1,y(1))-yoffset p(1).y(1,1)-yoffset; p(1).y(y(1),y(1))+yoffset p(1).y(y(1),1)+yoffset];             %# The y data for the image corners
    
    % this is where the coordinate mapping between the image and the path
    % data is critical!!!!
    xImage = [5, 41; 5, 41]; % the x data for the image corners - we assume this is the same coordinate space as the path data...
    yImage = [7,7; 23,23]; % the y data for the image corners - we assume this is the same coordinate space as the path data...
    zImage = [0 0; 0 0];   %# The z data for the image corners
    surf(xImage,yImage,zImage,...    %# Plot the surface
        'CData',flipdim(img, 1),...%img,...
        'FaceColor','texturemap');
    %set(gca,'Ydir','reverse')
    view(2)
    %set axis to map onto the underlay image only
    axis([p.x(1,1)+xoffset p.x(1,x(1)) p.y(1,y(1))-yoffset p.y(y(1),y(1))])


    %% multi-subject example
else

    Xstructname = strcat('buildings_',envid);

    %count # of subs to average over
    ss = getfield(navTrackData,'buildings',Xstructname); %ss = subjects list in dataframe
    dtemp1cat = [];%create empty matrices to store aggregate data from the group in
    dtemp2cat = [];%create empty matrices to store aggregate data from the group in

    %loop through the subjects' data and pull out their paths
    for i = 1:length(fieldnames(ss))
        d1temp  = getfield(navTrackData,'buildings',Xstructname,['subject_' num2str(i,'%02.f')],'fixX');
        d2temp  = getfield(navTrackData,'buildings',Xstructname,['subject_' num2str(i,'%02.f')],'fixY');

        %option 1 for aggregating the group data...
        dtemp{i}   = [d1temp;d2temp]; %keep subjects' data separate for averaging

        %option 2 for aggregating the group data...
        dtemp1cat = [dtemp1cat d1temp]; %pool all subjects' data as if one subject. DON'T use for averaging, just to get min-max
        dtemp2cat = [dtemp2cat d2temp]; %pool all subjects' data as if one subject. DON'T use for averaging, just to get min-max


        %OPTIONAL threshold paths so that participants don't go negative (this
        %helps ensure scale in pdfs is equivalent for averaging)
        %12/12/24 - no, this still doesn't do the job
        %dtemp = max(dtemp,0);

        % plot raw subject path just for sanity (make sure it looks right
        % compared to other path plotting code, etc)
        %figure
        %plot(dtemp(1,:),dtemp(2,:))
    end


    dcat = [dtemp1cat;dtemp2cat]; %pool all subjects' data as one so we can get a min-max for navigation space to plot

    %find the min/max X of all subjects and the min/max Y
    minx = min(dcat(1,:));
    maxx = max(dcat(1,:));
    miny = min(dcat(2,:));
    maxy = max(dcat(2,:));

    mimax = [minx maxx; miny maxy]; %store in single matrix for easy concatenation

    %compute average pdf
    % this has to be done in separate steps, making use of the group min
    % and max coordinates, otherwise the maps won't line up quite right

    for i = 1:length(fieldnames(ss))
        dtemp{i} = [dtemp{i} mimax];     %first add grp min and max to each individual's path data

        p(i)   = gkde2_custom(dtemp{i}); %then compute pdf
    end

    pavg = (p(1).pdf+p(2).pdf+p(3).pdf)/3 ; %this is a manual average of the path pdfs... not sure how to softcode this nicely for a larger group

    %plot the average pdf in 3D surface
    figure
    surf(p(1).x,p(1).y,pavg*pdfscaler) %note: we are using subject #1's x and y map here to define the space, but they shold be the same now due to adding mimax to everyone's path above
    colormap(hot)

    %plot over an image (e.g., isovist map)
        % load image as underlay/overlay
    img    = imread(image);     %# Load a sample image

    figure
    surf(p(1).x,p(1).y,pavg*pdfscaler,'FaceAlpha','interp',... %note: we are using subject #1's x and y map here to define the space, but they shold be the same now due to adding mimax to everyone's path above
        'AlphaDataMapping','scaled',...
        'AlphaData',pavg*pdfscaler,...
        'FaceColor','interp','EdgeAlpha',0);
    colormap(hot)
    hold on

    %xoffset = 5; %this is a crude attempt to line the real internal environment up with the path data
    %yoffset = 3;%10; %this is a crude attempt to line the real internal environment up with the path data
    %x      = size(p(1).x); %note: we are using subject #1's x and y map here to define the space, but they shold be the same now due to adding mimax to everyone's path above
    %y      = size(p(1).y); %note: we are using subject #1's x and y map here to define the space, but they shold be the same now due to adding mimax to everyone's path above
    %xImage = [p(1).x(1,1)+xoffset p(1).x(1,x(1)); p(1).x(x(1),1)+xoffset p(1).x(x(1),x(1))];   %# The x data for the image corners
    %yImage = [p(1).y(1,y(1))-yoffset p(1).y(1,1)-yoffset; p(1).y(y(1),y(1))+yoffset p(1).y(y(1),1)+yoffset];             %# The y data for the image corners
    
    % this is where the coordinate mapping between the image and the path
    % data is critical!!!!
    xImage = [5, 41; 5, 41]; % the x data for the image corners - we assume this is the same coordinate space as the path data...
    yImage = [7,7; 23,23]; % the y data for the image corners - we assume this is the same coordinate space as the path data...
    zImage = [0 0; 0 0];   %# The z data for the image corners
    surf(xImage,yImage,zImage,...    %# Plot the surface
        'CData',flipdim(img, 1),...%img,...
        'FaceColor','texturemap');
    %set(gca,'Ydir','reverse')
    view(2)
    %set axis to map onto the underlay image only
    %axis([p(1).x(1,1)+xoffset p(1).x(1,x(1)) p(1).y(1,y(1))-yoffset p(1).y(y(1),y(1))])
end

end


