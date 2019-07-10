function [Vpp, Lat, Raw, parms] = load_mep(dataset, varargin)     
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
    
    if isstring(args.channel)
        chan_pick = find(ismember(channel_labels, args.channel));
        if isempty(chan_pick)
            throw (MException('iMEP:CHAN', ...
            'Channel not found. Available: %s ', strjoin(channel_labels,', ')))     
        end
    elseif iscell(args.channel)
        if length(args.channel) >2
            throw (MException('iMEP:CHAN', "You can select at most 2 channels"))
        end
        chan_pick = NaN(length(args.channel),1);
        for cix = 1 : length(args.channel)
            cp = find(ismember(channel_labels, args.channel{cix}));            
            if isempty(cp)
                throw (MException('iMEP:CHAN', ...
                'Channel %s not found. Available: %s ', ...
                 args.channel{cix}, strjoin(channel_labels,', ')))     
            end
            chan_pick(cix) = cp;
        end        
    end
    
    
    signal = obj.dataEEGEMG(:,chan_pick);
    %bipolarize if necessary
    if size(signal,2) > 1 
        signal = diff(signal,[],2);
    end
    
    signal = padarray(signal, pre, 0);
   
    %% Cut MEP traces
    % calculate how many stimuli were applied
    % detect trigger onset
    tracer = obj.dataEEGEMG(:,args.tracer);   
    tracer = padarray(tracer, pre, 0);
    if max(tracer) < max(-tracer)
        tracer = -tracer;
    end
    
    [pks,locs,w,p] = findpeaks(tracer, 1:length(tracer),...
                                'MinPeakDistance',Fs.*0.8,...
                                'MinPeakHeight',quantile(tracer, .9));
    
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
    end
     fprintf('%s', '|')
end
%%
