function [data,ETparams] = eventDetection(x,y,pupilsize,ETparams,varargin)
%--------------------------------------------------------------------------
% README
%
% This code is based on an implementation of Nystr�m, M. & Holmqvist, K.
% (2010), "An adaptive algorithm for fixation, saccade, and glissade
% detection in eye-tracking data". Behavior Research Methods 42(1):188-204.
% It processes the recorded eye movement data to extract saccades,
% glissades and fixations.
%
% Observe that if the saccade template extension (not from Nystr�m et al.'s
% article) is used, ETparams.data.qApplySaccadeTemplate==true, this
% algorithm can handle data containing saccades during smooth pursuit as
% well.
%
% This code only requires the statistics toolbox for the functions nanmean,
% nanmedian and nanstd. If you do not have access to this toolbox, you can
% get a nanmean implementation from Peter Acklam's website:
% http://home.online.no/~pjacklam/matlab/software/util/statutil/nanmean.m
% You'll have to implement nanmedian and nanstd yourself following this
% nanmean as an example

% Prepare data and params (move origin, things like that)
%-------------------------------------
[data,ETparams] = prepareDataAndParams(x,y,pupilsize,ETparams,varargin{:});

% Calculate velocity and acceleration
%-------------------------------------
data = filterDataAndCalcDerivative(data,ETparams);

% Detect noise
%-------------------------------------
data = removeNoise(data,ETparams);

% Detrend and apply saccade template
%-------------------------------------
data = detrendAndApplySaccadeTemplate(data,ETparams);

% Iteratively find the optimal noise threshold
%-------------------------------------
data = estimateThresholds(data,ETparams);

% Detect saccades and glissades
%-------------------------------------
data = detectSaccadesAndGlissades(data,ETparams);

% Detect and remove blinks
% Also detects some noisy bits of data as evidenced
% by wobbly pupil size trace. Thats ok, err on save
% side here, make sure we don't miss any even small
% eyelid droops, and some noise removal is nice too...
% (Need to do this before saccades are merged, or
% we might also remove saccades that occured right
% after a blink)
%-------------------------------------
if ETparams.blink.detectMode
    data = detectAndRemoveBlinks(data,ETparams);
end

data = flagMissing(data);

% Now merge saccades with short intervals between them
% and get information about them
%-------------------------------------
data = processSaccadesAndGlissades(data,ETparams);

% Implicitly detect fixations
% and get information about them
%-------------------------------------
if ETparams.fixation.qDetect
    data = detectFixations (data,ETparams);
    data = processFixations(data,ETparams);
end