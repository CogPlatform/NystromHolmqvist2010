function plotClassification(data,datatype,veltype,sampleRate,glissadeSearchWindow,rect,varargin)

% standard plot routine for monocular data
% See also plotWithMark, plot2D and axes
% call syntax:
% plotClassification(data, datatype, sampleRate, glissadeSearchWindow, res, title)
% - data: see below for the fields it needs to contain, they're all
%         unpacked in the same place so its easy to see
% - datatype: 'pix' or 'deg'
% - veltype: type of velocity to plot. 'vel': 2D velocity,
%   'velX': X/azimuthal velocity, 'velY': Y/elevational velocity
% - sampleRate
% - glissadeSearchWindow: in milliseconds
% - rect: struct with extends of screen window, [upper left (x,y) lower
%   right (x,y)]. rect will be read from rect.(datatype)
% the rest is optional key-value parameters:
% - 'title': plot title
% - 'pic': struct with two fields, imdata with the image and offset to
%   encode the offset between the top left of the screen and of the
%   picture.
% - 'highlight': sample idxes for intervals to highlight
% - 'showSacInScan': put saccade on and offsets markers in 2D view
% - 'refCoords': single reference point to draw
% - 'tRefCoords': coordinates for reference points to draw that are
%                 localized in time (e.g., indicating when a target was
%                 presented
% - 'scanRefCoords': reference points to be drawn in 2D
% - 'zeroStartT': if true, will set first sample to t==0
%
% LEGEND of the plots:
% First two plots show the eye's azimuth and elevation in degree (Fick
% angles)
% Blue markers indicate the start of fixations, red the end
% Third plot shows the angular velocity of the eye, with blue markers
% indicating the start of saccades, red markers their end, cyan stars the
% end of high velocity glissades and green stars the end of low velocity
% glissades (start of glissades is end of preceding saccade)
% Finally, the last two plots show the subject's scanpath, either
% indicating the classified fixations or the raw eye position data. The eye
% position at the start of the trial (or the first fixation) is marked by a
% blue marker and the end of the trial (or last fixation) by a red marker.

narginchk(6,inf)

assert(isfield(data.(datatype),'vel'),'data for %s not available, enable ETparams.data.alsoStoreandDiffPixels',datatype);

%%% unpack the needed variables
% key-val parameters
titel = '';
pic = [];
highlightTime = [];
qIndicateSacInScanpath = false;
refCoords = [];
scanRefCoords = [];
tRefCoords = [];
qZeroStartT= false;
if nargin>=7
    nKeyValInp = nargin-6;
    assert(mod(nKeyValInp,2)==0,'key-value arguments must come in pairs')
    expectVal = false;                          % start expecting an option name, not a value
    p = 1;
    while p <= length(varargin)
        if ~expectVal   % the current value should be a setting
            assert(ischar(varargin{p}),'option name must be a string')
            expectVal = true;
        else    % we just read a setting name, now look for a value for that setting
            switch varargin{p-1}
                case 'title'
                    titel = texlabel(varargin{p},'literal');
                case 'pic'
                    pic = varargin{p};
                case 'highlight'
                    if ~any(isnan(varargin{p}))
                        highlightTime = varargin{p};
                    end
                case 'showSacInScan'
                    qIndicateSacInScanpath = varargin{p};
                case 'refCoords'
                    refCoords = varargin{p};
                    assert(numel(refCoords)==2,'refCoords input should have two elements')
                case 'scanRefCoords'
                    scanRefCoords = varargin{p};
                    assert(size(scanRefCoords,2)==2,'scanRefCoords input should be an Nx2 matrix')
                case 'tRefCoords'
                    tRefCoords = varargin{p};
                    assert(size(tRefCoords,2)==4,'tRefCoords input should be an Nx4 matrix')
                case 'zeroStartT'
                    qZeroStartT = ~~varargin{p};
                otherwise
                    error('do not understand input %s',varargin{p-1})
            end
            expectVal = false;
        end
        p=p+1;
    end
end

rect = rect.(datatype);

% prepare labels
missing = data.deg.missing;
if strcmp(datatype,'deg')
    unit = '°';
    xlbl = ['Azimuth (' unit ')'];
    ylbl = ['Elevation (' unit ')'];
else
    unit = 'pix';
    xlbl = ['Horizontal (' unit ')'];
    ylbl = ['Vertical (' unit ')'];
end
plbl = 'pupil size';
pvlbl= 'abs({\delta} pupil size)';

if strcmp(datatype,'deg')
    vxlbl = 'Azi';
    vylbl = 'Ele';
else
    vxlbl = 'X';
    vylbl = 'Y';
end
vlbl = {['Velocity 2D'      ' (' unit '/s)'],['Velocity '     vxlbl ' (' unit '/s)'], ['Velocity '     vylbl ' (' unit '/s)']};
albl = {['Acceleration 2D'  ' (' unit '/s^2)'],['Acceleration ' vxlbl ' (' unit '/s^2)'], ['Acceleration ' vylbl ' (' unit '/s^2)']};
vidx = find(ismember({'vel','velX','velY'},veltype));
clbl = 'Xcorr  response';   % double space on purpose, reads easier for me

