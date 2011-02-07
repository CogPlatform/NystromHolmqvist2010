function [data,qnoise] = removeNoise(data,ETparams)
% Detects and removes un-physiological movement (which derives from noise
% and blinks)

%%% prepare algorithm parameters
minFixSamples   = ceil(ETparams.minFixDur/1000 * ETparams.samplingFreq);
V_threshold     = median(data.deg.vel)*2;

% Detect possible blinks and noise (where XY-coords are 0 or if the eyes move too fast)
% TODO make check more general, checking if outside screen, current doesn't
% work for our EyeLink, which doesn't give 0 (though already nan in that
% case)
% do not have to process things that are already NaN
qnoise = (data.deg.X <= 0 & data.deg.Y <= 0) |...
             data.deg.vel  > ETparams.blinkVelocityThreshold |...
         abs(data.deg.acc) > ETparams.blinkAccThreshold;

% find bounds of blinks or noise as detected above
[noiseon,noiseoff]      = findContiguousRegions(qnoise);

% find bounds of data above threshold
[threshon,threshoff]    = findContiguousRegions(data.deg.vel > V_threshold);

% Process one blink or noise period at the time, refine the bounds
% We refine using the velocity threshold crosses computed on top. As this
% threshold is lower than the blink velocity threshold, on- and offset of
% this (usually very low!) median velocity threshold should enclose blink
% velocity thresholds, but not necessarily for any of the other sources of
% noise.
% Only replace if the noise bounds are enclosed by the median velocity
% bounds. This also removes the possibility that we latch on to a wrong
% bound much further away in the data, as was possible in the old version
% (although not likely to generate much error).
for p = 1:length(noiseon)
    qenclosed = threshon<=noiseon(p) & threshoff>=noiseoff(p);
    
    if any(qenclosed)
        noiseon(p)  = threshon (qenclosed);
        noiseoff(p) = threshoff(qenclosed);
    end
end

% create boolean matrix given refined noise bounds
qnoise = bounds2bool(noiseon,noiseoff,length(data.deg.vel));
% remove data that is due to noise
data.deg.X(qnoise)      = nan;
data.deg.Y(qnoise)      = nan;
data.deg.vel(qnoise)    = nan;
data.deg.acc(qnoise)    = nan;

% second pass: find those sections of data enclosed in nans that are too
% short to be meaningful (less than minimum fixation duration) and delete
% those too
[dataon,dataoff] = findContiguousRegions(~isnan(data.deg.vel));
for p=length(dataon):-1:1
    % Check that the section of data is longer than the minimum fixation
    % duration. Keep the indices if not so we can delete it later
    if dataoff(p)-dataon(p) >= minFixSamples
        dataon (p) = [];
        dataoff(p) = [];
        continue;
    end
end
noiseidxs = bounds2ind(dataon,dataoff);
% remove useless data
data.deg.X(noiseidxs)   = nan;
data.deg.Y(noiseidxs)   = nan;
data.deg.vel(noiseidxs) = nan;
data.deg.acc(noiseidxs) = nan;

% lastly, notify if more than 20% nan
if sum(isnan(data.deg.vel))/length(data.deg.vel) > 0.20
    disp('Warning: This trial contains > 20 % noise+blinks samples')
    data.qNoiseTrial = true;
else
    data.qNoiseTrial = false;
end