function cmap = regular(position, varargin)
    cmap = [0.00,0.45,0.74;...
            0.85,0.33,0.10;...
            0.93,0.69,0.13;...
            0.49,0.18,0.56;...
            0.47,0.67,0.19;...
            0.30,0.75,0.93;...
            0.64,0.08,0.18;...
            ];
    if ischar(position)
        map = {'blue','red','yellow','violett','green','lightblue','darkred'};
        cmap = cmap(ismember(map, position),:);
    elseif isnumeric(position)
        cmap = cmap(position,:);
    end
    args = struct('output', 'mat');
    for pair = reshape(varargin,2,[])
        args.(pair{1}) = pair{2};
    end
    
    if strcmpi(args.output, 'cellarray') || strcmpi(args.output, 'ca')
        for ix = 1 : size(cmap,1)
            tmp{ix} = cmap(ix,:);
        end
        cmap = tmp;
    end
end
