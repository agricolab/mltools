function med = median(alpha,dim)
%
% med = circ.median(alpha)
%   Computes the median direction for circular data.
%
%   Input:
%     alpha	sample of angles in radians
%     [dim  compute along this dimension, default is 1, must 
%           be either 1 or 2 for circ.median]
%
%   Output:
%     mu		median direction
%
%   circ.median can be slow for large datasets
%
% Update 2012
% PHB 3/19/2009
%
% References:
%   Biostatistical Analysis, J. H. Zar (26.6)
%
% Circular Statistics Toolbox for Matlab

% By Philipp Berens, 2009
% berens@tuebingen.mpg.de - www.kyb.mpg.de/~berens/circStat.html

if nargin < 2
  dim = 1;
end

M = size(alpha);
med = NaN(M(3-dim),1);
for i=1:M(3-dim)
  if dim == 2
    beta = alpha(i,:)';
  elseif dim ==1
    beta = alpha(:,i);
  else
    error('circ.median only works along first two dimensions')
  end
  
  beta = mod(beta,2*pi);
  n = size(beta,1);

  dd = circ.dist2(beta,beta);
  m1 = sum(dd>=0,1);
  m2 = sum(dd<=0,1);

  dm = abs(m1-m2);
  if mod(n,2)==1
    [m idx] = min(dm);
  else
    m = min(dm);
    idx = find(dm==m,2);
  end

  if m > 1
    warning('Ties detected.') %#ok<WNTAG>
  end

  md = circ.mean(beta(idx));

  if abs(circ.dist(circ.mean(beta),md)) > abs(circ.dist(circ.mean(beta),md+pi))
    md = mod(md+pi,2*pi);
  end
  
  med(i) = md;
end

if dim == 2
  med = med';
end