% time series
% position
qHaveNoSacDataP     = false;
qHaveSacOnlyDataP   = false;
if strcmp(datatype,'pix')
    xdata   = data.pix.X;
    ydata   = data.pix.Y;
    % see if have data with saccades cut out
    if isfield(data.pix,'XNoSac')
        xdataNoSac          = data.pix.XNoSac;
        ydataNoSac          = data.pix.YNoSac;
        qHaveNoSacDataP     = true;
    end
    % see if have data with only saccades
    if isfield(data.pix,'XSac')
        xdataOnlySac        = data.pix.XSac;
        ydataOnlySac        = data.pix.YSac;
        qHaveSacOnlyDataP   = true;
    end
elseif strcmp(datatype,'deg')
    xdata   = data.deg.Azi;
    ydata   = data.deg.Ele;
    % see if have data with saccades cut out
    if isfield(data.deg,'AziNoSac')
        xdataNoSac          = data.deg.AziNoSac;
        ydataNoSac          = data.deg.EleNoSac;
        qHaveNoSacDataP     = true;
    end
    % see if have data with only saccades
    if isfield(data.deg,'AziSac')
        xdataOnlySac        = data.deg.AziSac;
        ydataOnlySac        = data.deg.EleSac;
        qHaveSacOnlyDataP   = true;
    end
end


% time
if isfield(data,'time')
    time = data.time;
else
    time = ([1:length(xdata)]-1)/sampleRate * 1000;
end
if qZeroStartT
    time = time-time(1);
end
% map highlight sample indices to timestamps
highlightTimet = [];
if ~isempty(highlightTime)
    highlightTimet = interp1(1:length(time),time,highlightTime);
end

% velocity
if strcmp(datatype,'pix')
    mainf  = 'pix';
    fields = {'vel','velX','velY'};
elseif strcmp(datatype,'deg')
    mainf  = 'deg';
    fields = {'vel','velAzi','velEle'};
end
qHaveNoSacDataV     = false;
qHaveSacOnlyDataV   = false;
[velNoSac,velOnlySac] = deal(cell(1,3));
for f=length(fields):-1:1
    if isfield(data.(mainf),fields{f})
        vel{f} = data.(mainf).(fields{f});
    end
    if isfield(data.(mainf),[fields{f} 'NoSac'])
        velNoSac{f} = data.(mainf).([fields{f} 'NoSac']);
        qHaveNoSacDataV = true;
    end
    if isfield(data.(mainf),[fields{f} 'Sac'])
        velOnlySac{f} = data.(mainf).([fields{f} 'Sac']);
        qHaveSacOnlyDataV = true;
    end
end


% acceleration
if strcmp(datatype,'pix')
    mainf  = 'pix';
    fields = {'acc','accX','accY'};
elseif strcmp(datatype,'deg')
    mainf  = 'deg';
    fields = {'acc','accAzi','accEle'};
end
qHaveAcceleration = false;
for f=length(fields):-1:1
    if isfield(data.(mainf),fields{f})
        acc{f} = data.(mainf).(fields{f});
        qHaveAcceleration = true;
    end
end

% markers
% for missing flags, also include blinks. we'd want to color original or
% interpolated data during a blink as well
if isfield(data,'blink')
    qMissOrBlink =                bounds2bool(missing.on   ,missing.off   ,length(vel{1}));
    qMissOrBlink = qMissOrBlink | bounds2bool(data.blink.on,data.blink.off,length(vel{1}));
    [missing.on,missing.off] = bool2bounds(qMissOrBlink);
end
if ~isempty(missing.on)
    missFlag = Interleave(arrayfun(@(on,off) on:off,missing.on,missing.off,'uni',false),repmat({{'-r'}},1,length(missing.on)));
else
    missFlag = {};
end

sacon   = data.saccade.on;
sacoff  = data.saccade.off;
if isfield(data.saccade,'onPrecise')
    saconPrecise = data.saccade.onPrecise;
else
    saconPrecise = [];
end
if isfield(data,'blink')
    blinkMarks = {data.blink.on, {'mo','MarkerFaceColor','magenta','MarkerSize',4}, ... % blink on  markers
                  data.blink.off,{'mo','MarkerFaceColor','magenta','MarkerSize',4}};    % blink off markers
else
    blinkMarks = {};
end
if isfield(data,'glissade')
    qhighvelglissade = data.glissade.type==2;                                           % determine glissade type: 1 is low velocity, 2 is high velocity
    glisMarks = {data.glissade.off(qhighvelglissade) ,{'c*'},...                        % high velocity glissade off markers
                 data.glissade.off(~qhighvelglissade),{'g*'}};                          % low  velocity glissade off markers
