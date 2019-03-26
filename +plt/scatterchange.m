function scatterchange(X)
    hold on
    shift = linspace(-.1, .1, size(X,1));
    for six = 1 : size(X,1)    
        plot([1+shift(six),2+shift(six),], X(six,:), 'color','k','linestyle','--')
    end
    
    for ix = 1 : 2
        plt.scatterbox(ix, X(:,ix),plt.color.regular(ix));
    end
    
end