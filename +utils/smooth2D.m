% output = smooth2D(input,window,mode,padding)
% window should be specified as [dim1,dim2]
% mode 1: boxcar
% mode 2: gauss
% mode 3: parzen
% mode 4: hanning
% mode 7: gauss/exp
function output = smooth2D(input,window,mode,paddingy,paddingx)
    
    if nargin <3, mode = 1; end
    if nargin <4, paddingy = 'replicate'; end
    if nargin <5, paddingx = 'circular'; end
    if mode == 1, 
        filt = ones(window(1),1)*ones(window(2),1)';        
        filt = filt./numel(filt);
    elseif mode == 2, 
       filt =  gausswin(window(1))*gausswin(window(2))';
    elseif mode == 3, 
       filt =  parzenwin(window(1))*parzenwin(window(2))';
    elseif mode == 4,
       filt =  hanning(window(1))*hanning(window(2))';    
    elseif mode == 5,
       filt =  boxcar(window(1))*parzenwin(window(2))'./window(1);    
    elseif mode == 6,
       filt =  boxcar(window(1))*parzenwin(window(2))'./window(1);
    elseif mode ==7,
        filt =  gausswin(window(1))*exp(1:window(2));
    end
    filt    = filt./sum(sum(filt));
    if ~strcmp(paddingx,'none') || ~strcmp(paddingy,'none') ,
        %output  = convn(padarray(input,window./2,padding),filt,'same');
        %output  = output(1+(window(1)./2):end-window(1)/2,1+(window(2)./2):end-window(2)/2);
        filt    = filt./sum(sum(filt));
        tmp     = padarray(padarray(input,[0,window(2)./2],paddingx),[window(1)./2,0],paddingy);
        output  = convn(tmp,filt,'same');
        output  = output(1+(window(1)./2):end-window(1)/2,1+(window(2)./2):end-window(2)/2);
    else
        output  = convn(input,filt,'same');
    end
    

end