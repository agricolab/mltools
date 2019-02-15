function kickstart(folder, pull)

if nargin <2, pull = true; end

if pull
    ft.update(folder)
end

addpath(folder)
ft_defaults;
