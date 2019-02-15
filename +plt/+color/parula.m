function cmap = parula(position)
    cmap = plt.colormap.parula();
    if position < 0
        cmap = cmap(end+1+position,:);
    else
        cmap = cmap(position,:);
    end
end