else
    glisMarks = {};
end
if isfield(data,'fixation')
    qHaveFixations = true;
    xfixpos   = data.fixation.(['meanX_' datatype]);
    yfixpos   = data.fixation.(['meanY_' datatype]);
    fixMarks  = {data.fixation.on, {'bo','MarkerFaceColor','blue','MarkerSize',4},...   % fixation on  markers
                 data.fixation.off,{'ro','MarkerFaceColor','red' ,'MarkerSize',4}};     % fixation off markers
else
    qHaveFixations = false;
    fixMarks  = {};
end
% thresholds
if isfield(data.saccade,'peakXCorrThreshold')
    % used saccade template
    qSaccadeTemplate = true;
    saccadePeakXCorrThreshold       = data.saccade.peakXCorrThreshold;
else
    % saccades have been classified from the velocity trace
    qSaccadeTemplate = false;
end

if isfield(data.saccade,'offsetXCorrThreshold')
    % refinement also run from xcorr responses
    qSaccadeTemplateRefinement      = true;
    saccadeOnsetXCorrThreshold      = data.saccade.onsetXCorrThreshold;
    saccadeOffsetXCorrThreshold     = data.saccade.offsetXCorrThreshold;
    saccadePeakVelocityThreshold    = [];
    saccadeOnsetVelocityThreshold   = [];
    saccadeOffsetVelocityThreshold  = [];
else
    % refinement run from velocity trace
    qSaccadeTemplateRefinement      = false;
    saccadePeakVelocityThreshold    = data.saccade.peakVelocityThreshold;
    saccadeOnsetVelocityThreshold   = data.saccade.onsetVelocityThreshold;
    saccadeOffsetVelocityThreshold  = data.saccade.offsetVelocityThreshold;
end
glissadeSearchSamples   = ceil(glissadeSearchWindow./1000 * sampleRate);


%%% determine time axis limits
mmt  = [min(time) max(time)];

%%% determine axes positions
if qSaccadeTemplate || qHaveAcceleration
    if isfield(data,'pupil') && ~isempty(data.pupil.size)
        xplotPos = [0.05 0.88 0.90 0.08];
        yplotPos = [0.05 0.76 0.90 0.08];
        pplotPos = [0.05 0.64 0.90 0.08];
        vplotPos = [0.05 0.50 0.90 0.10];
        acplotPos = [0.05 0.36 0.90 0.10];
        fixplotPos = [0.05 0.04 0.43 0.28];
        rawplotPos = [0.52 0.04 0.43 0.28];
    else
        xplotPos = [0.05 0.88 0.90 0.08];
        yplotPos = [0.05 0.76 0.90 0.08];
        vplotPos = [0.05 0.60 0.90 0.12];
        acplotPos = [0.05 0.44 0.90 0.12];
        fixplotPos = [0.05 0.06 0.43 0.34];
        rawplotPos = [0.52 0.06 0.43 0.34];
    end
else
    if isfield(data,'pupil') && ~isempty(data.pupil.size)
        xplotPos = [0.05 0.88 0.90 0.08];
        yplotPos = [0.05 0.76 0.90 0.08];
        pplotPos = [0.05 0.60 0.90 0.12];
        vplotPos = [0.05 0.44 0.90 0.12];
        fixplotPos = [0.05 0.06 0.43 0.34];
        rawplotPos = [0.52 0.06 0.43 0.34];
    else
        xplotPos = [0.05 0.84 0.90 0.12];
        yplotPos = [0.05 0.68 0.90 0.12];
        vplotPos = [0.05 0.52 0.90 0.12];
        fixplotPos = [0.05 0.06 0.43 0.40];
        rawplotPos = [0.52 0.06 0.43 0.40];
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% plot X trace with fixation markers
ax = axes('position',xplotPos);
hold on;
plotTimeHighlights(highlightTimet,rect([1 3]));
if ~isempty(refCoords)
    plot([time(1) time(end)],refCoords(1)*[1 1],'b');
end
if ~isempty(tRefCoords)
    for p=1:size(tRefCoords,1)
        plot(tRefCoords(p,1:2),tRefCoords(p,[3 3]),'r')
    end
end
if qHaveNoSacDataP
    plot(time,xdata,'k');
    pdat = xdataNoSac;
    style = {'g-'};
else
    pdat = xdata;
    style = {'k-'};
end
if qHaveSacOnlyDataP
    plot(time,xdataOnlySac,'c');
end
plotWithMark(time,pdat,style,[],...                                     % data (y,x), style
             'time (ms) - fixations',xlbl,titel,...                     % x-axis label, y-axis label, axis title
             missFlag{:}, ...                                           % color part of trace that is missing
             blinkMarks{:}, ...                                         % blink markers (if any)
             fixMarks{:} ...                                            % fixation markers (if any)
            );
xlim([mmt(1) mmt(2)]);
grid on;box on;axis ij;


