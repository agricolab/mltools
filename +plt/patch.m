function [hdl, b] = patch(y, threshold, varargin)

    args = struct('handle', [],...
                  'facecolor', [.8 .8 .8],...
                  'facealpha',0.2,...
                  'edgecolor','w',...
                  'linestyle','none',...
                  'baseline',0);
	
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2};
    end  
    if ~isempty(args.handle)
        axes(args.handle)
    else
        args.handle = figure();
    end
        
    yhat        = (y > threshold);
    [b, l, n]   = bwboundaries(yhat);    
    for nix = 1 : n
        px = find(l==nix)';        
        b{nix} = px;
        py = y(px)';
        px = [px, fliplr(px)];
        py = [py, ones(size(py)).*args.baseline];
        pz = ones(size(py));
        patch(px, py, pz, 'facecolor', args.facecolor,...
                          'facealpha', args.facealpha,...
                          'edgecolor', args.edgecolor,...
                          'linestyle', args.linestyle)
    end
    hdl = args.handle;
    
end