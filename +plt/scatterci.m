function H = scatter(X, varargin)
    args = struct('color', 'k',...
                  'marker', {'o'},...
                  'linestyle', 'none',...
                  'handle',[],...
                  'spread', 0.1,...
                  'markersize', 3,...
                  'markeredgecolor','k',...
                  'ci', [],...
                  'climcolor','k');
    for pair = reshape(varargin,2,[])
        args.(pair{1}) = pair{2};
    end
    
    shift = linspace(-args.spread, args.spread, size(X, 1));
    x = 1 : size(X,1);
    hold on
    
    if length(args.marker) ~= size(X,1) && length(args.marker) == 1
        clear tmp
        [tmp{1:size(X,1)}] = deal(args.marker);
        args.marker = tmp;
    end
    if length(args.color) ~= size(X,1) && length(args.color) == 1
        clear tmp
        [tmp{1:size(X,1)}] = deal(args.color);
        args.color = tmp;
    end
    
    if length(args.markeredgecolor) ~= size(X,1) && length(args.markeredgecolor) == 1
        clear tmp
        [tmp{1:size(X,1)}] = deal(args.markeredgecolor);
        args.markeredgecolor = tmp;
    end
    
    
    if length(args.markersize) ~= size(X,1) && length(args.markersize) == 1
        clear tmp
        [tmp{1:size(X,1)}] = deal(args.markersize);
        args.markersize = tmp;
    end
    for varix = 1 : size(X,2)
        xx = shift+varix;
        if ~isempty(args.ci)
            for idx = 1 : length(xx)
                px = [xx(idx), xx(idx)];
                py = [args.ci(idx, varix, 1), args.ci(idx, varix, 2)];
                plot(px, py,'color', args.climcolor, 'linewidth', 1)
                px = px +[-args.spread*0.1, args.spread*0.1];
                pu = [args.ci(idx, varix, 1), args.ci(idx, varix, 1)];
                pl = [args.ci(idx, varix, 2), args.ci(idx, varix, 2)];
                plot(px, pu,'color', args.climcolor, 'linewidth', 1)
                plot(px, pl,'color', args.climcolor, 'linewidth', 1)
            end
        end
        H = [];
        for idx = 1 : length(xx)
            h = plot(gca, xx(idx), X(idx, varix),...
                'marker',args.marker{idx},...
                'markerfacecolor',args.color{idx},...
                'markeredgecolor',args.markeredgecolor{idx},...
                'markersize', args.markersize{idx},...
                'linestyle',args.linestyle);        
            H(idx) = h;
        end
    end

end
    