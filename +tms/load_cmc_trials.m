function [data, channel_labels, Fs] = load_cmc_trials(dataset, varargin)     
   
    % turn of warning, as we cant load all objects in mat
    warning off
    curdir = pwd;
    cd ([fileparts(mfilename('fullpath')), filesep,'lz'])
    load(dataset, 'obj');
    cd (curdir);
    warning on

    default_eeg_channels = {'Fp1', 'Fpz', 'Fp2', 'AF7', 'AF3', 'AF4',...
                            'AF8', 'F7', 'F5', 'F3', 'F1', 'Fz', 'F2',...
                            'F4', 'F6', 'F8', 'FT9', 'FT7', 'FT8',...
                            'FT10', 'FC5', 'FC3', 'FC1', 'FC2', 'FC4',...
                            'FC6', 'T7', 'C5', 'C3', 'C1', 'Cz', 'C2',...
                            'C4', 'C6', 'T8', 'CP5', 'CP3', 'CP1',...
                            'CPz', 'CP2', 'CP4', 'CP6', 'TP9', 'TP7',...
                            'TP8', 'TP10', 'P7', 'P5', 'P3', 'P1',...
                            'Pz', 'P2', 'P4', 'P6', 'P8', 'PO7',...
                            'PO3', 'POz', 'PO4', 'PO8', 'O1', 'Oz',...
                            'O2', 'Iz'};
                        
    args = struct('channel', 'EDC_L',...
                  'tracer',obj.ampSettings.ChanNumb + 1,...
                  'chan_names', [],...
                  'duration_in_ms', 1000,...
                  'NPeaks', 20); 
    args.eeg_channels = default_eeg_channels;
    
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end
    
    Fs          = obj.ampSettings.SampRate;
    pre         = ceil(args.duration_in_ms*Fs/1000); % cut 100ms before the TMS   
    channel_labels = obj.ampSettings.ChanNames;

    if isstring(args.channel) || ischar(args.channel)
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
    eeg_data = padarray(obj.dataEEGEMG, pre, 0);
    emg_data = padarray(signal, pre, 0);
    tracer = obj.dataEEGEMG(:,args.tracer);
    tracer = padarray(tracer, pre, 0);
    
    [pks,locs,w,p] = findpeaks(tracer, 1:length(tracer),...
                                'MinPeakDistance',Fs.*0.8,...
                                'NPeaks', args.NPeaks);
                                
    if length(locs) ~= args.NPeaks
        throw(MException('iMEP:NPeaks','Not enough peaks found'))
    end
    if any(min(diff(locs))<pre)
         throw(MException('iMEP:Duration',...
             ['TMS was applied faster than minimum duration.',...
              'Choose a value smaller than ', num2str(min(diff(locs)))]))
    end    
    
    data = [];
    for trigix = 1 : length(locs)
        trigger = locs(trigix);
        for cix = 1 : length(args.eeg_channels)
            idx = find(ismember(channel_labels, args.eeg_channels{cix}));
            if isempty(idx)
                tmp = NaN(pre,1);
            else
                tmp = eeg_data(trigger-pre+1:trigger, idx);
            end
            data(cix, :, trigix) = tmp;
        end
        tmp = emg_data(trigger-pre+1:trigger);
        data(cix+1, :, trigix) = tmp;
    end    
    channel_labels = [args.eeg_channels, "EMG"];
    