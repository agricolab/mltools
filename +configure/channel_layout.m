function chan = channel_layout(chan, folder)
    elec_filename   = [folder.ft,filesep,'template',filesep,'electrode', filesep, 'standard_1005.elc'];
    elec            = ft_convert_units(ft_read_sens(elec_filename),'cm');
    f               = [];

    for k = 1 : length(chan.eeg)
        f = [f, find(strcmpi(elec.label,chan.labels{k}))];
    end
    [~, chan.shuffle] = sort(f);
    elec.chanpos    = elec.chanpos(f,:);
    elec.elecpos    = elec.elecpos(f,:);
    elec.label      = elec.label(f,:);
    chan.elec       = elec;

    cfg             = [];
    cfg.layout      = 'EEG1005.lay';
    cfg.channel     = chan.eeg;
    chan.layout     = ft_prepare_layout(cfg);
    ft_layoutplot(chan)
    % sort channel positions, becuase the order of channels in chan.eeg !=
    % order of channels in chan.layout.label
    % useful for later low-level plotting with show_field
    for chan_idx = 1 : length(chan.eeg)
        posix = find(ismember(chan.layout.label, chan.eeg{chan_idx}));
        chan.pos(chan_idx,:) = chan.layout.pos(posix,:);
    end
    % create neighbours for repairing artifacted or missing channels
    cfg                 = [];
    cfg.method          = 'triangulation';
    cfg.layout          = chan.layout;
    cfg.channels        = 'EEG';
    chan.neighbours     = ft_prepare_neighbours(cfg);
    close all   
    
end