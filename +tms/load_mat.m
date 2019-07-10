function [data, fs, chan_names, stim_onset, stim_code]  = load_mat(fname)

    % turn of warning, as we cant load all objects in mat
    warning off
    curdir = pwd;
    % we need lz_TMS_v3.m in the path to load the file
    % therefore i siwtch my working directory momentarily 
    % to where this are stored
    cd ([fileparts(mfilename('fullpath')), filesep,'lz'])
    load(fname);
    cd (curdir);
    warning on

    chan_names = obj.ampSettings.ChanNames;
    fs = obj.ampSettings.SampRate;
    data = obj.dataEEGEMG(:,1:end-1);
    stim_chan = obj.dataEEGEMG(:,end);
    stim_onset = find(diff(stim_chan)>0)+1;
    stim_code = stim_chan(stim_onset)*10;
