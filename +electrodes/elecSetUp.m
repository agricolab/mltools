addpath('C:\Program Files\MATLAB\R2010a\toolbox\biosig\biosig\t501_VisualizeCoupling');
% function for extracting 64 electrode set-up (network study with ActiCap system)
cfg.channels={'Fp1','AFF5h', 'AFF1h','F5','F3','F1','Fz','FFC5h','FFC3h','FFC1h','FC5','FC3','FC1','FTT7h','FCC5h','FCC3h','FCC1h','C5','C3','C1','Cz','TTP7h','CCP5h','CCP3h','CCP1h','TP9','CP5','CP3','CP1','P5','P3','P1'...
    'Fp2','AFF6h', 'AFF2h','F6','F4','F2','FFC6h','FFC4h','FFC2h','FC6','FC4','FC2','FCz','FTT8h','FCC6h','FCC4h','FCC2h','C6','C4','C2','TTP8h','CCP6h','CCP4h','CCP2h','TP10','CP6','CP4','CP2','CPz','P6','P4','P2'}';
file='10-5-System_Mastoids_EGI129.csd';
importfile(file);
for k=1:length(cfg.channels)
    for i=1:length(data)
        if strcmp(cfg.channels(k),textdata{i})
            X(k)=data(i,4);
            Y(k)=data(i,5);
            Z(k)=data(i,6);
        end
    end
end
X=X';
Y=Y';
Z=Z';
clear data textdata
%for xyz=1:length(cfg.channels)
for c=1:3
    if c==1
        for r=1:length(cfg.channels)
            locs_2D(r,c)=X(r);
        end
    elseif c==2
        for r=1:length(cfg.channels)
            locs_2D(r,c)=Y(r);
        end
    elseif c==3
        for r=1:length(cfg.channels)
            locs_2D(r,c)=Z(r);
        end
    end
end    
%end
%pars.rot=45;
loc_phys=mk_sensors_plane(locs_2D);