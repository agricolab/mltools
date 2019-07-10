%% function [Vpp, Lat, Occ, Dur] = load_imep(dataset, varargin)
%
% Args
% ----  
% dataset:str
%   path to mat.file from tms measurement
% varargin:keywords
%   channel: 'EDC_L'   
%       defining the channel for which to calculate the MEP measures    
%   approach: <'lz', 'es', 'rg', 'simple'> 
%       lz: a replica of the original lukas ziegler approach
%       es: finds the longest peak above the threshold, normalizes it to
%           effect size compared to the baseline
%       rg: finds the longest peak and the longest trough, detects range
%           based on these
%       simple: take the range, subtract the range of the baseline
%   threshold: float
%      ignored for some approaches, defines the threshold for a Vpp to count as iMEP
%
% Returns
% -------
% Vpp:vector 
%   peak-to-peak amplitudes   
%   1 x n matrix with n trials
% Lat:vector 
%   latency estimate
%   1 x n matrix with n trials
% Occ:vector
%   whether iMEP was present or not
%   1 x n matrix with n trials
% Dur:vector
%   duration of the iMEP   
%   1 x n matrix with n trials
%
% tip
% ---
% requires the corresponding lz_TMS_v2-4.m in path

% changelog
% -------
% 21.03.19: switch workdir to have object code in path
% 19.03.19: created documentation


