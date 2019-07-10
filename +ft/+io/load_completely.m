function [data] = load_completely(filename)

    cfg                         = [];
    cfg.trialfun                = 'ft_trialfun_general';
    cfg.dataset                 = filename;
    cfg.trialdef.triallength    = Inf;    
    cfg                         = ft_definetrial(cfg);    
    data                        = ft_preprocessing(cfg);
    
end