%%% plot Y trace with fixation markers
ay = axes('position',yplotPos);
hold on;
plotTimeHighlights(highlightTimet,rect([2 4]));
if ~isempty(refCoords)
    plot([time(1) time(end)],refCoords(2)*[1 1],'b');
end
if ~isempty(tRefCoords)
    for p=1:size(tRefCoords,1)
        plot(tRefCoords(p,1:2),tRefCoords(p,[4 4]),'r')
    end
end
if qHaveNoSacDataP
    plot(time,ydata,'k');
    pdat = ydataNoSac;
    style = {'g-'};
else
    pdat = ydata;
    style = {'k-'};
end
if qHaveSacOnlyDataP
    plot(time,ydataOnlySac,'c');
end
plotWithMark(time,pdat,style,[],...                                     % data (y,x), style
             'time (ms) - fixations',ylbl,'',...                        % x-axis label, y-axis label, axis title
             missFlag{:}, ...                                           % color part of trace that is missing
             blinkMarks{:}, ...                                         % blink markers (if any)
             fixMarks{:} ...                                            % fixation markers (if any)
            );
xlim([mmt(1) mmt(2)]);
grid on;box on;axis ij;


%%% plot pupil size trace with blink markers
if isfield(data,'pupil') && ~isempty(data.pupil.size)
    % pupil size:
    % determine axis size
    psr = max(data.pupil.size)-min(data.pupil.size);
    axisSize = [];
    if psr~=0
        axisSize = [mmt(1) mmt(2) min(data.pupil.size)-.03*psr max(data.pupil.size)+.03*psr];
    end
    ap = axes('position',pplotPos);
    hold on;
    plotTimeHighlights(highlightTimet,axisSize(3:4));
    plotWithMark(time,data.pupil.size,{'k-'},[],...                     % data (y,x), style
                 'time (ms) - blinks',plbl,'',...                       % x-axis label, y-axis label, axis title
                 missFlag{:}, ...                                       % color part of trace that is missing
                 blinkMarks{:} ...                                      % blink markers (if any)
                );
    if ~isempty(axisSize)
        axis(axisSize)
    end
    % change of pupil size:
    pvdat = abs(data.pupil.dsize);
    % determine axis size
    axisSize = [];
    if max(max(pvdat))~=0
        axisSize = [mmt(1) mmt(2) 0 max(pvdat)*1.03];
    end
    apv= axes('position',pplotPos);
    hold on;
    plotTimeHighlights(highlightTimet,axisSize(3:4));
    % line at 0
    plot([time(1) time(end)],[0 0],'b');
    hold on;
    plotWithMark(time,pvdat,{'k-'},[],...                               % data (y,x), style
                 'time (ms) - blinks',pvlbl,'',...                      % x-axis label, y-axis label, axis title
                 missFlag{:}, ...                                       % color part of trace that is missing
                 blinkMarks{:} ...                                      % blink markers (if any)
                );
    if ~isempty(axisSize)
        axis(axisSize);
    end
    if isfield(data,'blink') && isfield(data.blink,'peakDSizeThreshold')
        % plot pupil size change thresholds for blink classification
        hold on;
        plot(mmt, [1 1]*data.blink.peakDSizeThreshold,'r--')
        plot(mmt, [1 1]*data.blink.onsetDSizeThreshold,'r:')
        for p=1:length(data.blink.off)
            plot(time([data.blink.off(p) min(glissadeSearchSamples+data.blink.off(p),end)]), [1 1]*data.blink.offsetDSizeThreshold(p),'r-'); % the "end" is returns the length of time. Cool end works everywhere inside an index expression!
        end
        hold off;
    end
    % at start size, not dsize, is visible
    set([apv; allchild(apv)],'visible','off');
    % need to set visible axis to current and topmost axis for zooming to
    % operate on rigth axis. (If we don't do this, x zoom still works as
    % all axes are linked on x, by looking at y range reveals last drawn in
    % a given position is always target of zoom, even if it isn't
    % visible...)
    axes(ap);
    % toggle button
    uicontrol(...
    'Style','togglebutton',...
    'String','d',...
    'FontName','symbol',...
    'Units','Normalized',...
    'Position',[sum(pplotPos([1 3]))+.01 sum(pplotPos([2 4]))-.055 .02 .03],...
    'Callback',@Pupil_Callback);
else
    ap  = [];
    apv = [];
end


%%% plot velocity trace with saccade and glissade markers
av2 = axes('position',vplotPos);
plotVel(time,vel{1},velNoSac{1},velOnlySac{1},vlbl{1},'vel',datatype,...
    missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTimet,...
    qSaccadeTemplateRefinement,saccadePeakVelocityThreshold,saccadeOnsetVelocityThreshold,glissadeSearchSamples,saccadeOffsetVelocityThreshold);
