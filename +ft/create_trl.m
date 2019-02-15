function trl_structure = create_trl(trl, varargin)
    post = ceil(mean(diff(trl(:,1))));
    pre = ceil(post/2);
    args = struct('pre', pre, 'post', post, 'index', 1);
    for pair = reshape(varargin, 2, [])
        args.(pair{1}) = pair{2}; 
    end
    trl_structure = cat(2, trl(:,args.index)-args.pre,...
                           trl(:,args.index)+args.post, ...
                           ones(size(trl,1),1).*args.pre,...
                           ones(size(trl,1),1)*args.index);
end