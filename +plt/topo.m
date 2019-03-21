% makes plots of potentials on head
% usage showfield(z,loc,scale, markersize,resolution, cbar) ;
%
% input:
%  z  values of field/potential to be shown.
%  loc   matrix containing 2D coordinates of channels in second and third column 
%  scale sets the scale of the color map. Either a 1x2 vector
%            corresponding to minimum and a maximum or just a number (say x) 
%            then the scale is from [-x x]. The default is 
%            {=[ -max(abs(z)) max(abs(z)) ]}
%  markersize is the size of the markers for the original channels
%  resolution sets the resolution, {100}
%  cbar=1 draws colorbar, otherwiseno colorbar is not shown. {1}
%   rewritten by R.Bauer & M.Vukelic for CIN AG NPT 22.06.2011
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function topo(z,loc,varargin) 

args = struct('scale', [-max(max(abs(z))),max(max(abs(z)))],...
              'threshold', Inf,...
              'markersize', 12,...
              'resolution', 200,...
              'interpol', 0,...
              'cbar',0,...
              'hilite',0,...
              'interpolwindow', mean(sqrt(sum((loc).^2,2))),...
              'tit','');
          
args.loc = loc;          
for pair = reshape(varargin, 2, [])
    args.(pair{1}) = pair{2}; 
end              
if any(args.hilite==0)
    args.hi_idx = zeros(size(loc,1),1);
else
    args.hi_idx = zeros(size(loc,1),1);
    args.hi_idx(hilite) = true;
end
if length(args.scale) == 1
    args.scale = [min([args.scale, -args.scale]) max([args.scale, -args.scale])];
end

[~,m] = size(args.loc);
if m == 2
  x = args.loc(:,1);
  y = args.loc(:,2);
else
  x = args.loc(:,2);
  y = args.loc(:,3);
end

xlin    = linspace(1.4*min(x),1.4*max(x),args.resolution);
ylin    = linspace(1.4*min(y),1.4*max(y),args.resolution);
[X,Y]   = meshgrid(xlin,ylin);
Z       = griddata(x,y,z,X,Y,'nearest');
HI      = griddata(x,y,args.hi_idx,X,Y,'nearest');
a       = fix(args.resolution * args.interpolwindow); 
a       = a+mod(a,2);
if args.interpol  
    kernel = gausswin(a)*gausswin(a)';
    kernel = kernel./sum(sum(kernel));    
    Z = convn(Z,kernel,'same');   
end

% Take data within head
rmax            = 1.02*max(sqrt(x.^2+y.^2));
mask            = (sqrt(X.^2+Y.^2) <= rmax);
Z(mask == 0)    = NaN;
HI(mask == 0)   = NaN;

% plot stuff
cla  
surface(X,Y,zeros(size(Z)),Z,'edgecolor','none');shading interp;
hold on
if any(any(abs(Z) >= args.threshold))
    contour(X,Y,abs(Z) >= args.threshold, 1,...
            'color',[.1 .1 .1]+0,'linewidth', 2);
end
if any(args.hi_idx)
    contour(X,Y,HI > 0, 1,...
            'color', [1 0 0]+0, 'linewidth', 2, 'linestyle', '-');
end
hold off
caxis(args.scale);
hold on;
plot(x, y, '.k','markersize', args.markersize);


%meanx=mean(loc(:,2)*.85+.45);
%meany=mean(loc(:,3)*.85+.45);
scalx=1;
drawhead(0,.0,rmax,scalx);
set(gca,'visible','off');

axis([-1.2*rmax 1.2*rmax -1.0*rmax 1.4*rmax]);
axis equal;
if args.cbar==1
  h = colorbar;set(h,'fontweight','bold')
end

annotation('textbox','position',[0 0 1 1],'edgecolor','None','HorizontalAlignment','center','string',args.tit);

end


function drawhead(x,y,size,scalx)

cirx=(x+scalx*size*cos((1:1000)*2*pi/1000) )';ciry=(y+size*sin((1:1000)*2*pi/1000))';

plot(cirx, ciry, 'k', 'linewidth', 2);
hold on;

ndiff = 20;
plot( [x  cirx(250-ndiff) ],[y+1.1*size ciry(250-ndiff)],'k','linewidth',1);
plot( [x  cirx(250+ndiff) ],[y+1.1*size ciry(250+ndiff)],'k','linewidth',1);

end