if ~isscalar(vel)
    avx = axes('position',vplotPos);
    plotVel(time,vel{2},velNoSac{2},velOnlySac{2},vlbl{2},'velX',datatype,...
        missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTimet,...
        qSaccadeTemplateRefinement,saccadePeakVelocityThreshold,saccadeOnsetVelocityThreshold,glissadeSearchSamples,saccadeOffsetVelocityThreshold);
    avy = axes('position',vplotPos);
    plotVel(time,vel{3},velNoSac{3},velOnlySac{3},vlbl{3},'velY',datatype,...
        missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTimet,...
        qSaccadeTemplateRefinement,saccadePeakVelocityThreshold,saccadeOnsetVelocityThreshold,glissadeSearchSamples,saccadeOffsetVelocityThreshold);
    vaxs = [av2 avx avy];
    % show desired vel at start
    toHide = [1:3]; toHide(toHide==vidx) = [];
    for p=toHide
        set([vaxs(p); allchild(vaxs(p))],'visible','off');
    end
    axes(vaxs(vidx));   % set visible axis to current and topmost axis
    % toggle button
    strsv = {'v2','vx','vy'};
    strs2= strsv(toHide);
    vt1 = uicontrol(...
        'Style','pushbutton',...
        'String',strs2{1},...
        'Units','Normalized',...
        'Position',[sum(vplotPos([1 3]))+.01 sum(vplotPos([2 4]))-.045 .02 .03],...
        'Callback',@(obj,~,~) VelAcc_Callback(obj,'vel'));
    vt2 = uicontrol(...
        'Style','pushbutton',...
        'String',strs2{2},...
        'Units','Normalized',...
        'Position',[sum(vplotPos([1 3]))+.01 sum(vplotPos([2 4]))-.085 .02 .03],...
        'Callback',@(obj,~,~) VelAcc_Callback(obj,'vel'));
    vts = [vt1 vt2];
else
    vaxs = av2;
end

%%% either plot cross correlation output with saccade and glissade markers,
%%% or use the space to plot acceleration, or fuck it
aaxs = [];  % empty if no acceleration plots
ac   = [];  % empty if no cross correlation output plot
if qSaccadeTemplate
    % determine axis size
    axisSize = [mmt(1) mmt(2) 0 min(2.5,max(data.deg.velXCorr))];    % xcorr values above 2.5 seem to only occur due to noise
    ac = axes('position',acplotPos);
    hold on;
    plotTimeHighlights(highlightTimet,axisSize(3:4));
    % line at 0
    plot([time(1) time(end)],[0 0],'b');
    hold on;
    plotWithMark(time,data.deg.velXCorr,{'k-'},[],...                       % data (y,x), style
                 'time (ms) - saccades/glissades',clbl,'',...               % x-axis label, y-axis label, axis title
                 sacon, {'bo','MarkerFaceColor','blue','MarkerSize',4},...  % saccade on  markers
                 sacoff,{'ro','MarkerFaceColor','red' ,'MarkerSize',4},...  % saccade off markers
                 glisMarks{:}, ...                                          % glissade markers (if any)
                 blinkMarks{:} ...                                          % blink markers (if any)
                );
    hold on;
    % add classification thresholds
    plot(mmt,[1 1]*saccadePeakXCorrThreshold,'r--')
    if qSaccadeTemplateRefinement
        plot(mmt,[1 1]*saccadeOnsetXCorrThreshold,'r:')
        for p=1:length(sacoff)
            plot(time([sacoff(p) min(glissadeSearchSamples+sacoff(p),end)]),[1 1]*saccadeOffsetXCorrThreshold(p),'r-'); % the "end" is returns the length of time. Cool end works everywhere inside an index expression!
        end
    end
    hold off;
    axis(axisSize);
end
if qHaveAcceleration
    av2 = axes('position',acplotPos);
    plotAcc(time,acc{1},albl{1},'vel', missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTimet);
    if ~isscalar(acc)
        avx = axes('position',acplotPos);
        plotAcc(time,acc{2},albl{2},'velX',missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTimet);
        avy = axes('position',acplotPos);
        plotAcc(time,acc{3},albl{3},'velY',missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTimet);
        aaxs = [av2 avx avy];
    else
        aaxs = av2;
    end
end
acaxs = [ac aaxs];
if ~isempty(acaxs) && ~isscalar(acaxs)
    % figure out which plots we have, show most desired one by default, add
    % correct number of toggle buttons
    % 1. get labels
    strsac = {};
    if qSaccadeTemplate
        strsac = [strsac {'xcorr'}];
    end
    if qHaveAcceleration
        strsac = [strsac {'a2'}];
        if ~isscalar(aaxs)
            strsac = [strsac {'ax','ay'}];
        end
    end
    % figure out toggle buttons
    nToggle = length(strsac)-1;
    if nToggle==1
        off = -.065;
    elseif nToggle==2
        off = [-.045 -.085];
    elseif nToggle==3
        off = [-.025 -.065 -.105];
    end
    for t=1:nToggle
        acts(t) = uicontrol(...
            'Style','pushbutton',...
            'String',strsac{t+1},...
            'Units','Normalized',...
            'Position',[sum(acplotPos([1 3]))+.01 sum(acplotPos([2 4]))+off(t) .02 .03],...
            'Callback',@(obj,~,~) VelAcc_Callback(obj,'acc'));
    end
    
    % show only desired panel at start
    for p=acaxs(2:end)
        set([p; allchild(p)],'visible','off');
    end
    axes(acaxs(1));   % set visible axis to current and topmost axis
