function [] = query_events(filename)
    cfg                         = [];
    cfg.trialfun                = 'ft_trialfun_general';
    cfg.dataset                 = filename;
    cfg.trialdef.eventtype      = '?';
    cfg                         = ft_definetrial(cfg);
end