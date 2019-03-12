function h = scatterbox(x, y, col)
    shift = linspace(-.1, .1, length(y));
    h = plot(gca, shift+x, y,...
            'marker','o', 'markerfacecolor',col, 'markeredgecolor',col,...
            'linestyle','none');
    ylim = get(gca, 'ylim');
    if ylim(1) > min(y)
        ylim(1) = floor(min(y));
    end
    if ylim(2) < max(y)
        ylim(2) = ceil(max(y));
    end
    fringe = floor(diff(ylim)*0.05);
    ylim = ylim + [-fringe, fringe];
    set(gca, 'ylim', ylim);
end
    