end

% link x-axis (time) of the three or more timeseries for easy viewing
allTSeries = [ax ay ap apv vaxs acaxs];
linkaxes(allTSeries,'x');


%%% plot scanpath of raw data and of fixations
fix2dhndls = [];
if qHaveFixations || qHaveNoSacDataP || qHaveSacOnlyDataP
    asf = axes('position',fixplotPos);
    hold on
    if nargin>=8 && strcmp(datatype,'pix') && ~isempty(pic)
        imagesc([0 size(pic.imdata,2)]+pic.offset(2),[0 size(pic.imdata,1)]+pic.offset(1),pic.imdata);
    end
    if ~isempty(scanRefCoords)
        plot(scanRefCoords(:,1),scanRefCoords(:,2),'b.');
    end
    if ~isempty(refCoords)
        aspectr = (rect(3)-rect(1))/(rect(4)-rect(2));
        plot(refCoords(1)+(rect(3)-rect(1))*.05/aspectr*[-1 1],refCoords(2)                      *[ 1 1],'b');
        plot(refCoords(1)                              *[ 1 1],refCoords(2)+(rect(4)-rect(2))*.05*[-1 1],'b');
    end
    if qHaveFixations
        usrDatf.tag = 'evt';
        usrDatf.ton = time(data.fixation.on);
        usrDatf.toff= time(data.fixation.off);
        fix2dhndls = plotWithMark(xfixpos,yfixpos,{'k-'},usrDatf,...                        % data (y,x), style, base userData
                     xlbl,ylbl,'',...                                                       % x-axis label, y-axis label, axis title
                     [1:length(xfixpos)],{'go','MarkerFaceColor','g','MarkerSize',4},...    % mark each fixation (that is marker on each datapoint we feed it
                     1,                  {'co','MarkerFaceColor','c','MarkerSize',4},...    % make first fixation marker blue
                     length(xfixpos),    {'mo','MarkerFaceColor','m','MarkerSize',4} ...    % make last  fixation marker red
                    );
    else
        extraInp = {};
        if ~isempty(highlightTime)
            for p=1:size(highlightTime,1)
                extraInp = [extraInp {[round(highlightTime(p,1)):round(highlightTime(p,2))],{'r-'}}];
            end
        end
        usrDatr.tag = 'raw';
        usrDatr.t   = time;
        if qHaveNoSacDataP && qHaveSacOnlyDataP
            usrDatrs   = usrDatr;
            usrDatrs.x = xdataOnlySac;
            usrDatrs.y = ydataOnlySac;
            noshndl    = plot(xdataOnlySac,ydataOnlySac,'c-','UserData',usrDatrs);
            hold on;
        end
        if qHaveNoSacDataP
            % when we have both onlySac and noSac and when we only have
            % noSac, we draw this one with plotWithMark
            pdat = {xdataNoSac,ydataNoSac};
            style = {'g-'};
        elseif qHaveSacOnlyDataP
            pdat = {xdataOnlySac,ydataOnlySac};
            style = {'c-'};
        end
        fix2dhndls = plotWithMark(pdat{1},pdat{2},style,usrDatr,...                          % data (y,x), style, base userData
                     xlbl,ylbl,'',...                                                       % x-axis label, y-axis label, axis title
                     1,                  {'co','MarkerFaceColor','c','MarkerSize',4},...    % use blue marker for first datapoint
                     length(xdata),      {'mo','MarkerFaceColor','m','MarkerSize',4},...    % use red  marker for last  datapoint
                     extraInp{:}                                                     ...
                    );
        if qHaveNoSacDataP && qHaveSacOnlyDataP
            fix2dhndls = [fix2dhndls noshndl];
        end
    end
    axis(rect([1 3 2 4]));
    grid on;box on;axis ij;
else
    asf = [];
end

asr = axes('position',rawplotPos);
hold on
if nargin>=8 && strcmp(datatype,'pix') && ~isempty(pic)
    imagesc([0 size(pic.imdata,2)]+pic.offset(2),[0 size(pic.imdata,1)]+pic.offset(1),pic.imdata);
end
if ~isempty(scanRefCoords)
    plot(scanRefCoords(:,1),scanRefCoords(:,2),'b.');
end
if ~isempty(refCoords)
    aspectr = (rect(3)-rect(1))/(rect(4)-rect(2));
    plot(refCoords(1)+(rect(3)-rect(1))*.05/aspectr*[-1 1],refCoords(2)                      *[ 1 1],'b');
    plot(refCoords(1)                              *[ 1 1],refCoords(2)+(rect(4)-rect(2))*.05*[-1 1],'b');
end
extraInp = {};
if ~isempty(highlightTime)
    for p=1:size(highlightTime,1)
        extraInp = [extraInp {[round(highlightTime(p,1)):round(highlightTime(p,2))],{'r-'}}];
    end
end
if qIndicateSacInScanpath
    extraInp = [extraInp {sacon, {'bo','MarkerFaceColor','b','MarkerSize',4,'UserDataNoGrow',true},...  % saccade on  markers
                          sacoff,{'ro','MarkerFaceColor','r','MarkerSize',4,'UserDataNoGrow',true}}];
end
usrDatr.tag = 'raw';
usrDatr.t   = time;
raw2dhndls = plotWithMark(xdata,ydata,{'k-'},usrDatr,...                            % data (y,x), style, base userData
             xlbl,ylbl,'',...                                                       % x-axis label, y-axis label, axis title
             1,                  {'co','MarkerFaceColor','c','MarkerSize',4},...    % use blue marker for first datapoint
             length(xdata),      {'mo','MarkerFaceColor','m','MarkerSize',4},...    % use red  marker for last  datapoint
             extraInp{:}                                                     ...
            );
%axis(rect([1 3 2 4]));
axis tight;grid on;box on;axis ij;

% link view of the two scanpath plots for easy viewing
linkaxes([asr asf],'xy');

% make sure we don't lose the standard toolbar
set(gcf,'Toolbar','figure');
set(gcf,'DockControls','off');
zoom on;

% link x-t time extents to data shown in 2D by setting up callbacks for
% actions that change the x-t, y-t axes
actions = {allTSeries,[raw2dhndls fix2dhndls]};
set(zoom(gcf),'ActionPostCallback',@(obj,evd) viewCallbackFcn(obj,evd,actions));
set(pan(gcf) ,'ActionPostCallback',@(obj,evd) viewCallbackFcn(obj,evd,actions));




    function Pupil_Callback(~,~,~)
        if strcmp(get(ap,'visible'),'on')
            set([ap;   allchild(ap)],'visible','off');
            set([apv; allchild(apv)],'visible','on');
            axes(apv);  % set visible axis to current and topmost axis
        else
            set([apv; allchild(apv)],'visible','off');
            set([ap;   allchild(ap)],'visible','on');
            axes(ap);   % set visible axis to current and topmost axis
        end
    end

    function VelAcc_Callback(obj,what)
        % find which pressed, and therefore which to show and hide
        but = get(obj,'String');
        switch what
            case 'vel'
                axs = vaxs;
                strs= strsv;
                ts  = vts;
            case 'acc'
                axs = acaxs;
                strs= strsac;
                ts  = acts;
        end
        if isempty(axs)
            return;
        end
        % do show and hide
        qShow   = strcmp(but,strs);
        toHidev = find(~qShow);
        toShow  = find( qShow);
        for q=toHidev
            set([axs(q); allchild(axs(q))],'visible','off');
        end
        set([axs(toShow); allchild(axs(toShow))],'visible','on');
        axes(axs(toShow));     % set visible axis to current and topmost axis
        % adjust labels on buttons
        strsVis  = strs(toHidev);
        for butI=1:length(ts)
            set(ts(butI),'String',strsVis{butI});
        end
    end
end

function plotVel(time,vel,velNoSac,velOnlySac,vlbl,veltype,datatype,...
    missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTime,...
    qSaccadeTemplateRefinement,saccadePeakVelocityThreshold,saccadeOnsetVelocityThreshold,glissadeSearchSamples,saccadeOffsetVelocityThreshold)
% determine axis size
axisSize = calcAxisExtents(vel,mmt);
% plot highlights
hold on;
plotTimeHighlights(highlightTime,axisSize(3:4));
% line at 0
plot([time(1) time(end)],[0 0],'b');
% data trace(s)
if ~isempty(velNoSac)
    plot(time,vel,'k');
    pdat = velNoSac;
    style = {'g-'};
else
    pdat = vel;
    style = {'k-'};
end
if ~isempty(velOnlySac)
    plot(time,velOnlySac,'c');
end
plotWithMark(time,pdat,style,[],...                                     % data (y,x), style
             'time (ms) - saccades/glissades',vlbl,'',...               % x-axis label, y-axis label, axis title
             missFlag{:}, ...                                           % color part of trace that is missing
             sacon, {'bo','MarkerFaceColor','blue','MarkerSize',4},...  % saccade on  markers
             sacoff,{'ro','MarkerFaceColor','red' ,'MarkerSize',4},...  % saccade off markers
             glisMarks{:}, ...                                          % glissade markers (if any)
             blinkMarks{:} ...                                          % blink markers (if any)
    );
if ~isempty(saconPrecise)
    hold on;
    plot(interp1(1:length(time),time,saconPrecise),zeros(size(saconPrecise)),'bx');
end
% add classification thresholds
if strcmp(datatype,'deg') && ~qSaccadeTemplateRefinement && strcmp(veltype,'vel')
    % dont plot if:
    % 1. if plotting pixels, as thresholds are in �/s
    % 2. if refinement was done with the saccade template responses as no
    %    velocity thresholds are then used; it would be misleading to plot
    %    them here
    % 3. if we're plotting a component velocity, as thresholds are for 2D
    %    velocity
    hold on;
    plot(mmt,[1 1]*saccadePeakVelocityThreshold,'r--')
    plot(mmt,[1 1]*saccadeOnsetVelocityThreshold,'r:')
    for p=1:length(sacoff)
        plot(time([sacoff(p) min(glissadeSearchSamples+sacoff(p),end)]),[1 1]*saccadeOffsetVelocityThreshold(p),'r-'); % the "end" is returns the length of time. Cool end works everywhere inside an index expression!
    end
    hold off;
end
if ~isempty(axisSize)
    axis(axisSize)
end
if ~strcmp(veltype,'vel')
    grid on;box on;axis ij;
end
end

function plotAcc(time,acc,albl,veltype,...
    missFlag,sacon,sacoff,saconPrecise,glisMarks,blinkMarks,mmt,highlightTime)
% determine axis size
axisSize = calcAxisExtents(acc,mmt);
% plot highlights
hold on;
plotTimeHighlights(highlightTime,axisSize(3:4));
% line at 0
plot([time(1) time(end)],[0 0],'b');
plotWithMark(time,acc,{'k-'},[],...                                     % data (y,x), style
             'time (ms) - saccades/glissades',albl,'',...               % x-axis label, y-axis label, axis title
             missFlag{:}, ...                                           % color part of trace that is missing
             sacon, {'bo','MarkerFaceColor','blue','MarkerSize',4},...  % saccade on  markers
             sacoff,{'ro','MarkerFaceColor','red' ,'MarkerSize',4},...  % saccade off markers
             glisMarks{:}, ...                                          % glissade markers (if any)
             blinkMarks{:} ...                                          % blink markers (if any)
    );
if ~isempty(saconPrecise)
    hold on;
    plot(interp1(1:length(time),time,saconPrecise),zeros(size(saconPrecise)),'bx');
end
if ~isempty(axisSize)
    axis(axisSize)
end
if ~strcmp(veltype,'vel')
    grid on;box on;axis ij;
end
end

function plotTimeHighlights(highlightTime,verExtents)
if ~isempty(highlightTime)
    for p=1:size(highlightTime,1)
        patch(highlightTime(p,[1 2 2 1]),verExtents([1 1 2 2]),[.8 .8 .8],'EdgeColor',[.8 .8 .8]);
    end
end
end

function axisSize = calcAxisExtents(var,mmt)
axisSize = [];
if any(~isnan(var))
    if min(0,min(var))==0
        axisSize = [mmt(1) mmt(2) 0 max(var)*1.03];
    else
        psr = max(var)-min(var);
        axisSize = [mmt(1) mmt(2) min(var)-.03*psr max(var)+.03*psr];
    end
end
end

function viewCallbackFcn(~,evd,actions)
% get new view
newTLims = evd.Axes.XLim;
% for each defined action, see if the changed axis is among the ones the
% action listens for
for p=1:size(actions,1)
    if ismember(evd.Axes,actions{p,1})
        % yes, found an actions listening for change to this axis.
        % execute view change on defined targets
        for q=1:length(actions{p,2})
            if strcmp(actions{p,2}(q).Type,'hggroup')
                hndls = actions{p,2}(q).Children;
            else
                hndls = actions{p,2}(q);
            end
            for l=1:length(hndls)
                dat = hndls(l).UserData;
                if isempty(dat)
                    continue;
                end
                if strcmp(dat.tag,'raw')
                    qData = dat.t>=newTLims(1) & dat.t<=newTLims(2);
                    % grow visible by one sample so that connecting
                    % lines for samples just outside t lims are
                    % visible, just like they are in the xt plots
                    [on,off] = bool2bounds(qData);
                    if ~isfield(dat,'dontGrow') || ~dat.dontGrow
                        on = max(1,on-1); off = min(off+1,length(dat.x));
                    end
                    % set plot data to new time limits
                    set(hndls(l),'XData',dat.x(on:off).','YData',dat.y(on:off).');
                elseif strcmp(dat.tag,'evt')
                    % find all fixations that are partially visible
                    qData =  (dat.ton>=newTLims(1) & dat.ton<=newTLims(2)) | (dat.toff>=newTLims(1) & dat.toff<=newTLims(2));
                    % set plot data to new time limits
                    hndls(l).XData = dat.x(qData).';
                    hndls(l).YData = dat.y(qData).';
                end
            end
        end
    end
end
end