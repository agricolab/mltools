%% Repair artifacted channels
function interp = repair_channels(data, chan, threshold, max_iterations )
if nargin < 3, threshold = 200; end
if nargin < 4, max_iterations = 10; end

iterations      = 0;
while true
    iterations  = iterations+1;
    if iterations > max_iterations
        disp('too many iterations')
        break
    end

    bad_channel = {};
    for trl_idx = 1:length(data.trial)
        tmp = data.trial{trl_idx};
        idx = find(range(tmp,2) > threshold);
        if ~isempty(idx)
            bad_channel = cat(1, bad_channel, data.label{idx});
        end
    end   
    if isempty(bad_channel) 
        disp(['no bad channels anymore after ',num2str(iterations-1),' iterations'])
        break
    end
    cfg                 = [];
    cfg.method          = 'spline';
    cfg.badchannel      = unique(bad_channel);
    cfg.neighbours      = chan.neighbours; %find neighbours
    cfg.elec            = chan.elec;
    data              = ft_channelrepair(cfg, data); %reconstruct bad channels
end   
interp = data;

end
