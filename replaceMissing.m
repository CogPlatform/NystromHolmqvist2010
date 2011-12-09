function data = replaceMissing(data,qInterpMissingPos)
% Currently, this only replaces missing data with linear interpolation for
% the velocity traces. It should be straightforward to implement if you
% need this for position or other traces.

% process data
data = replaceMissingImplementation(data,'deg',qInterpMissingPos,true);

if isfield(data.pix,'vel')
    data = replaceMissingImplementation(data,'pix',qInterpMissingPos,false);
end




function data = replaceMissingImplementation(data,datatype,qInterpMissingPos,qPrintInfo)

% get eye velocities in pixels/degree
vel     = data.(datatype).vel;
if strcmp(datatype,'pix')
    velX    = data.pix.velX;
    velY    = data.pix.velY;
    if qInterpMissingPos
        X   = data.pix.X;
        Y   = data.pix.Y;
    end
elseif strcmp(datatype,'deg')
    velX    = data.deg.velAzi;
    velY    = data.deg.velEle;
    if qInterpMissingPos
        X   = data.deg.Azi;
        Y   = data.deg.Ele;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% We want to deal with all the nan in the data.
% This is getting rid of blinks and such...
qNaN = isnan(vel);
if any(qNaN)
    if qPrintInfo
        fprintf('  N NaN samples: %d (%.2f%%)\n',sum(qNaN),sum(qNaN)./length(vel)*100);
    end
    
    [nanon,nanoff] = bool2bounds(qNaN);
    % gooi NaNnen gevonden aan begin en einde trial eruit, daar kunnen we
    % niets mee...
    if nanon(1)==1
        nanon(1)    = [];
        nanoff(1)   = [];
    end
    if ~isempty(nanoff) && nanoff(end)==length(vel)     % might be empty by now...
        nanon(end)  = [];
        nanoff(end) = [];
    end
    
    for p=1:length(nanon)
        % pas indices aan, nanon(p) and nanoff(p) wijzen naar de eerste
        % en laatste NaN in een serie
        on  = nanon(p)-1;
        off = nanoff(p)+1;
        % replace with interpolated velocity
        [vel,velX,velY] = replaceIntervalVelocity(vel,velX,velY,on,off);
        
        if qInterpMissingPos
            X(on:off) = linspace(X(on), X(off), off-on+1);
            Y(on:off) = linspace(Y(on), Y(off), off-on+1);
        end
    end
    
    if qPrintInfo
        % show how many NaN we have left now, those cannot be handled
        fprintf('   -> N NaN samples left: %d (%.2f%%)\n',sum(isnan(vel)),sum(isnan(vel))./length(vel)*100);
    end
    
    % store data with nans removed
    data.(datatype).vel = vel;
    if strcmp(datatype,'pix')
        data.pix.velX = velX;
        data.pix.velY = velY;
        if qInterpMissingPos
            data.pix.X = X;
            data.pix.Y = Y;
        end
    elseif strcmp(datatype,'deg')
        data.deg.velAzi = velX;
        data.deg.velEle = velY;
        if qInterpMissingPos
            data.deg.Azi = X;
            data.deg.Ele = Y;
        end
    end
end