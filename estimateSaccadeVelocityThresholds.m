function data = estimateSaccadeVelocityThresholds(data,ETparams,qusecentralsample)
% iteratively establishes the best threshold for saccade detection for this
% trial. This is done either based on the eye velocity trace or based on
% the velocity after cross correlated with a saccade template.
% Given a threshold T, we take all data of the trial where the eye velocity
% as less than T and calculate its mean and std. We then establish a new
% threshold at V = mean + 6*std. We repeat this until the new threshold is
% less than 1�/s lower than the old threshold. The procedure is the same
% except that the procedure finished when the change in correlation
% threshold is less than 1% (.01).
% The thus established velocity threshold is close to optimal in that it
% allows us to detect as many saccades as possible given the noise in the
% data but does not detect too many due to possibly high noise in the data.
%
% !! Call this function with two parameters, unless you know what you are
% doing.

% prepare algorithm parameters
minFixSamples       = ceil(ETparams.fixation.minDur/1000 * ETparams.samplingFreq);
centralFixSamples   = ceil(ETparams.saccade.minDur /6000 * ETparams.samplingFreq);

% select parameters and data to work with
if ETparams.data.qApplySaccadeTemplate
    field_peak  = 'xCorrPeakThreshold';
    field_onset = 'xCorrOnsetThreshold';
    vel         = data.deg.xcorr_vel;
else
    field_peak  = 'peakVelocityThreshold';
    field_onset = 'onsetVelocityThreshold';
    vel         = data.deg.vel;
end

% assign initial thresholds
data.saccade.(field_peak) = ETparams.saccade.(field_peak);
previousPeakDetectionThreshold = inf;

% iterate while we're gaining more than a 1� decrease in saccade peak
% velocity threshold
while ( ETparams.data.qApplySaccadeTemplate && previousPeakDetectionThreshold - data.saccade.(field_peak) > .01)... % running on xcorr output
        ||...
      (~ETparams.data.qApplySaccadeTemplate && previousPeakDetectionThreshold - data.saccade.(field_peak) > 1)...   % running on velocity trace
    
    previousPeakDetectionThreshold = data.saccade.(field_peak);
    
    % Find parts where the velocity is below the threshold, possible
    % fixation time (though this is still crude)
    qBelowThresh = vel < data.saccade.(field_peak);
    
    if nargin==2 || qusecentralsample
        % We need to cut off the edges of the testing intervals and only
        % use parts of the data that are likely to belong to fixations or
        % the iteration will not converge to a lower threshold. So always
        % use this code path (just call this function with 2 arguments),
        % unless you want to see it for yourself. This is not just done to
        % speed up convergence.
        % NB: although this does not match how the algorithm is described
        % in Nystr�m & Holmqvist, 2010, it does match the code they made
        % available. As explained above, the more simple method they
        % described in their paper does not converge to lower thresholds
        % (in the minimal testing I did at least), while this code-path
        % appears to be robust.
        
        % get bounds of these detected peaks
        [threshon,threshoff] = bool2bounds(qBelowThresh);
        
        % throw out intervals that are too short and therefore unlikely to
        % be fixations
        qLongEnough = threshoff-threshon >= minFixSamples;
        threshon    = threshon (qLongEnough);
        threshoff   = threshoff(qLongEnough);
        
        % shrink them as done in Nystrom's version, to make sure we don't
        % catch the data that is still during the saccade
        threshon    = threshon +floor(centralFixSamples);
        threshoff   = threshoff-ceil (centralFixSamples);
        
        % convert to data selection indices
        idx         = bounds2ind(threshon,threshoff);
        
        % get mean and std of this data
        meanVel     = nanmean(vel(idx));
        stdVel      = nanstd (vel(idx));
    else
        meanVel     = nanmean(vel(qBelowThresh));
        stdVel      = nanstd (vel(qBelowThresh));
    end
    
    % calculate new thresholds
    data.saccade.(field_peak)       = meanVel + 6*stdVel;
    data.saccade.(field_onset)      = meanVel + 3*stdVel;
end

% Calculate peak and onset velocity threshold as well, even if peaks
% are detected from the cross correlation trace.
% ETparams.saccade.qSaccadeTemplateRefine determines whether saccade
% onset/offset refinement is based on the velocity trace (false). If so,
% these are needed.
if ETparams.data.qApplySaccadeTemplate && ~ETparams.saccade.qSaccadeTemplateRefine
    if nargin==2 || qusecentralsample
        % get mean and std of this data
        meanVel     = nanmean(data.deg.vel(idx));
        stdVel      = nanstd (data.deg.vel(idx));
    else
        meanVel     = nanmean(data.deg.vel(qBelowThresh));
        stdVel      = nanstd (data.deg.vel(qBelowThresh));
    end
    data.saccade.peakVelocityThreshold   = meanVel + 6*stdVel;
    data.saccade.onsetVelocityThreshold  = meanVel + 3*stdVel;
end