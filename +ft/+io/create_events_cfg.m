function [cfg] = create_events_cfg(filename, varargin)
    args = struct('eventtype', 'Feedback',...
                  'eventvalue', 1,...
                  'prestim', 1,...
                  'poststim', 2);
               
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end   
    
    cfg                         = [];
    cfg.trialfun                = 'ft_trialfun_general';
    cfg.dataset                 = filename;
    cfg.trialdef.eventtype      = args.eventtype;
    cfg.trialdef.eventvalue     = args.eventvalue;
    cfg.trialdef.prestim        = args.prestim;
    cfg.trialdef.poststim       = args.poststim;    
    cfg                         = ft_definetrial(cfg);
end