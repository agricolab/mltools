%% function [Vpp, Lat, Raw, parms] = load_ioc(dataset, varargin)
%
% Args
% ----  
% dataset:str
%   path to mat.file from tms measurement
% varargin:keywords
%   channel: 'EDC_L'   
%       defining the channel for which to calculate the MEP measures    
%   preactivated: 100
%       if baseline period of a trial above baseline, trial is rejected
%
% Returns
% -------
% Vpp:matrix 
%   peak-to-peak amplitudes   
%   n x m matrix with n trials per m intensities 
% Lat:matrix 
%   latency estimates
%   n x m matrix with n trials per m intensities
% Raw:matrix 
%   latency estimates
%   n x m matrix with n samples per m intensities. TMS was applied at 100,
%   Fs is 1000 Hz
% parms:vector
%   [offset, slope, threshold] of a sigmoidal fit on the Vpp
%
% tip
% ---
% requires the corresponding lz_TMS_v2-4.m in path
%
% written by rgugg 
%
% changelog
% -------
% 19.03.19: created documentation
% 19.03.19: added sigmoidal fit
% 19.03.19: added baseline rejection based on thresholding
%
function [Vpp, Lat, Raw, parms] = load_ioc(dataset, varargin)     
    % turn of warning, as we cant load all objects in mat
    warning off
    curdir = pwd;
    cd ([fileparts(mfilename('fullpath')), filesep,'lz'])
    load(dataset, 'obj');
    cd (curdir);
    warning on
    
    % set arguments
    args = struct('channel', 'EDC_L',...
                  'tracer',obj.ampSettings.ChanNumb + 1,...
                  'preactivated', 100); %last channel is usually trigger channel
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end   
      
    Fs          = obj.ampSettings.SampRate;
    ms_sample   = ceil(1*Fs/1000);
    pre         = ceil(100*Fs/1000); % cut 100ms before the TMS
    post        = ceil(100*Fs/1000); % cut 100ms after the TMS
    minlatency  = ceil(15 * Fs/1000); % earliest for MEP
    maxlatency  = ceil(50 * Fs/1000); % latest for MEP
    
    channel_labels = obj.ampSettings.ChanNames;
    chan_pick = find(ismember(channel_labels, args.channel));
    signal = obj.dataEEGEMG(:,chan_pick);
    signal = padarray(signal, pre, 0);
    mso = obj.tms_settings.io_int;
    [MSO, switcher] = sort(mso);

    %% Cut MEP traces
    % calculate how many stimuli were applied
    Niterations = obj.tms_settings.mep_iterations;
    Nintensities = length(obj.tms_settings.io_range);
    NPeaks = Niterations * Nintensities;  
    % detect trigger onset
    tracer = obj.dataEEGEMG(:,args.tracer);   
    tracer = padarray(tracer, pre, 0);
    [pks,locs,w,p] = findpeaks(tracer, 1:length(tracer),...
                                'MinPeakDistance',Fs.*0.8,...
                                'NPeaks', NPeaks);
    if length(locs) ~= NPeaks
        throw(MException('PKS:NUM','Not enough triggers found'))
    end
    % cut epochs
    epoch = [];   
    for start = locs            
        a = start-pre;        
        b = start+post;           
        tmp = signal(a:b);
        tmp = tmp-mean(tmp);
        epoch = cat(2, epoch, tmp);
    end
    % estimate MEP parameters per trial

    pick = pre+minlatency:pre+maxlatency;
    Auc = nanmean(abs(epoch(pick,:)));
    Auc = reshape(Auc,Niterations,Nintensities);
    Auc = Auc(:,switcher);
    Lat = [];
    Vpp = [];
    Raw = [];
    fprintf('%s', '|')
    for trl = 1 : size(epoch,2)    

        response    = epoch(pick, trl);        
        [~, plat]  = max(response);
        [~, tlat]  = min(response);
        if plat < tlat
            Raw(:, trl) = -epoch(:, trl);
        else
            Raw(:, trl) = epoch(:, trl);
        end
        Lat(trl)    = mean([plat, tlat]);
        Vpp(trl)    = range(response);
        baseline    = epoch(1:pre - (5*ms_sample), trl);
        if max(abs(baseline)) > args.preactivated
            fprintf('%s', 'r')
            Vpp(trl) = NaN;
            Lat(trl) = NaN;
            Raw(:, trl) = NaN(size(epoch,1), 1);
        else
            fprintf('%s', '-')
        end                
        if mod(trl, Niterations)==0
            fprintf('%s', '|')
        end
    end
    
    Lat = reshape((10+(Lat/5)),Niterations,Nintensities);
    Lat = Lat(:,switcher);
    Vpp = reshape(Vpp,Niterations,Nintensities);
    Vpp = Vpp(:,switcher);
    raw = squeeze(nanmean(reshape(Raw,[], 10, 7),2));
    Raw = [];
    for trl = 1 : size(raw,2)
        Raw(:,trl) = downsample(raw(1:end-1,trl),Fs/1000);
    end
    Raw = Raw(:,switcher);
    %% fit sigmoidal
    rmt             = MSO./MSO(2);
    x               = repmat(rmt'*100, 10, 1);
    y               = reshape(Vpp', [], 1);    
    x(isnan(y))     = [];
    y(isnan(y))     = [];
 
    foo             = @(saturation, slope, threshold, x) ...
                        saturation./ ( 1 + exp(-slope*(x-threshold)));
    
    
    model   = fit(x, y, foo, ...
                  'StartPoint', [max(y) range(y)./length(x) mean(x)],...
                  'Lower', [0 0.1 80],...
                  'Upper', [max(y) 1 150]);
                  
    saturation  = model.saturation;
    slope       = model.slope;
    threshold   = model.threshold;
    parms       = [saturation, slope, threshold];
    xx          = [60:0.01:150]';    
    trace       = foo(saturation, slope, threshold, xx);

end
%%