% written by rgugg 
function [Vpp, Lat, Occ, Dur] = load_imep(dataset, varargin)   

    % turn of warning, as we cant load all objects in mat
    warning off
    curdir = pwd;
    % we need lz_TMS_v3.m in the path to load the file
    % therefore i siwtch my working directory momentarily 
    % to where this are stored
    cd ([fileparts(mfilename('fullpath')), filesep,'lz'])
    load(dataset);
    cd (curdir);
    warning on

    args = struct('channel', 'EDC_L',...
                  'tracer', obj.ampSettings.ChanNumb + 1,...
                  'NPeaks', obj.tms_settings.imep_runs*obj.tms_settings.imep_iterations,...
                  'approach','lz',...
                  'threshold', 2);
               
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end   

    Fs  = obj.ampSettings.SampRate;
    pre = ceil(100*Fs/1000);
    post = ceil(100*Fs/1000);
    channel_labels = obj.ampSettings.ChanNames;
    if ischar(args.channel)
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
    tracer = obj.dataEEGEMG(:,args.tracer);
    tracer = padarray(tracer, pre, 0);
    
    %%
    
    [pks,locs,w,p] = findpeaks(tracer, 1:length(tracer),...
                                'MinPeakDistance',Fs.*0.8,...
                                'NPeaks', args.NPeaks);
    if length(locs) ~= args.NPeaks
        throw(MException('iMEP:NPeaks','Not enough peaks found'))
    end
    
    epoch = [];
    for start = locs            
        a = start-pre;        
        b = start+post;           
        tmp = signal(a:b);
        tmp = tmp-mean(tmp);
        tmp = abs(tmp);
        epoch = cat(2, epoch, tmp);
    end
    
    %%
    ms_samples = ceil(1 * Fs/1000);
    switch args.approach
        case 'lz'
            %disp('Executing rguggs implementation of lziegler approach');
            minimum_duration = ceil(5 * Fs/1000); %duration above 5ms consider as iMEP (Ziemann 1999)                
            minlatency = ceil(15 * Fs/1000);
            maxlatency = ceil(50 * Fs/1000);
            Vpp = [];
            Lat = [];
            Occ = [];
            Dur = [];
            for trix = 1 : size(epoch,2)        
                bl = epoch(1:pre-5*ms_samples, trix);
                post = epoch(pre+minlatency:pre+maxlatency, trix);
                bls = std(bl,0,1);
                blm = mean(bl,1);
                th = (blm + 1 * bls);
                response = (post > th);
                [~,L,n] = bwboundaries(response);
                tmp_dur = 0;
                onset = NaN;
                for nix = 1 : n
                    tmp = sum(L==nix);
                    if tmp > tmp_dur
                        tmp_dur = tmp;                
                        onset = find(L==nix,1);
                    end
                end                
                Dur(trix)   = tmp_dur * 1000/Fs;
                Occ(trix)   = tmp_dur>minimum_duration;
                vpp         = max(post) - min(post);
                vpp         = vpp - (max(bl)-min(bl));
                vpp         = vpp .* Dur(trix);
                vpp         = max([vpp, 0]);
                Vpp(trix)   = vpp;        
                Lat(trix)   = (minlatency+onset) * 1000/Fs;
            end
        
        case 'es' 
            %disp('Executing a mix between rguggs and lziegler approach');
            minlatency = ceil(15 * Fs/1000);
            maxlatency = ceil(50 * Fs/1000);
            response = epoch(pre+minlatency:pre+maxlatency,:);
            bl =  epoch(1:pre-5*ms_samples,:);
            bls = mean(std(bl,0,1));
            blm = mean(mean(bl,2));
            Vpp = NaN(1, size(epoch,2));
            Occ = zeros(1, size(epoch,2));
            Lat = NaN(1, size(epoch,2));
            Dur = NaN(1, size(epoch,2));
            th  = (blm + args.threshold*bls);
            for trix = 1 : size(epoch,2)
                [b,L,n] = bwboundaries(response(:,trix) > th);
                if isempty(n) || n == 0
                    continue;
                end
                ondur = 0;
                onset = NaN;
                for nix = 1 : n
                    tmp = sum(L==nix);
                    if (tmp > ondur)
                        ondur = tmp;                
                        onset = find(L==nix,1);
                    end
                end
                % substract 1 because bwboundaries overestimates by 1, and
                % can overshoot the vector length
                peak = max(response(onset:onset+ondur-1,trix));
                    
                Vpp(trix) = (peak-blm)./bls;
                Occ(trix) = (peak-blm) >= (args.threshold*bls);
                Dur(trix) = (ondur) * 1000/Fs;
                Lat(trix) = (minlatency + onset ) * 1000/Fs;
                
            end
        
        case 'rg'
            % runs a gaussian filter with 5ms width
            % selects the peak as the longest period above threshold 
            % selects the trough as the longest period below threshold after the peak occured 
            % Vpp as range between peak and trough
            %disp('Executing rguggs approach');
            minlatency = ceil(15 * Fs/1000);
            maxlatency = ceil(50 * Fs/1000);
            filtered = [];
            kernel = gausswin(25,1); kernel = kernel./sum(kernel);
            for trix = 1 : size(epoch,2)    
                filtered(:,trix) = conv(epoch(:,trix), kernel, 'same');
            end
            response = filtered(pre+minlatency:pre+maxlatency,:);
            bl =  epoch(1:pre-5*ms_samples,:);
            bls = mean(std(bl,0,1));
            blm = mean(mean(bl,2));
            Vpp = NaN(1, size(epoch,2));
            Occ = zeros(1, size(epoch,2));
            Lat = NaN(1, size(epoch,2));
            Dur = NaN(1, size(epoch,2));
            for trix = 1 : size(epoch,2)
                [b,L,n] = bwboundaries(response(:,trix) > (blm + (args.threshold * bls)));
                if isempty(n) || n == 0
                    continue;
                end
                ondur = 0;
                onset = NaN;
                for nix = 1 : n
                    tmp = sum(L==nix);
                    if (tmp > ondur)
                        ondur = tmp;                
                        onset = find(L==nix,1);
                    end
                end
                [b,L,n] = bwboundaries(response(onset:end,trix) < (blm+args.threshold*bls));
                if n==1 || n== 0 %no mep or no offtime
                    offset = length(response);
                    offdur = 1;
                else
                    offdur = 0;
                    offset = NaN;
                    for nix = 1 : n
                        tmp = sum(L==nix);
                        if (tmp > offdur)
                            offdur = tmp;                
                            offset = find(L==nix,1);
                        end
                    end
                end
                % substract 1 because bwboundaries overestimates by 1, and
                % can overshoot the vector length
                peak        = max(response(onset:onset+ondur-1,trix));
                trough      = min(response(offset:offset+offdur-1,trix));                
                Vpp(trix)   = peak-trough;
                Occ(trix)   = 1;
                Dur(trix)   = (offset- onset) * 1000/Fs;
                Lat(trix)   = (minlatency + onset ) * 1000/Fs;
                
            end
            
        case 'simple'
            minlatency = ceil(15 * Fs/1000);
            maxlatency = ceil(50 * Fs/1000);        
            response = epoch(pre+minlatency:pre+maxlatency,:);

            Vpp = NaN(1, size(epoch,2));
            Occ = zeros(1, size(epoch,2));
            Lat = NaN(1, size(epoch,2));
            Dur = NaN(1, size(epoch,2));
            for trix = 1 : size(epoch,2)                
                [peak, plat]    = max(response(:,trix));
                peak            = peak(1);
                plat            = plat(1);
                [trough, dur]        = min(response(plat:end,trix));
                dur             = dur(1);                
                trough          = trough(1);
                bpp             = range(epoch(1:pre-5*ms_samples, trix));
                vpp             = peak-trough;
                Vpp(trix)       = vpp;
                Occ(trix)       = vpp >= bpp;
                Dur(trix)       = dur * 1000/Fs;
                Lat(trix)       = (minlatency + plat + (dur/2)) * 1000/Fs;
                
            end
        
        otherwise
            throw(MException('iMEP:Approach','Approach "%s" is not implemented', args.approach));
        
            
        
    end
    
    
    
end
