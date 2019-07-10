%{
                           lz_TMS_v5.m  -  description
                               -------------------

    Facility             : Functional and Restorative Neurosurgery
                             Neurosurgical University Hospital
                                 Eberhard Karls University
    Author               : Lukas Ziegler adapted by Ali S
    Email                : 
    Created on           : 29/06/2017
    Description          : This is a full-fledged function to control various TMS stimulation techniques
                           Possible Determinations:
                            - Hotspot
                            - Resting Motor Threshold
                            - Active Motor Threshold
                            - Optimal Inter-Pulse-Interval for SICF
                            - Optimal Inter-Pulse-Interval for LICF
                            - Maximal Voluntary Contraction force
                            - Latencies to coil orientation (AP-LM; Hamada 2012)
                            - Input Output Curve
                            - CorticoSpinalExcitability and TEP
                            - CSE Mapping
                            - iMEP or MEP measurement during contraction
                            - iMEP with different coil directionsR_EE
                            - Inter-Pulse-Interval for iMEP or MEP measurement during contraction
                            - General setting functions
    Additional info      : If hardware is changed one has to run check_pins
    to see if the LPT pins changed, also check address of LPT and com ports
%}

classdef lz_TMS_v5 < handle
    
    properties
        marker_pin      = [1, 5]; % Pin to only add marker to buffer
        stim_pin        = 3;      % Pin to stimulate and add marker to buffer
        lpt_ad          = 'LPT1'; % Parallel port to use for stimulation
        ptb_screen      = 1;      % Number of external screen for PTB window
        dataEEGEMG      = [];     % Data will be stored here
        dataEEGEMG_cut  = [];     % If powerpack problems first data will be saved here
        MEP             = [];     % MEP infos
        mvc             = [];     % Maximum voluntary contraction force
        r_EEG           = [];     % Resting EEG
        a_EMG           = [];     % active EMG/EEG
        MEPepochs       = [];     % Plotting variable
        time            = [];
        objMag          %controller for MagVenture
        objBuf          %controller of Buffer
        objLoc          %controller of localite
        objLPT          %controller of parallel port
        PTB             %controller of psychtoolbox
        tms_settings    %TMS stimulation settings
        dataSub         %information about subject
        directories     %Save directories
        ampSettings     %Settings for buffer
        audio           %Audio feedback
        
    end
    
    methods(Access = public)
        %% Basic functions for TMS measurement setup        
        function hotSpot(obj)
            % Detection of optimal position for activating target muscle
            % The function will ask for stimulator intensity and 
            % apply # = tms_settings.hotspot_nb_stim stimuli
            % Each stimulus has to be triggered manually; Intensity can be
            % adjusted via the MagVenture settings
            clc
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            rep    = 1;
            finish = 1;
            amp = input('Choose amplitude: ');
            while finish
                while rep<=obj.tms_settings.hotspot_nb_stim
                    if( obj.objMag.spObject.BytesAvailable~=0)
                        switch obj.objMag.spObject.BytesAvailable
                            case 8
                                clc
                                fprintf('Repetition: %d \nCurrent amplitude: %d \n',rep,amp)
                                mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                                if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                    %stimulate with specified intensity if target muscle at rest and get buffer data
                                    [tmp,~] = obj.stimTMS_rest(obj,amp); 
                                    if(isempty(tmp))
                                        disp('Power pack empty!!!')
                                        keyboard
                                    else
                                        obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                        clear tmp
                                    end
                                    % Analyze buffer Data
                                    if(~isempty(obj.dataEEGEMG))
                                        %take last second of marker channel
                                        if size(obj.dataEEGEMG,1) > 1*obj.ampSettings.SampRate + 1
                                            trig         = obj.dataEEGEMG(end-(1*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)';
                                        else
                                            trig         = obj.dataEEGEMG(:,obj.ampSettings.ChanNumb+1)'; %last milliseconds of marker channel
                                        end
                                        stimTime = find(trig, 1, 'last') %Last entry in marker channel
                                        %stimTime     = 500; 
                                        if(stimTime > 40 && ~isnan(stimTime))% && length(trig) > stimTime + obj.tms_settings.mep_end )
                                            data = obj.filterData(obj, obj.tms_settings.addNotchFilt);  %take target muscle and detrend
                                            obj.getMEPinf(obj,data,stimTime,1,rep, obj.tms_settings.threshold_rmt);              %analyze data for possible MEP
                                            obj.plotMEP(obj,data,stimTime,1,rep, gca);                  %plot current MEP
                                            obj.objLoc.sendMEP(obj.MEP.maxAmp(1,rep)+obj.MEP.minAmp(1,rep),obj.MEP.maxAmp(1,rep), obj.MEP.delay(1,rep));
                                        else
                                            keyboard %sth went wron try to figure out why and continue
                                            obj.MEP.minAmp(1,rep)  = 0;
                                            obj.MEP.maxAmp(1,rep)  = 0;
                                            obj.MEP.delay(1,rep)   = 0;
                                        end
                                        
                                    end
                                    if(obj.objMag.spObject.BytesAvailable~=0)
                                        obj.objMag.flushData
                                    end
                                    obj.objMag.getStatus()
                                    rep = rep + 1;
                                elseif strcmpi(mag_fbk,'int_change') %intensity changed
                                    clc
                                    amp = input('Choose new stimulation intensity: ');
                                    clc
                                    obj.objMag.changeAmp(0,0);
                                    fprintf('Current stimulation intensity: %d \n',amp)
                                end
                            case 16
                                messageMag = obj.objMag.getData()';
                                obj.objLoc.sendData(messageMag);
                                magSettings = dec2bin(messageMag(6));
                                if(magSettings(4))
                                    keyboard
                                end
                            case 24
                                messageMag = obj.objMag.getData()';
                                obj.objLoc.sendData(messageMag);
                            otherwise
                                messageMag = obj.objMag.getData()';
                                messageMag = messageMag(end-7:end);
                                obj.objLoc.sendData(messageMag);
                        end                        
                    end
                end
                if(~isempty(obj.dataEEGEMG))  %~quit || 
                    % Sort MEPs according to PTP
                    [~, sortMEPs]  = sort(obj.MEP.peakToPeak);
                    clear tmp1 tmp2
                    figure
                    if(sum(sortMEPs) > 0)
                        var       = 0;
                        for MEPnumb = 1:size(sortMEPs, 2)
                            % Set x
                            x_start = -50;
                            x_end = obj.tms_settings.mep_end + 10;
                            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
                            % Set subplots
                            if(MEPnumb/9==round((MEPnumb/9)))
                                var          = MEPnumb-1;
                                figure
                            end
                            subplot(3,3,MEPnumb-var)
                            % Plot data
                            data_tmp = squeeze(obj.MEPepochs(1,sortMEPs(1,MEPnumb),:));
                            plot(x,data_tmp,'k', 'LineWidth', 2)
                            clear data_tmp
                            hold on
                            % Plot ptp boundary
                            plot([obj.MEP.delayMin(1,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMin(1,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                            plot([obj.MEP.delayMax(1,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMax(1,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                            hold off
                            % Figure parameters
                            y_range = [-obj.MEP.minAmp(1,sortMEPs(1,MEPnumb)) obj.MEP.maxAmp(1,sortMEPs(1,MEPnumb))];
                            if min(y_range) == 0; y_range = [-100 100]; end
                            ylim([min(y_range) max(y_range)])
                            clear y_range
                            xlim([x_start x_end])
                            title(sprintf('MEP number: %d\n PtP: %d\nMaxPeak: %d, Latency: %d',sortMEPs(1,MEPnumb), ...
                                round(obj.MEP.peakToPeak(sortMEPs(1,MEPnumb))), round(obj.MEP.maxAmp(sortMEPs(1,MEPnumb))), ...
                                round(obj.MEP.delay(sortMEPs(1,MEPnumb)))))
                        end
                        figure
                        annotation('textbox', [0.28,0.52,0.1,0.1],...
                            'String', {['Highest MEP:'] ...
                            ['Number: ' num2str(sortMEPs(end))] ...
                            ['PeakToPeak: ' num2str(round(obj.MEP.peakToPeak(sortMEPs(end)))) ' \muV'] ...
                            ['MaxAmp: '  num2str(round(obj.MEP.maxAmp(sortMEPs(end)))) ' \muV'] ...
                            ['MinAmp: '  num2str(-round(obj.MEP.minAmp(sortMEPs(end)))) ' \muV'] ...
                            ['Latency: ' num2str(round(obj.MEP.delay(sortMEPs(end)))) ' \muV'] ...
                            }, 'FontSize', 14);
                    else
                        title('No MEPs detected', 'Fontsize', 16)
                    end
                    clear data
                    obj.MEPepochs = []; obj.MEP = []; %keeps file small
                    disp('Saving...')
                    if ~isdir(obj.directories.hs); mkdir(obj.directories.hs); end
                    save([obj.directories.hs 'hotspot_' num2str(rep)], 'obj', '-v7.3')
                    disp('Saved')
                    obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
                end
                [finish, rep] = obj.add_stim(obj);
            end
            obj.objMag.turnOnOff('off');
        end
        
        function get_ipi(obj)
            % This function applies 10 paired pulse Stimuli of selected IPI
            % The IPIs are stated by tms_settings.ipi
            % For application a MagVenture protocol has to be initiated
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); % change magventure to 0%
            obj.objMag.flushData()
            obj.dataEEGEMG = []; % make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.pp 'ipi_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.pp 'ipi_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            ipi_n = 1;
            set_back_int = 0;
            amp = floor(1.1*obj.tms_settings.rmt_int);
            obj.tms_settings.ipi = obj.tms_settings.ipi(randperm(numel(obj.tms_settings.ipi))); %random order of IPIs
            for j = 1:numel(obj.tms_settings.ipi) %show order of ISIs
                fprintf('ISI %d: %1.1d \n', j, obj.tms_settings.ipi(j))
            end
            if strcmpi(input('Continue (Enter/n): ','s'),'n') %Continue after protocol is set on Magventure
                finish=0;
            end
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    for rep = 1:10  %apply 10 stimuli for each IPI
                                        if rep ~= 1 
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.tms_settings.ipi(ipi_n))
                                        %stimulate with specified intensity if target muscle at rest and get buffer data
                                        [tmp,isiTic] = obj.stimTMS_rest(obj,amp);
                                        if(isempty(tmp))
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            stimTime     = stimTime + floor(0.001*obj.tms_settings.ipi(ipi_n)*obj.ampSettings.SampRate); %so that the MEP triggered by the S2 is analyzed
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,ipi_n,rep, obj.tms_settings.threshold_rmt);
                                                obj.plotMEP(obj, data, stimTime, ipi_n, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.maxAmp(ipi_n,rep)+obj.MEP.minAmp(ipi_n,rep),obj.MEP.maxAmp(ipi_n,rep), obj.MEP.delay(ipi_n,rep));
                                            else
                                                obj.MEP.minAmp(ipi_n,rep)  = 0;
                                                obj.MEP.maxAmp(ipi_n,rep)  = 0;
                                                obj.MEP.delay(ipi_n,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    cla(h2);
                                    boxplot(obj.MEP.peakToPeak(1:ipi_n,:)', obj.tms_settings.ipi(1:ipi_n))
                                    xlabel(h2, 'IPI [ms]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Opt IPI'; [num2str(ipi_n) ' out of ' num2str(numel(obj.tms_settings.ipi))]}, 'FontSize', 12)
                                    drawnow
                                    if(ipi_n<length(obj.tms_settings.ipi))
                                        if set_back_int
                                            ipi_n = ipi_n - 1;
                                            set_back_int = 0;
                                        end
                                        ipi_n = ipi_n + 1;
                                        obj.pauseFunc(obj, -1, obj.tms_settings.ipi(ipi_n));
                                    else
                                        finish = 0;
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            
            % Plot the mean MEPs
            figure
            plot(obj.tms_settings.ipi,nanmean(obj.MEP.peakToPeak,2),'+')
            title('IPI MEPs', 'FontSize', 16)
            xlabel('ISI [ms]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
            
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.pp); mkdir(obj.directories.pp); end
            save([obj.directories.pp 'ipi_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function get_idi(obj)
            % This function applies 10 paired pulse Stimuli of selected IDI
            % The IDIs are stated by tms_settings.idi
            % The interval btw stimuli is set by Matlab, therefore short
            % intervals are NOT possible
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.pp 'idi_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.pp 'idi_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            run = 1;
            set_back_int = 0;
            amp = floor(1.1*obj.tms_settings.rmt_int);
            obj.tms_settings.idi = obj.tms_settings.idi(randperm(numel(obj.tms_settings.idi))); %random order of IPIs
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    % Single Pulse
                                    if obj.tms_settings.idi(run) == 0
                                        for rep = 1:10  %apply 10 SP stimuli
                                            if rep ~= 1 
                                                %ISI of 5 +- 1.25 s
                                                while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                            end
                                            fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.tms_settings.idi(run))
                                            %stimulate with specified intensity if target muscle at rest and get buffer data
                                            [tmp,isiTic] = obj.stimTMS_rest(obj,amp);
                                            if(isempty(tmp))
                                                disp('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.check_buffer()
                                                    set_back_int = 1;
                                                else 
                                                    keyboard
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, obj.tms_settings.threshold_rmt);
                                                    obj.plotMEP(obj, data, stimTime, run, rep, h1)
                                                    obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                                else
                                                    obj.MEP.minAmp(run,rep)  = 0;
                                                    obj.MEP.maxAmp(run,rep)  = 0;
                                                    obj.MEP.delay(run,rep)   = 0;
                                                    obj.objLoc.sendMEP(0,0,0);
                                                end
                                            end
                                        end
                                    else % Paired Pulse
                                        for rep = 1:10  %apply 10 PP stimuli
                                            if rep ~= 1 
                                                %ISI of 5 +- 1.25 s
                                                while toc(isiTic) < 4.5-1.25+2.5*rand(1), end %500ms for MagVen to change int
                                            end
                                            fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.tms_settings.idi(run))
                                            %paire-pulse stimulation with specified amp and idi if target muscle at rest and get buffer data
                                            tmp = obj.stimPP_rest(obj,amp,obj.tms_settings.idi(run));
                                            isiTic = tic; %Set timer for ISI
                                            if(isempty(tmp))
                                                disp('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.check_buffer()
                                                    set_back_int = 1;
                                                else
                                                    keyboard
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                                clear trig
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, obj.tms_settings.threshold_rmt);
                                                    obj.plotMEP(obj, data, stimTime, run, rep, h1)
                                                    obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                                else
                                                    obj.MEP.minAmp(run,rep)  = 0;
                                                    obj.MEP.maxAmp(run,rep)  = 0;
                                                    obj.MEP.delay(run,rep)   = 0;
                                                    obj.objLoc.sendMEP(0,0,0);
                                                end
                                            end
                                        end
                                    end
                                    cla(h2);
                                    boxplot(obj.MEP.peakToPeak(1:run,:)', obj.tms_settings.idi(1:run))
                                    xlabel(h2, 'IPI [ms]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Opt IPI'; [num2str(run) ' out of ' num2str(numel(obj.tms_settings.idi))]}, 'FontSize', 12)
                                    drawnow
                                    if(run<length(obj.tms_settings.idi))
                                        if set_back_int
                                            run = run - 1;
                                            set_back_int = 0;
                                        end
                                        run = run + 1;
                                        obj.pauseFunc(obj, -1, obj.tms_settings.idi(run));
                                    else
                                        finish = 0;
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            
            % Plot the mean MEPs
            figure
            plot(obj.tms_settings.idi,nanmean(obj.MEP.peakToPeak,2),'+')
            title('IPI MEPs', 'FontSize', 16)
            xlabel('ISI [ms]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
            
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.pp); mkdir(obj.directories.pp); end
            save([obj.directories.pp 'idi_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function rEEG(obj)
            % This function records 3 minuts of resting EEG and EMG
            
            obj.check_buffer() %Check if buffer is still recording
%             obj.objMag.turnOnOff('off');
%             obj.objMag.flushData();
            obj.dataEEGEMG  = [];
            obj.r_EEG       = [];
            time            = obj.time;
%             pre_contr = nan(1,10);
            % Preperation time I
            obj.PTB.displayMessage('Resting EEG');
%             play(obj.audio.prep);
            pause(2)
            obj.clear_buffer(obj)
            % Preperation time II - gives time to be completly relax
            obj.PTB.displayMessage('Relax');
            play(obj.audio.relax)
            pause(1)
%             play(obj.audio.contract);
            step_rise=1;                % counts the number of measurement steps
            obj.clear_buffer(obj)       % empty the buffer matrix
            step_tic = tic;             % timer for 200ms steps
            run_tic = tic;              % timer for measure part (pre/post)
            obj.PTB.drawCross()
            obj.add_marker(obj,1)       % adds marker to buffer
            while toc(run_tic) < 180    % Measure resting EEG for 180s
                if toc(step_tic) >= 0.2 % take last 200ms
                    tmp             = double(obj.objBuf.read_data());   % get data
                    obj.r_EEG       = cat(1,obj.r_EEG, tmp );           % append data
                    tmp             = tmp/10;     
                    obj.dataEEGEMG  = cat(1,obj.dataEEGEMG, tmp);       %append data
                    
%                     % make sure data is 200 ms
%                     if size(tmp,1) > 0.2*obj.ampSettings.SampRate
%                         tmp = tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
%                     else
%                         tmp = tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
%                     end
%                     tmp = detrend(tmp);                 % detrend data
%                     pre_contr(step_rise) = rms(tmp);    % measure of current contraction force
%                     tmp = nanmean(pre_contr);           % measure of total MVC
%                     %visual fdbk of contraction force
%                     % (current contraction force, MVC, threshold,
%                     % threshold_range,zoom_factor)
%                     obj.PTB.m_contr(pre_contr(step_rise), tmp, tmp,obj.tms_settings.mvc_range,0.8) 
                    clear tmp
                    step_rise = step_rise + 1; %next 200ms
                    step_tic = tic;  %reset step timer
                end
            end
            
%             pause(180)                  %3 minutes of cross fixation
            obj.add_marker(obj,2)       % adds marker to buffer
%             obj.dataEEGEMG = double(obj.objBuf.read_data());   % get data
%             while toc(run_tic) < 180    % Measure resting EEG for 180s
%                 if toc(step_tic) >= 0.2 % take last 200ms
%                     tmp             = double(obj.objBuf.read_data());   % get data
%                     obj.r_EEG       = cat(1,obj.r_EEG, tmp );           % append data
%                     tmp             = tmp/10;     
%                     obj.dataEEGEMG  = cat(1,obj.dataEEGEMG, tmp);       % append data
                    
                    % make sure data is 200 ms
%                     if size(tmp,1) > 0.2*obj.ampSettings.SampRate
%                         tmp = tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
%                     else
%                         tmp = tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
%                     end
%                     tmp = detrend(tmp);                 % detrend data
%                     pre_contr(step_rise) = rms(tmp);    % measure of current contraction force
%                     tmp = nanmean(pre_contr);           % measure of total MVC
                    % visual fdbk of contraction force
                    % (current contraction force, MVC, threshold,
                    % threshold_range,zoom_factor)
%                     obj.PTB.m_contr(pre_contr(step_rise), tmp, tmp,obj.tms_settings.mvc_range,0.8) 
%                     clear tmp
%                     step_rise = step_rise + 1; %next 200ms
%                     step_tic = tic;  %reset step timer
%                 end
%             end
%             clear pre_contr step_tic run_tic
            
                
            obj.PTB.displayMessage('Finished');

            disp('saving...')
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.r_EEG); mkdir(obj.directories.r_EEG); end
            save([obj.directories.r_EEG 'r_EEG_' time], 'obj', '-v7.3')
            disp('Finished')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = []; % obj.r_EEG = [];
        end

        function aEMG(obj)
            % This function records 3 minuts of active EEG and EMG
            
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('off');
            obj.objMag.flushData();
            obj.dataEEGEMG = [];
            obj.a_EMG = [];
            time = obj.time;
            pre_contr = nan(1,10);
            % Preperation time I
            obj.PTB.displayMessage('Active EMG');
            play(obj.audio.prep);
            pause(3)
            % Preperation time II - gives time to be completly relax
            obj.PTB.displayMessage('Contract');
            pause(1)
            play(obj.audio.contract);
            step_rise=1;                % counts the number of measurement steps
            obj.clear_buffer(obj)       % empty the buffer matrix
            step_tic = tic;             % timer for 200ms steps
            run_tic = tic;              % timer for measure part (pre/post)
            obj.add_marker(obj,1)       % adds marker to buffer
            while toc(run_tic) < 180    % Measure resting EEG for 180s
                if toc(step_tic) >= 0.2 % take last 200ms
                    tmp             = double(obj.objBuf.read_data());   % get data
                    obj.a_EMG       = cat(1,obj.a_EMG, tmp );           % append data
                    tmp             = tmp/10;     
                    obj.dataEEGEMG  = cat(1,obj.dataEEGEMG, tmp);       %append data
                    
                    % make sure data is 200 ms
                    if size(tmp,1) > 0.2*obj.ampSettings.SampRate
                        tmp = tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                    else
                        tmp = tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                    end
                    tmp = detrend(tmp);                 % detrend data
                    pre_contr(step_rise) = rms(tmp);    % measure of current contraction force
                    tmp = nanmean(pre_contr);           % measure of total MVC
                    %visual fdbk of contraction force
                    % (current contraction force, MVC, threshold,
                    % threshold_range,zoom_factor)
                    obj.PTB.m_contr(pre_contr(step_rise), tmp, tmp,obj.tms_settings.mvc_range,0.8) 
                    clear tmp
                    step_rise = step_rise + 1; %next 200ms
                    step_tic = tic;  %reset step timer
                end
            end
            clear pre_contr step_tic run_tic
            
            obj.add_marker(obj,2)       % adds marker to buffer
            obj.PTB.displayMessage('Finished');

            disp('saving...')
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.a_EMG); mkdir(obj.directories.a_EMG); end
            save([obj.directories.a_EMG 'a_EMG_' time], 'obj', '-v7.3')
            disp('Finished')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = []; % obj.a_EMG = [];
        end
        
        function get_CMC(obj)
            % This function reord time atamps for the CMC
            time = 'pre';
            % Preperation time I
            obj.PTB.displayMessage('Left Hand');
            play(obj.audio.prep);
%             obj.add_marker(obj,1)       %adds marker to buffer
            pause(2)
%             obj.add_marker(obj,1)       %adds marker to buffer

            obj.PTB.displayMessage('Contract');
            play(obj.audio.contract);
            pause(1)
            obj.add_marker(obj,2)       %adds marker to buffer
            pause(5);
            %obj.add_marker(obj,2)       %adds marker to buffer

            % Measurement of MVC
            obj.PTB.displayMessage('Relax');
            play(obj.audio.relax);
            pause(1)
            obj.add_marker(obj,1)   %adds marker to buffer
            pause(5)
            %obj.add_marker(obj,1)   %adds marker to buffer
            
        end
        
        function get_MVC(obj)
        % This function measures the maximum voluntary contraction
        % (MVC) force, measured as the RMS of the EMG activity in 200ms
        % steps
        obj.check_buffer() %Check if buffer is still recording
        obj.objMag.turnOnOff('off');
        obj.objMag.flushData();
        obj.dataEEGEMG = [];
        time = 'pre';
        pre_contr = nan(1,10);
        % Preperation time I
        obj.PTB.displayMessage('Left Hand');
        play(obj.audio.prep);
        pause(2)
        % Preperation time II - gives time to achieve max contraction
        obj.PTB.displayMessage('Contract');
        play(obj.audio.contract);
        step_rise=1;                %counts the number of measurement steps
        obj.clear_buffer(obj)       %empty the buffer matrix
        step_tic = tic;             %timer for 200ms steps
        run_tic = tic;              %timer for measure part (pre/post)
        obj.add_marker(obj,1)       %adds marker to buffer
        while toc(run_tic) < 2      %Measure pre MVC for 2s
            if toc(step_tic) >= 0.2 %take last 200ms
                tmp = double(obj.objBuf.read_data()/10);     % get data
                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %append data
                % make sure data is 200 ms
                if size(tmp,1) > 0.2*obj.ampSettings.SampRate
                    tmp = tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                else
                    tmp = tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                end
                tmp = detrend(tmp);         % detrend data
                pre_contr(step_rise) = rms(tmp); % measure of current contraction force
                tmp = nanmean(pre_contr);   % measure of total MVC
                %visual fdbk of contraction force
                % (current contraction force, MVC, threshold,
                % threshold_range,zoom_factor)
                obj.PTB.m_contr(pre_contr(step_rise), tmp, tmp,obj.tms_settings.mvc_range,0.8) 
                clear tmp
                step_rise = step_rise + 1; %next 200ms
                step_tic = tic;  %reset step timer
            end
        end
        clear pre_contr step_tic run_tic

        % Measurement of MVC
        step = 1;               %set the step count back to 1
        obj.add_marker(obj,2)   %adds marker to buffer
        step_tic = tic;         %timer for 200ms steps
        run_tic = tic;          %timer for measure part (pre/post)
        while toc(run_tic) < 5  %Measure MVC for 5s in 200ms steps
            if toc(step_tic) >= 0.2 %take last 200ms
                obj.add_marker(obj,2) %adds marker to buffer
                data_tmp = double(obj.objBuf.read_data()/10); %get data
                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, data_tmp); %append data
                % make sure data is 200 ms
                if size(data_tmp,1) > 0.2*obj.ampSettings.SampRate
                    data_tmp = data_tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                else
                    data_tmp = data_tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                end
                data_tmp = detrend(data_tmp);       % detrend data   ADAPT!!!   
                obj.mvc.step(step) = rms(data_tmp); %measure of contraction force
                clear data_tmp
                obj.mvc.mean = nanmean(obj.mvc.step); %measure of MVC
                %visual fdbk of contraction force
                % (current contraction force, MVC, threshold,
                % threshold_range,zoom_factor)
                obj.PTB.m_contr(obj.mvc.step(step), obj.mvc.mean,obj.mvc.mean, obj.tms_settings.mvc_range,0.8)
                step = step + 1; %next 200ms
                step_tic = tic;  %reset timer for 200ms steps
            end
        end
        obj.PTB.displayMessage('Relax');
        play(obj.audio.relax);
        pause(2)

        %% 2nd run
        pre_contr = nan(1,10);
        % Preperation time I
        obj.PTB.displayMessage('Left Hand');
        play(obj.audio.prep);
        pause(2)
        % Preperation time II - gives time to achieve max contraction
        obj.PTB.displayMessage('Contract');
        play(obj.audio.contract);
        step_rise=1;                     %counts the number of measurement steps
        obj.clear_buffer(obj)       %empty the buffer matrix
        step_tic = tic;             %timer for 200ms steps
        run_tic = tic;              %timer for measure part (pre/post)
        obj.add_marker(obj,1)       %adds marker to buffer
        while toc(run_tic) < 2      %Measure pre MVC for 2s
            if toc(step_tic) >= 0.2 %take last 200ms
                tmp = double(obj.objBuf.read_data()/10);     % get data
                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %append data
                % make sure data is 200 ms
                if size(tmp,1) > 0.2*obj.ampSettings.SampRate
                    tmp = tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                else
                    tmp = tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                end
                tmp = detrend(tmp);         % detrend data
                pre_contr(step_rise) = rms(tmp); % measure of current contraction force
                tmp = nanmean(pre_contr);   % measure of total MVC
                %visual fdbk of contraction force
                % (current contraction force, MVC, threshold,
                % threshold_range,zoom_factor)
                obj.PTB.m_contr(pre_contr(step_rise), tmp, tmp,obj.tms_settings.mvc_range,0.8) 
                clear tmp
                step_rise = step_rise + 1; %next 200ms
                step_tic = tic;  %reset step timer
            end
        end
        clear pre_contr step_tic run_tic

        % Measurement of MVC
        obj.add_marker(obj,2)   %adds marker to buffer
        step_tic = tic;         %timer for 200ms steps
        run_tic = tic;          %timer for measure part (pre/post)
        while toc(run_tic) < 5  %Measure MVC for 5s in 200ms steps
            if toc(step_tic) >= 0.2 %take last 200ms
                obj.add_marker(obj,2) %adds marker to buffer
                data_tmp = double(obj.objBuf.read_data()/10); %get data
                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, data_tmp); %append data
                % make sure data is 200 ms
                if size(data_tmp,1) > 0.2*obj.ampSettings.SampRate
                    data_tmp = data_tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                else
                    data_tmp = data_tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                end
                data_tmp = detrend(data_tmp);       % detrend data   ADAPT!!!   
                obj.mvc.step(step) = rms(data_tmp); %measure of contraction force
                clear data_tmp
                obj.mvc.mean = nanmean(obj.mvc.step); %measure of MVC
                %visual fdbk of contraction force
                % (current contraction force, MVC, threshold,
                % threshold_range,zoom_factor)
                obj.PTB.m_contr(obj.mvc.step(step), obj.mvc.mean,obj.mvc.mean, obj.tms_settings.mvc_range,0.8)
                step = step + 1; %next 200ms
                step_tic = tic;  %reset timer for 200ms steps
            end
        end
        obj.PTB.displayMessage('Relax');
        play(obj.audio.relax);
        pause(2)

        %% 3rd run
        pre_contr = nan(1,10);
        % Preperation time I
        obj.PTB.displayMessage('Left Hand');
        play(obj.audio.prep);
        pause(2)
        % Preperation time II - gives time to achieve max contraction
        obj.PTB.displayMessage('Contract');
        play(obj.audio.contract);
        step_rise=1;                     %counts the number of measurement steps
        obj.clear_buffer(obj)       %empty the buffer matrix
        step_tic = tic;             %timer for 200ms steps
        run_tic = tic;              %timer for measure part (pre/post)
        obj.add_marker(obj,1)       %adds marker to buffer
        while toc(run_tic) < 2      %Measure pre MVC for 2s
            if toc(step_tic) >= 0.2 %take last 200ms
                tmp = double(obj.objBuf.read_data()/10);     % get data
                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %append data
                % make sure data is 200 ms
                if size(tmp,1) > 0.2*obj.ampSettings.SampRate
                    tmp = tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                else
                    tmp = tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                end
                tmp = detrend(tmp);         % detrend data
                pre_contr(step_rise) = rms(tmp); % measure of current contraction force
                tmp = nanmean(pre_contr);   % measure of total MVC
                %visual fdbk of contraction force
                % (current contraction force, MVC, threshold,
                % threshold_range,zoom_factor)
                obj.PTB.m_contr(pre_contr(step_rise), tmp, tmp,obj.tms_settings.mvc_range,0.8) 
                clear tmp
                step_rise = step_rise + 1; %next 200ms
                step_tic = tic;  %reset step timer
            end
        end
        clear pre_contr step_tic run_tic

        % Measurement of MVC
        obj.add_marker(obj,2)   %adds marker to buffer
        step_tic = tic;         %timer for 200ms steps
        run_tic = tic;          %timer for measure part (pre/post)
        while toc(run_tic) < 5  %Measure MVC for 5s in 200ms steps
            if toc(step_tic) >= 0.2 %take last 200ms
                obj.add_marker(obj,2) %adds marker to buffer
                data_tmp = double(obj.objBuf.read_data()/10); %get data
                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, data_tmp); %append data
                % make sure data is 200 ms
                if size(data_tmp,1) > 0.2*obj.ampSettings.SampRate
                    data_tmp = data_tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';                        
                else
                    data_tmp = data_tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                end
                data_tmp = detrend(data_tmp);       % detrend data   ADAPT!!!   
                obj.mvc.step(step) = rms(data_tmp); %measure of contraction force
                clear data_tmp
                obj.mvc.mean = nanmean(obj.mvc.step); %measure of MVC
                %visual fdbk of contraction force
                % (current contraction force, MVC, threshold,
                % threshold_range,zoom_factor)
                obj.PTB.m_contr(obj.mvc.step(step), obj.mvc.mean,obj.mvc.mean, obj.tms_settings.mvc_range,0.8)
                step = step + 1; %next 200ms
                step_tic = tic;  %reset timer for 200ms steps
            end
        end
        obj.PTB.displayMessage('Finished');
        play(obj.audio.relax);


        disp('saving...')
        obj.MEPepochs = []; obj.MEP = []; %keeps file small
        disp('Saving...')
        if ~isdir(obj.directories.mvc); mkdir(obj.directories.mvc); end
        save([obj.directories.mvc 'MVC_' time], 'obj', '-v7.3')
        disp('Finished')
        obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];

        end

        function get_RMT(obj)
            % Determination of resting motor threshold by the relative
            % frequency method
            % Choose the lowest intensity eliciting MEPs >50µV ptp
            % amplitude in at least 5 of 10 trials
            % TMS should start with a subthreshold intensity of stimulation, i.e. 40%
            % First, stimulus intensity is gradually increased in steps of 5% MSO until TMS consistently evokes MEPs
            % Thereafter, stimulus intensity is gradually lowered in steps of 1% MSO until less than 5/10. 
            % This stimulus intensity plus 1 is then defined as RMT (Groppa et al., 2012)
            clc
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.mt 'RMT_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            run = 1;
            finish = 1;
            exit_run = 1; 
            amp = input('Choose starting amplitude: ');
            while finish %general exit
                if( obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                while finish %exit from run x
                                    disp(['Current intensity: ' num2str(amp)])
                                    while exit_run %exit earlier if there are at least 5 MEPs above threshold
                                        for rep = 1:10 %apply 10 stimuli
                                            if rep ~= 1 
                                                %ISI of 5 +- 1.25 s
                                                while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                            end
                                            display(['Rep: ' num2str(rep)])
                                            %stimulate with specified intensity if target muscle at rest and get buffer data
                                            [tmp,isiTic] = obj.stimTMS_rest(obj,amp);
                                            if(isempty(tmp))
                                                disp('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.check_buffer()
                                                    keyboard
                                                else
                                                    keyboard;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                                clear trig
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj, obj.tms_settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, obj.tms_settings.threshold_rmt);
                                                    obj.plotMEP(obj,data,stimTime,run,rep, gca);
                                                    obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                                else
                                                    obj.MEP.minAmp(run,rep)  = 0;
                                                    obj.MEP.maxAmp(run,rep)  = 0;
                                                    obj.MEP.delay(run,rep)   = 0;
                                                end
                                            end
                                            %Exit earlier if 5 MEPs detected or 5 can't be reached
                                            tmp = sum(double(obj.MEP.peakToPeak(run,:)>obj.tms_settings.threshold_rmt));
                                            if tmp >= 5; exit_run = 0; break
                                            elseif (rep-tmp) >= 6; exit_run = 0; break
                                            end
                                        end
                                    end
                                    exit_run = 1;
                                    obj.objMag.changeAmp(0,0);
                                    [~, sortMEPs]  = sort(obj.MEP.peakToPeak(run,:));
                                    var       = 0;
                                    clear tmp1 tmp2
                                    figure,
                                    if(sum(sortMEPs) > 0)
                                        for MEPnumb = 1:size(sortMEPs, 2)
                                            x_start = -50;
                                            x_end = obj.tms_settings.mep_end + 10;
                                            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
                                            if(MEPnumb/9==round((MEPnumb/9)))
                                                var          = MEPnumb-1;
                                                figure
                                            end
                                            subplot(3,3,MEPnumb-var)
                                            plot(x,squeeze(obj.MEPepochs(run,sortMEPs(1,MEPnumb),:)),'k', 'LineWidth', 2)
                                            hold on
                                            plot([obj.MEP.delayMin(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMin(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                                            plot([obj.MEP.delayMax(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMax(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                                            hold off
                                            y_range = [-obj.MEP.minAmp(run,sortMEPs(1,MEPnumb)) obj.MEP.maxAmp(run,sortMEPs(1,MEPnumb))];
                                            if min(y_range)==0 && max(y_range) == 0
                                                y_range = [-100 100];
                                            end
                                            ylim([min(y_range) max(y_range)])
                                            clear y_range
                                            xlim([x_start x_end])
                                            xlabel('Time [ms]')
                                            ylabel('Amplitude [\muV]')
                                            title(sprintf('MEP number: %d\n PtP: %d\nMaxPeak: %d, Latency: %d',sortMEPs(1,MEPnumb), ...
                                                round(obj.MEP.peakToPeak(sortMEPs(1,MEPnumb))), round(obj.MEP.maxAmp(sortMEPs(1,MEPnumb))), ...
                                                round(obj.MEP.delay(sortMEPs(1,MEPnumb)))))
                                        end
                                        clc
                                        figure,
                                        annotation('textbox', [0.28,0.52,0.1,0.1],...
                                            'String', {['Run: ' num2str(run)] [num2str(sum(double(obj.MEP. ...
                                            peakToPeak(run,:)>obj.tms_settings.threshold_rmt))) ' out of 10' ] ...
                                            ['Current Intensity: ' num2str(amp)] ...
                                            }, 'FontSize', 14);
                                        obj.objMag.changeAmp(0,0);
                                    else
                                        title('No MEPs detected', 'Fontsize', 16)
                                    end
                                    run = run + 1;
                                    [finish, amp] = obj.add_intensity_rmt();
                                    if finish ~= 0
                                        figure
                                        obj.pauseFunc(obj, 0, amp);
                                    else
                                        disp('Finished')
                                    end
                                end
                            elseif strcmpi(mag_fbk,'int_change') %intensity changed
                                clc
                                amp = input('Choose new stimulation intensity: ');
                                clc
                                obj.objMag.changeAmp(0,0);
                                fprintf('Current stimulation intensity: %d \n',amp)
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            magSettings = dec2bin(messageMag(6));
                            if(magSettings(4))
                                keyboard
                            end
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            clear data
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.mt); mkdir(obj.directories.mt); end
            save([obj.directories.mt 'RMT_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function get_AMT(obj)
            % Determination of active motor threshold by the relative
            % frequency method
            % Choose the lowest intensity eliciting MEPs >200µV ptp
            % amplitude in at least 5 of 10 trials
            % First, stimulus intensity is gradually increased in steps of 5% MSO until TMS consistently evokes MEPs
            % Thereafter, stimulus intensity is gradually lowered in steps of 1% MSO until less than 5/10. 
            % This stimulus intensity plus 1 is then defined as AMT (Groppa et al., 2012)
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on'); %Turn MagVen on
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.dataEEGEMG = []; % Clear data matrix
            time = 'pre';
            if exist([obj.directories.mt 'AMT_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.mt 'AMT_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            run = 1;
            finish = 1;
            exit_run = 1;
            amp = input('Choose starting amplitude: ');
            while finish %general exit
                if( obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            %check MagVen for input
                            mag_fbk = obj.check_mag(obj);
                            if strcmpi(mag_fbk,'stimulate')
                                %Start stimulation protocol
                                while finish %exit from run x
                                    obj.objMag.changeAmp(amp,0);
                                    pause_ms(500)
                                    display(['Current intensity: ' num2str(amp)])
                                    while exit_run %exit earlier if there are at least 5 MEPs above threshold
                                        for rep = 1:10
                                            if rep ~= 1
                                                %ISI of 5 +- 1.25 s
                                                while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                            end
                                            clc
                                            display(['Rep: ' num2str(rep)])
                                            % Preperation time
                                            obj.PTB.displayMessage('Left Hand');
                                            play(obj.audio.prep);
                                            pause(1)
                                            % Contraction Time
                                            obj.PTB.displayMessage('Contract');
                                            play(obj.audio.contract);
                                            % If subject contracts muscle for
                                            % 2-3s at correct % MVC stimulate
                                            [tmp,isiTic] = obj.stimTMS_act(obj,amp);
                                            if(isempty(tmp)) %Data wasn't recorded
                                                disp('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.check_buffer()
                                                    keyboard
                                                else
                                                    keyboard;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                                clear data_tmp
                                            end
                                            
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                                clear trig
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj, obj.tms_settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, obj.tms_settings.threshold_amt);
                                                    obj.plotMEP(obj,data,stimTime,run,rep, gca);
                                                    obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                                else
                                                    obj.MEP.minAmp(run,rep)  = 0;
                                                    obj.MEP.maxAmp(run,rep)  = 0;
                                                    obj.MEP.delay(run,rep)   = 0;
                                                end
                                            end
                                            %Exit earlier if 5 MEPs detected or 5 can't be reached
                                            tmp = sum(double(obj.MEP.peakToPeak(run,:)>obj.tms_settings.threshold_amt));
                                            if tmp >= 5; exit_run = 0; break
                                            elseif (rep-tmp) >= 6; exit_run = 0; break
                                            end
                                        end
                                    end
                                    exit_run = 1;
                                    obj.objMag.changeAmp(0,0);
                                    [~, sortMEPs]  = sort(obj.MEP.peakToPeak(run,:));
                                    var       = 0;
                                    clear tmp1 tmp2
                                    figure,
                                    if(sum(sortMEPs) > 0)
                                        for MEPnumb = 1:size(sortMEPs, 2)
                                            x_start = -50;
                                            x_end = obj.tms_settings.mep_end + 10;
                                            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
                                            if(MEPnumb/9==round((MEPnumb/9)))
                                                var          = MEPnumb-1;
                                                figure
                                            end
                                            subplot(3,3,MEPnumb-var)
                                            plot(x,squeeze(obj.MEPepochs(run,sortMEPs(1,MEPnumb),:)),'k', 'LineWidth', 2)
                                            hold on
                                            plot([obj.MEP.delayMin(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMin(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                                            plot([obj.MEP.delayMax(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMax(run,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                                            hold off
                                            y_range = [-obj.MEP.minAmp(run,sortMEPs(1,MEPnumb)) obj.MEP.maxAmp(run,sortMEPs(1,MEPnumb))];
                                            if min(y_range)==0 && max(y_range) == 0
                                                y_range = [-100 100];
                                            end
                                            ylim([min(y_range) max(y_range)])
                                            clear y_range
                                            xlim([x_start x_end])
                                            xlabel('Time [ms]')
                                            ylabel('Amplitude [\muV]')
                                            title(sprintf('MEP number: %d\n PtP: %d\nMaxPeak: %d, Latency: %d',sortMEPs(1,MEPnumb), ...
                                                round(obj.MEP.peakToPeak(sortMEPs(1,MEPnumb))), round(obj.MEP.maxAmp(sortMEPs(1,MEPnumb))), ...
                                                round(obj.MEP.delay(sortMEPs(1,MEPnumb)))))
                                        end
                                        clc
                                        figure,
                                        annotation('textbox', [0.28,0.52,0.1,0.1],...
                                            'String', {['Run: ' num2str(run)] [num2str(sum(double(obj.MEP. ...
                                            peakToPeak(run,:)>obj.tms_settings.threshold_amt))) ' out of 10' ] ...
                                            ['Current Intensity: ' num2str(amp)] ...
                                            }, 'FontSize', 14);
                                        obj.objMag.changeAmp(0,0);
                                    else
                                        title('No MEPs detected', 'Fontsize', 16)
                                    end
                                    run = run + 1;
                                    [finish, amp] = obj.add_intensity_rmt();
                                    if finish ~= 0
                                        figure
                                        obj.pauseFunc(obj, 0, amp);
                                    else
                                        disp('Finished')
                                    end
                                end
                            elseif strcmpi(mag_fbk,'int_change') %intensity changed
                                clc
                                amp = input('Choose new stimulation intensity: ');
                                clc
                                obj.objMag.changeAmp(0,0);
                                fprintf('Current stimulation intensity: %d \n',amp)
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            magSettings = dec2bin(messageMag(6));
                            if(magSettings(4))
                                keyboard
                            end
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.mt); mkdir(obj.directories.mt); end
            save([obj.directories.mt 'AMT_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function lat_current(obj)
            % This function is meant to get the latencies of MEP in regards to certain orientations
            % Different latency-ratios can point towards responders to
            % certain interventions (Hamada et al., 2013)
            obj.check_buffer() %Check if buffer is still recording
            obj.dataEEGEMG = [];
            orientation = input('Orientation: (pa/lm)','s');
            if exist([obj.directories.lat_current 'current_' orientation '.mat'],'file') == 2
                orientation = input('File exists already. Redo Time: ','s');
            end
            if strcmpi(orientation,'pa')
                amp = floor(1.1*obj.tms_settings.amt_int);
            elseif strcmpi(orientation,'lm')
                amp = floor(1.5*obj.tms_settings.amt_int);
                if amp < 50
                    amp = 50;
                end
            else
                disp('You have chosen the wrong orientation')
                keyboard
            end
            obj.objMag.flushData();
            finish  = 1;
            run     = 1;
            set_back_int = 0;
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            %check MagVen for input
                            mag_fbk = obj.check_mag(obj);
                            if strcmpi(mag_fbk,'stimulate')
                                %Start stimulation protocol
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(amp,0);
                                    pause(1)
                                    for rep = 1:obj.tms_settings.mep_iterations	
                                        if rep ~= 1 
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        disp(['Rep: ' num2str(rep)])
                                        % Preperation time
                                        obj.PTB.displayMessage('Left Hand');
                                        play(obj.audio.prep);
                                        pause(1)
                                        % Contraction Time
                                        obj.PTB.displayMessage('Contract');
                                        play(obj.audio.contract);     
                                        % If subject contracts muscle for
                                        % 2-3s at correct % MVC stimulate
                                        [tmp,isiTic] = obj.stimTMS_act(obj,amp);
                                        if(isempty(tmp)) %Data wasn't recorded
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                                keyboard
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                            clear data_tmp
                                        end
                                        
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt );
                                                obj.getiMEPinf(obj,data,stimTime,run,rep);
                                                obj.plotMEP(obj, data, stimTime, run, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.peakToPeak(run,rep),obj.MEP.peakToPeak(run,rep), obj.MEP.duration(run,rep));
                                            else
                                                obj.MEP.iMEP(run,rep)  = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    
                                    if strcmpi(orientation,'pa')
                                        if run >= obj.tms_settings.runs_pa
                                            finish = 0;
                                        else
                                            obj.pauseFunc(obj,0,amp);
                                        end
                                    elseif strcmpi(orientation,'lm')
                                        if run >= obj.tms_settings.runs_lm
                                            finish = 0;
                                        else
                                            obj.pauseFunc(obj,0,amp);
                                        end
                                    end
                                    
                                    if set_back_int == 1 %repeat last stimulus as it wasn't recorded
                                        run = run - 1; 
                                        set_back_int = 0;
                                    end
                                    run = run + 1;
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %do this to keep file small
            disp('Saving...')
            if ~isdir(obj.directories.lat_current); mkdir(obj.directories.lat_current); end
            save([obj.directories.lat_current 'current_' orientation], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        %% Functions to measure corticospinal excitability at rest
        function get_IO(obj)
            % Function to get input output recruitment curve
            % intensities are selected by tms_settings.io_int and applied
            % in a pseudo-random order in blocks of 10 stimuli per
            % intensity
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.io 'io_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.io 'io_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            int     = 1;
            set_back_int = 0;
            io_curve = NaN(1,length(obj.tms_settings.io_int)); %Set matri in which to store means for fitting
%             obj.tms_settings.io_int = obj.tms_settings.io_int(randperm(numel(obj.tms_settings.io_int))); %random order of intensities
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    disp(['Current intensity: ' num2str(int) ' ' num2str(obj.tms_settings.io_int(1,int)) '%'])
                                    %apply 10 Stimuli for each intensity
                                    for rep = 1:10
                                        if rep ~= 1
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (3.15-1.95)*rand(1)+2, end %500ms for MagVen to change int
                                        end
                                        display(['Rep: ' num2str(rep)])
                                        %stimulate with specified intensity if target muscle at rest and get buffer data
                                        [tmp,isiTic] = obj.stimTMS_rest(obj,obj.tms_settings.io_int(1,int));
                                        if(isempty(tmp))
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                            else
                                                keyboard
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,int,rep, obj.tms_settings.threshold_rmt);
                                                obj.plotMEP(obj, data, stimTime, int, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.maxAmp(int,rep)+obj.MEP.minAmp(int,rep),obj.MEP.maxAmp(int,rep), obj.MEP.delay(int,rep));
                                            else
                                                obj.MEP.minAmp(int,rep)  = 0;
                                                obj.MEP.maxAmp(int,rep)  = 0;
                                                obj.MEP.delay(int,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    io_curve(1,int)     =  mean(obj.MEP.peakToPeak(int,:));
                                    cla(h2);
                                    boxplot(obj.MEP.peakToPeak(1:int,:)', obj.tms_settings.io_int(1:int))
                                    xlabel(h2, 'Intensity [%]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Input Output Curve'; [num2str(int) ' out of ' num2str(size(obj.tms_settings.io_int,2))]}, 'FontSize', 12)
                                    drawnow                    
                                    if(int>=length(obj.tms_settings.io_int))
                                        [io_fit, io_fit_int] = obj.fit(obj, io_curve);
                                        obj.plotInpOutCurv(obj,io_curve,io_fit,io_fit_int)
                                        [finish] = obj.addIntIO(obj);
                                        figure
                                        h1=subplot(2,1,1);
                                        h2=subplot(2,1,2);
                                    else
                                        obj.pauseFunc(obj, int, 1);
                                    end
                                    int = int + 1;
                                    if set_back_int
                                        int = int - 1; 
                                        set_back_int = 0;
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.io); mkdir(obj.directories.io); end
            save([obj.directories.io 'io_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end

        function get_IO_rand(obj)
            % Function to get input output recruitment curve
            % intensities are selected by tms_settings.io_int and applied
            % in a pseudo-random order in blocks of 10 stimuli per
            % intensity
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.io 'io_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.io 'io_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            int     = 1;
            set_back_int = 0;
            io_curve = NaN(1,length(obj.tms_settings.io_int)); %Set matri in which to store means for fitting
            obj.tms_settings.io_int = obj.tms_settings.io_int(randperm(numel(obj.tms_settings.io_int))); %random order of intensities
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    disp(['Current intensity: ' num2str(int) ' ' num2str(obj.tms_settings.io_int(1,int)) '%'])
                                    %apply 10 Stimuli for each intensity
                                    for rep = 1:10
                                        if rep ~= 1
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        display(['Rep: ' num2str(rep)])
                                        %stimulate with specified intensity if target muscle at rest and get buffer data
                                        [tmp,isiTic] = obj.stimTMS_rest(obj,obj.tms_settings.io_int(1,int));
                                        if(isempty(tmp))
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                            else
                                                keyboard
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,int,rep, obj.tms_settings.threshold_rmt);
                                                obj.plotMEP(obj, data, stimTime, int, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.maxAmp(int,rep)+obj.MEP.minAmp(int,rep),obj.MEP.maxAmp(int,rep), obj.MEP.delay(int,rep));
                                            else
                                                obj.MEP.minAmp(int,rep)  = 0;
                                                obj.MEP.maxAmp(int,rep)  = 0;
                                                obj.MEP.delay(int,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    io_curve(1,int)     =  mean(obj.MEP.peakToPeak(int,:));
                                    cla(h2);
                                    boxplot(obj.MEP.peakToPeak(1:int,:)', obj.tms_settings.io_int(1:int))
                                    xlabel(h2, 'Intensity [%]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Input Output Curve'; [num2str(int) ' out of ' num2str(size(obj.tms_settings.io_int,2))]}, 'FontSize', 12)
                                    drawnow                    
                                    if(int>=length(obj.tms_settings.io_int))
                                        [io_fit, io_fit_int] = obj.fit(obj, io_curve);
                                        obj.plotInpOutCurv(obj,io_curve,io_fit,io_fit_int)
                                        [finish] = obj.addIntIO(obj);
                                        figure
                                        h1=subplot(2,1,1);
                                        h2=subplot(2,1,2);
                                    else
                                        obj.pauseFunc(obj, int, 1);
                                    end
                                    int = int + 1;
                                    if set_back_int
                                        int = int - 1; 
                                        set_back_int = 0;
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.io); mkdir(obj.directories.io); end
            save([obj.directories.io 'io_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end

        function get_CSE(obj)
            % Function to get corticospinal excitability
            % # of runs is selected by tms_settings.cse_runs and applied
            % in blocks of # = tms_settings.cse_iterations stimuli
            % EEG channel obj.tms_settings.eeg_fbk_ch is also plotted as
            % feedback
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.mep 'mep_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.mep 'mep_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            run     = 1;
            set_back_int = 0;
            amp = floor(1.1*obj.tms_settings.rmt_int);
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    for rep = 1:obj.tms_settings.cse_iterations
                                        if rep ~= 1
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        display(['Rep: ' num2str(rep)])
                                        %stimulate with specified intensity if target muscle at rest and get buffer data
                                        [tmp,isiTic] = obj.stimTMS_rest(obj,amp);
                                        if(isempty(tmp))
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,run,rep, obj.tms_settings.threshold_rmt);
                                                obj.plotMEP(obj, data, stimTime, run, rep, h1)
                                                obj.plotEEG(obj, stimTime, rep, h2, obj.tms_settings.eeg_fbk_ch)
                                                obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                            else
                                                obj.MEP.minAmp(run,rep)  = 0;
                                                obj.MEP.maxAmp(run,rep)  = 0;
                                                obj.MEP.delay(run,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    if run >= obj.tms_settings.cse_runs
                                        finish = 0;
                                    else
                                        obj.pauseFunc(obj,0,amp);
                                    end
                                    
                                    if set_back_int == 1 %repeat last stimulus as it wasn't recorded
                                        run = run - 1; 
                                        set_back_int = 0;
                                    end
                                    run = run + 1;
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.mep); mkdir(obj.directories.mep); end
            save([obj.directories.mep 'mep_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end

        function get_corticalmap(obj)
            % Function to get cortical excitability map
            % # of stimulation points is selected by tms_settings.map_points
            % and one stimulus per location is applied
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = 'pre';
            if exist([obj.directories.map 'map_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.map 'map_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish = 1; %Exit if round>rand_walk_iterations
            round =1; %spot of location in 10x10 grid
            set_back_int = 0;
            amp = floor(1.1*obj.tms_settings.rmt_int);
            while finish
                if( obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                while round<=obj.tms_settings.map_points %stays in loop until end of iterations %apply x stimuli at different loations
                                    if round ~= 1 
                                        %ISI of 5 +- 1.25 s
                                        while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                    end
                                    %stimulate with specified intensity if target muscle at rest and get buffer data
                                    [tmp,isiTic] = obj.stimTMS_rest(obj,amp);
                                    if(isempty(tmp))
                                        disp('Power pack empty!!!')
                                        if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                            obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                            obj.dataEEGEMG = [];
                                            obj.check_buffer()
                                            set_back_int = 1;
                                        else
                                            keyboard;
                                        end
                                    else
                                        obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                        clear tmp
                                    end
                                    if(~isempty(obj.dataEEGEMG))
                                        trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                        stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                        clear trig
                                        if(stimTime > 40 && ~isnan(stimTime))
                                            data = obj.filterData(obj, obj.tms_settings.addNotchFilt);
                                            obj.getMEPinf(obj,data,stimTime,1,round, 0);
                                            obj.plotMEP(obj,data,stimTime,1,round, gca);
                                            obj.objLoc.sendMEP(obj.MEP.peakToPeak(1,round), obj.MEP.minAmp(1,round), obj.MEP.delay(1,round));
                                        else
                                            obj.MEP.minAmp(1,round)  = 0;
                                            obj.MEP.maxAmp(1,round)  = 0;
                                            obj.MEP.delay(1,round)   = 0;
                                            obj.MEP.delayMax(1,round) = 0;
                                            obj.MEP.delayMin(1,round) = 0;
                                            obj.MEP.peakToPeak(1,round) = 0;
                                        end
                                    end
                                    clc
                                    if(obj.objMag.spObject.BytesAvailable~=0)
                                        obj.objMag.flushData
                                    end
                                    fprintf('MEP peak-to-peak:  %.2f \nStimulus %d of %i\n',nanmean(obj.MEP.peakToPeak(1,round)), round, obj.tms_settings.map_points);
                                    round = round + 1;
                                    if round > obj.tms_settings.map_points
                                    finish = 0;
                                    end
                                end
                                %if exited due to empty PP repeat last stimulus and
                                %continue from there
                                if set_back_int == 1
                                    set_back_int = 0;
                                    keyboard
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            magSettings = dec2bin(messageMag(6));
                            if(magSettings(4)) %exit by disabling magventure
                                break;
                            end
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.map); mkdir(obj.directories.map); end
            save([obj.directories.map 'map_' time], 'obj', '-v7.3')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            disp('Finished')
            obj.objMag.turnOnOff('off');
        end        
        
        %% Functions to measure corticospinal excitability in contracted muscle                
        function iMEP_detection(obj)
            % Function to determine if iMEP is detectable after application
            % of 10 stimuli at 100% MSO with set % of MVC
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on'); %Turn MagVen on
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.dataEEGEMG = []; % Clear data matrix
            amp = obj.tms_settings.imep_amp; %Stimulation intensity
            time = 'pre';
            if exist([obj.directories.imep 'imep_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.imep 'imep_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            run     = 1;
            set_back_int = 0; %set back to previous stim if data is not recorded
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            %check MagVen for input
                            mag_fbk = obj.check_mag(obj);
                            if strcmpi(mag_fbk,'stimulate')
                                %Start stimulation protocol
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    % Iteration of multiple stimuli in one go
                                    for rep = 1:obj.tms_settings.imep_iterations
                                        if rep ~= 1 
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        clc
                                        display(['Rep: ' num2str(rep)])
                                        % Preperation time
                                        obj.PTB.displayMessage('Left Hand');
                                        play(obj.audio.prep);
                                        pause(1)
                                        % Contraction Time
                                        obj.PTB.displayMessage('Contract');
                                        play(obj.audio.contract);     
                                        % If subject contracts muscle for
                                        % 3s at X%MVC stimulate
                                        [tmp,isiTic] = obj.stimTMS_act(obj,amp);
                                        if(isempty(tmp)) %Data wasn't recorded
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                                keyboard
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                            clear data_tmp
                                        end
                                        
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt );
                                                obj.getiMEPinf(obj,data,stimTime,run,rep);
                                                obj.plotMEP(obj, data, stimTime, run, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.peakToPeak(run,rep),obj.MEP.peakToPeak(run,rep), obj.MEP.duration(run,rep));
                                            else
                                                obj.MEP.iMEP(run,rep)  = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    
                                    cla(h2);
                                    plot(sum(obj.MEP.iMEP(1:run,:),2),'ok','MarkerSize',10,'MarkerFaceColor','k')
                                    ylabel(h2, 'Number of iMEPs')
                                    drawnow 
                                    
                                    if run >= obj.tms_settings.imep_runs
                                        finish = 0;
                                    else
                                        obj.pauseFunc(obj,0,amp);
                                    end
                                    
                                    if set_back_int == 1 %repeat last stimulus as it wasn't recorded
                                        run = run - 1; 
                                        set_back_int = 0;
                                    end
                                    run = run + 1;
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %do this to keep file small
            disp('Saving...')
            if ~isdir(obj.directories.imep); mkdir(obj.directories.imep); end
            save([obj.directories.imep 'imep_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.changeAmp(0,0)
        end

        function iMEP_coil_orientation(obj)
            % Function to determine if iMEP is detectable with different coil orientations
            % Pseudo randomized application of 10 stimuli at 100% MSO with set % of MVC
            % Orientations are set by tms_settings.imep_orientations
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on'); %Turn MagVen on
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.dataEEGEMG = []; % Clear data matrix
            amp = obj.tms_settings.imep_amp; %Stimulation intensity
            time = 'pre';
            if exist([obj.directories.imep 'orientation_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.imep 'orientation_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            run     = 1;
            set_back_int = 0; %set back to previous stim if data is not recorded
            obj.tms_settings.imep_orientations = obj.tms_settings.imep_orientations(randperm(numel(obj.tms_settings.imep_orientations)));
            input(['Did you select orientation ' obj.tms_settings.imep_orientations{run} '? \nEnter to continue']) %First orientation
            while finish
                clc
                disp('Press stimulation button to start run')
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            %check MagVen for input
                            mag_fbk = obj.check_mag(obj);
                            if strcmpi(mag_fbk,'stimulate')
                                %Start stimulation protocol
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    fprintf('Select orientation %s\n', obj.tms_settings.imep_orientations{run})
                                    % Iteration of multiple stimuli in one go
                                    for rep = 1:obj.tms_settings.imep_iterations
                                        if rep ~= 1 
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75,end %4.5-1.25+2.5*rand(1), end %500ms for MagVen to change int
                                        end
                                        clc
                                        disp(['Rep: ' num2str(rep)])
                                        % Preperation time
                                        obj.PTB.displayMessage('Left Hand');
                                        play(obj.audio.prep);
                                        pause(1)
                                        % Contraction Time
                                        obj.PTB.displayMessage('Contract');
                                        play(obj.audio.contract);     
                                        % If subject contracts muscle for
                                        % 3s at X%MVC stimulate
                                        [tmp,isiTic] = obj.stimTMS_act(obj,amp);                                        
                                        if(isempty(tmp)) %Data wasn't recorded
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                                keyboard
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                            clear data_tmp
                                        end
                                        
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt );
                                                obj.getiMEPinf(obj,data,stimTime,run,rep);
                                                obj.plotiMEP(obj, data, stimTime, rep, h1) 
%                                                 obj.plotMEP(obj, data, stimTime, run, rep, h1) 
                                                obj.objLoc.sendMEP(obj.MEP.peakToPeak(run,rep),obj.MEP.peakToPeak(run,rep), obj.MEP.duration(run,rep));
                                            else
                                                obj.MEP.iMEP(run,rep)  = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                   
                                    cla(h2);
                                    plot(sum(obj.MEP.iMEP(1:run,:),2),'ok','MarkerSize',10,'MarkerFaceColor','k')
                                    xticks(h2,1:run)
                                    xticklabels(h2,obj.tms_settings.imep_orientations(1:run))
                                    ylabel(h2, 'Number of iMEPs')
                                    title({'Orientation'; [num2str(run) ' out of ' num2str(numel(obj.tms_settings.imep_orientations))]}, 'FontSize', 12)
                                    drawnow                    
                                    
                                    if run >= numel(obj.tms_settings.imep_orientations)
                                        finish = 0;
                                    else
                                        input(['Did you select orientation ' obj.tms_settings.imep_orientations{run+1} '? \nEnter to continue'])
                                        obj.pauseFunc(obj,0,amp);
                                    end
                                    
                                    if set_back_int == 1 %repeat last stimulus as it wasn't recorded
                                        run = run - 1; 
                                        set_back_int = 0;
                                    end
                                    run = run + 1;
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %do this to keep file small
            disp('Saving...')
            if ~isdir(obj.directories.imep); mkdir(obj.directories.imep); end
            save([obj.directories.imep 'orientation_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function iTMS_Stimulation(obj)
            % Function to determine if iMEP is detectable with 20 TMS
            % Stimuli at rest and 20 stimuli with set % of MVC
            % Orientations are set by tms_settings.imep_orientations
            obj.check_buffer()                      %Check if buffer is still recording
            obj.objMag.turnOnOff('on');             %Turn MagVen on
            obj.objMag.changeAmp(0,0);              %change magventure to 0%
            obj.dataEEGEMG                  = [];   % Clear data matrix
            amp                             = obj.tms_settings.imep_amp; %Stimulation intensity
            time                            = obj.time;
%             obj.tms_settings.mvc_percentage = 0.0001;
%             obj.mvc.mean = 50; % 1.27;
            
            if exist([obj.directories.imep 'orientation_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.imep 'orientation_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            run     = 1;
            set_back_int = 0; %set back to previous stim if data is not recorded
            obj.tms_settings.imep_orientations = obj.tms_settings.imep_orientations(randperm(numel(obj.tms_settings.imep_orientations)));
%             input(['Did you select orientation ' obj.tms_settings.imep_orientations{run} '? \nEnter to continue']) %First orientation
            while finish
                clc
                disp('Press stimulation button to start run')
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            %check MagVen for input
                            mag_fbk = obj.check_mag(obj);
                            if strcmpi(mag_fbk,'stimulate')
                                %Start stimulation protocol
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    
                                    a=strfind( obj.tms_settings.iTMS_Stimu, 'Rest');
                                    if (find(not(cellfun('isempty', a))) == run);
                                        for rep = 1:obj.tms_settings.TMS_iterations
                                            if rep ~= 1 
                                                %ISI of 5 +- 1.25 s
                                                while toc(isiTic) < (6.25-3.75)*rand(1)+3.75,end %4.5-1.25+2.5*rand(1), end %500ms for MagVen to change int
                                            end
                                            clc
                                            disp(['Rep: ' num2str(rep)])
                                            % Preperation time
                                            obj.PTB.displayMessage('Left Hand');
    %                                         play(obj.audio.prep);
                                            pause(1)
                                            % Contraction Time
                                            obj.PTB.displayMessage('Relax');
                                            pause(3)
    %                                         play(obj.audio.contract);     
                                            % If subject contracts muscle for
                                            % 3s at X%MVC stimulate
                                            [tmp,isiTic] = obj.stimTMS_rest(obj,amp);                                        
                                            if(isempty(tmp)) %Data wasn't recorded
                                                disp('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.check_buffer()
                                                    set_back_int = 1;
                                                    keyboard
                                                else
                                                    keyboard;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                                clear data_tmp
                                            end

                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                                clear trig
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.tms_settings.addNotchFilt );
                                                    obj.getiMEPinf_Rest(obj,data,stimTime,run,rep, obj.tms_settings.threshold_rmt);
                                                    obj.plotiMEP(obj, data, stimTime, rep, h1) 
    %                                                 obj.plotMEP(obj, data, stimTime, run, rep, h1) 
                                                    obj.objLoc.sendMEP(obj.MEP.peakToPeak(run,rep),obj.MEP.peakToPeak(run,rep), obj.MEP.duration(run,rep));
                                                else
                                                    obj.MEP.iMEP(run,rep)  = 0;
                                                    obj.objLoc.sendMEP(0,0,0);
                                                end
                                            end
                                        end

                                        % cla(h2);

                                        plot(h2,sum(obj.MEP.iMEP(1:run,:),2),'ok','MarkerSize',10,'MarkerFaceColor','k')
    %                                     xticks(h2,1:run)
    %                                     xticklabels(h2,obj.tms_settings.imep_orientations(1:run))
                                        ylabel(h2, 'Number of iMEPs')
                                        title({'TMS Stimulation'; [num2str(run) ' of ' cell2mat(obj.tms_settings.iTMS_Stimu(run))]}, 'FontSize', 12)
                                        drawnow                    
                                        if run >= numel(obj.tms_settings.iTMS_Stimu)
                                            finish = 0;
                                        else
                                            obj.pauseFunc(obj,0,amp);
                                        end
                                    
                                        if set_back_int == 1 %repeat last stimulus as it wasn't recorded
                                            run = run - 1; 
                                            set_back_int = 0;
                                        end
                                    
                                        run = run + 1;
                                    else 
                                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %                                     fprintf('Select orientation %s\n', obj.tms_settings.imep_orientations{run})
                                        % Iteration of multiple stimuli in one go
                                        a=strfind( obj.tms_settings.iTMS_Stimu, 'Contraction');
                                        find(not(cellfun('isempty', a)));

                                        for rep = 1:obj.tms_settings.TMS_iterations
                                            if rep ~= 1 
                                                %ISI of 5 +- 1.25 s
                                                while toc(isiTic) < (6.25-3.75)*rand(1)+3.75,end %4.5-1.25+2.5*rand(1), end %500ms for MagVen to change int
                                            end
                                            clc
                                            disp(['Rep: ' num2str(rep)])
                                            % Preperation time
                                            obj.PTB.displayMessage('Left Hand');
    %                                         play(obj.audio.prep);
                                            pause(1)
                                            % Contraction Time
                                            obj.PTB.displayMessage('Contract');
    %                                         play(obj.audio.contract);     
                                            % If subject contracts muscle for
                                            % 3s at X%MVC stimulate
                                            [tmp,isiTic] = obj.stimTMS_act(obj,amp);                                        
                                            if(isempty(tmp)) %Data wasn't recorded
                                                disp('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.check_buffer()
                                                    set_back_int = 1;
                                                    keyboard
                                                else
                                                    keyboard;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                                clear data_tmp
                                            end

                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                                stimTime     = find(trig, 1, 'last') %Last entry in marker channel
                                                pause(1);
                                                clear trig
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.tms_settings.addNotchFilt );
                                                    obj.getiMEPinf(obj,data,stimTime,run,rep);
                                                    obj.plotiMEP(obj, data, stimTime, rep, h1) 
    %                                               obj.plotMEP(obj, data, stimTime, run, rep, h1) 
                                                    obj.objLoc.sendMEP(obj.MEP.peakToPeak(run,rep),obj.MEP.peakToPeak(run,rep), obj.MEP.duration(run,rep));
                                                else
                                                    obj.MEP.iMEP(run,rep)  = 0;
                                                    obj.objLoc.sendMEP(0,0,0);
                                                end
                                            end
                                        end

                                        % cla(h2);

                                        plot(h2,sum(obj.MEP.iMEP(1:run,:),2),'ok','MarkerSize',10,'MarkerFaceColor','k')
    %                                     xticks(h2,1:run)
    %                                     xticklabels(h2,obj.tms_settings.imep_orientations(1:run))
                                        ylabel(h2, 'Number of iMEPs')
                                        title({'TMS Stimulation'; [num2str(run) ' of ' cell2mat(obj.tms_settings.iTMS_Stimu(run))]}, 'FontSize', 12)
                                        drawnow                    

                                        if run >= numel(obj.tms_settings.iTMS_Stimu)
                                            finish = 0;
                                        else
                                            obj.pauseFunc(obj,0,amp);
                                        end
                                    
                                        if set_back_int == 1 %repeat last stimulus as it wasn't recorded
                                            run = run - 1; 
                                            set_back_int = 0;
                                        end
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            figure;plot(obj.dataEEGEMG(:,9));
            obj.MEPepochs = []; obj.MEP = []; %do this to keep file small
            disp('Saving...')
            % obj.directories.iTMS        = [projectPath '\data\' dataSub.initials '\iTMS_Stimulation\'];
            if ~isdir(obj.directories.iTMS); mkdir(obj.directories.iTMS); end
            save([obj.directories.iTMS 'iTMS_Stimulation_' time], 'obj', '-v7.3')
            save([obj.directories.hs 'hotspot_' num2str(rep)], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function iMEP_ipi(obj)
            % Function to determine if iMEP is detectable with different IPIs
            % Pseudo randomized application of 10 stimuli at 100% MSO with set % of MVC
            % IPIs are set by tms_settings.ipi_imep
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on'); %Turn MagVen on
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.dataEEGEMG = []; % Clear data matrix
            amp = obj.tms_settings.imep_amp; %Stimulation intensity
            time = 'pre';
            if exist([obj.directories.imep 'pp_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.imep 'pp_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            ipi_n = 1;
            set_back_int = 0; %set back to previous stim if data is not recorded
            obj.tms_settings.ipi_imep = obj.tms_settings.ipi_imep(randperm(numel(obj.tms_settings.ipi_imep))); %random order of IPIs
            for j = 1:numel(obj.tms_settings.ipi_imep) %show order of ISIs
                fprintf('ISI %d: %1.1d \n', j, obj.tms_settings.ipi_imep(j))
            end
            if strcmpi(input('Continue (Enter/n): ','s'),'n') %Continue after protocol is set on Magventure
                finish=0;
            end
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            %check MagVen for input
                            mag_fbk = obj.check_mag(obj);
                            if strcmpi(mag_fbk,'stimulate')
                                %Start stimulation protocol
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(amp,0);
                                    pause(1)
                                    for rep = 1:obj.tms_settings.imep_iterations  %apply x stimuli for each IPI
                                        if rep ~= 1
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.tms_settings.ipi_imep(ipi_n))
                                        % Subject has to contract muscle at certain threshold to trigger next step
                                        obj.PTB.displayMessage('Left Hand');
                                        play(obj.audio.prep);
                                        pause(1)
                                        obj.PTB.displayMessage('Contract');
                                        play(obj.audio.contract);
                                        % If subject contracts muscle for
                                        % 3s at X%MVC stimulate
                                        [tmp,isiTic] = obj.stimTMS_act(obj,amp);                                        
                                        if(isempty(tmp)) %Data wasn't recorded
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                                keyboard
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                            clear data_tmp
                                        end
                                        
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            stimTime     = stimTime + floor(0.001*obj.tms_settings.ipi_imep(ipi_n)*obj.ampSettings.SampRate); %so that the MEP triggered by the S2 is analyzed
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                obj.getiMEPinf(obj,data,stimTime,ipi_n,rep);
                                                obj.plotiMEP(obj, data, stimTime, rep, h1)
%                                                 obj.plotMEP(obj, data, stimTime, ipi_n, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.peakToPeak(ipi_n,rep),obj.MEP.peakToPeak(ipi_n,rep), obj.MEP.duration(ipi_n,rep));
                                            else
                                                obj.MEP.peakToPeak(ipi_n,rep)  = 0;
                                                obj.MEP.duration(ipi_n,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    cla(h2);
                                    plot(sum(obj.MEP.iMEP(1:ipi_n,:),2),'ok','MarkerSize',10,'MarkerFaceColor','k')
                                    xticks(h2,1:ipi_n)
                                    xticklabels(h2,obj.tms_settings.ipi_imep(1:ipi_n))
                                    ylabel(h2, 'Number of iMEPs')
                                    title({'IPI'; [num2str(ipi_n) ' out of ' num2str(numel(obj.tms_settings.ipi_imep))]}, 'FontSize', 12)
                                    drawnow
                                    if(ipi_n<length(obj.tms_settings.ipi_imep))
                                        if set_back_int
                                            ipi_n = ipi_n - 1;
                                            set_back_int = 0;
                                        end
                                        ipi_n = ipi_n + 1;
                                        obj.pauseFunc(obj, -1, obj.tms_settings.ipi_imep(ipi_n));
                                    else
                                        finish = 0;
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            
            % Plot the mean MEPs
            figure
            plot(obj.tms_settings.ipi_imep,nanmean(obj.MEP.peakToPeak,2),'+')
            title('IPI MEPs', 'FontSize', 16)
            xlabel('ISI [ms]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
            
            obj.MEPepochs = []; obj.MEP = []; %do this to keep file small
            disp('Saving...')
            if ~isdir(obj.directories.imep); mkdir(obj.directories.imep); end
            save([obj.directories.imep 'pp_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function iMEP_io(obj)
            % Function to get input output recruitment curve of iMEP
            % intensities are applied in a pseudo-random order
            % in blocks of 10 stimuli per intensity
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = input('Type (sp/pp): ','s');
            if exist([obj.directories.imep 'io_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.imep 'io_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish  = 1;
            int     = 1;
            set_back_int = 0;
            obj.tms_settings.io_int = [50 60 70 80 90];
            obj.tms_settings.io_int = obj.tms_settings.io_int(randperm(numel(obj.tms_settings.io_int))); %random order of intensities
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    disp(['Current intensity: ' num2str(int) ' ' num2str(obj.tms_settings.io_int(1,int)) '%'])
                                    %apply 10 Stimuli for each intensity
                                    for rep = 1:10
                                        if rep ~= 1
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        display(['Rep: ' num2str(rep)])
                                        % Subject has to contract muscle at certain threshold to trigger next step
                                        obj.PTB.displayMessage('Left Hand');
                                        play(obj.audio.prep);
                                        pause(1)
                                        obj.PTB.displayMessage('Contract');
                                        play(obj.audio.contract);
                                        % If subject contracts muscle for
                                        % 3s at X%MVC stimulate
                                        [tmp,isiTic] = obj.stimTMS_act(obj,obj.tms_settings.io_int(1,int));
                                        if(isempty(tmp))
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                            else
                                                keyboard
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last second of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            clear trig
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.tms_settings.addNotchFilt);
                                                obj.getiMEPinf(obj,data,stimTime,int,rep);
                                                obj.plotiMEP(obj, data, stimTime, rep, h1)
%                                                 obj.plotMEP(obj, data, stimTime, int, rep, h1)
                                                obj.objLoc.sendMEP(obj.MEP.peakToPeak(int,rep),obj.MEP.peakToPeak(int,rep), obj.MEP.duration(int,rep));
                                            else
                                                obj.MEP.peakToPeak(ipi_n,rep)  = 0;
                                                obj.MEP.duration(ipi_n,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    cla(h2);
                                    plot(sum(obj.MEP.iMEP(1:int,:),2),'ok','MarkerSize',10,'MarkerFaceColor','k')
                                    xticks(h2,1:int)
                                    xticklabels(h2,obj.tms_settings.io_int(1:int))
                                    ylabel(h2, 'Number of iMEPs')
                                    title({'Int'; [num2str(int) ' out of ' num2str(numel(obj.tms_settings.io_int))]}, 'FontSize', 12)
                                    drawnow                    
                                    if(int>=length(obj.tms_settings.io_int))
                                        finish = 0;
                                    else
                                        obj.pauseFunc(obj, int, 1);
                                    end
                                    int = int + 1;
                                    if set_back_int
                                        int = int - 1; 
                                        set_back_int = 0;
                                    end
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.imep); mkdir(obj.directories.io); end
            save([obj.directories.imep 'io_' time], 'obj', '-v7.3')
            disp('Saved')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end

        function iMEP_corticalmap(obj)
            % Function to get cortical excitability map
            % # of stimulation points is selected by tms_settings.map_points
            % and one stimulus per location is applied
            obj.check_buffer() %Check if buffer is still recording
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(0,0); %change magventure to 0%
            obj.objMag.flushData();
            obj.dataEEGEMG = []; %make sure that data matrix is empty
            time = input('Type (sp/pp): ','s');
            if exist([obj.directories.imep 'map_' time '.mat'],'file') == 2
                time = input('Time: ','s');
                if exist([obj.directories.imep 'map_' time '.mat'],'file') == 2
                    time = input('File exists already. Redo Time: ','s');
                end
            end
            obj.objMag.flushData();
            finish = 1; %Exit if round>rand_walk_iterations
            round =1; %spot of location in 10x10 grid
            set_back_int = 0;
            amp = input('Choose stimulation amplitude');
            while finish
                if( obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            mag_fbk = obj.check_mag(obj); %check for change in MagVen settings
                            if strcmpi(mag_fbk, 'stimulate') %Manual MagVenture Stimulation
                                while round<=obj.tms_settings.map_points %stays in loop until end of iterations %apply x stimuli at different loations
                                    for rep = 1:25 %25 for random walk should normally be 5 but mixed results..
                                        if rep ~= 1
                                            %ISI of 5 +- 1.25 s
                                            while toc(isiTic) < (6.25-3.75)*rand(1)+3.75, end %500ms for MagVen to change int
                                        end
                                        % Subject has to contract muscle at certain threshold to trigger next step
                                        obj.PTB.displayMessage('Left Hand');
                                        play(obj.audio.prep);
                                        pause(1)
                                        obj.PTB.displayMessage('Contract');
                                        play(obj.audio.contract);
                                        % If subject contracts muscle for
                                        % 3s at X%MVC stimulate
                                        [tmp,isiTic] = obj.stimTMS_act(obj,amp);
                                        if(isempty(tmp))
                                            disp('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.check_buffer()
                                                set_back_int = 1;
                                            else
                                                keyboard;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-obj.ampSettings.SampRate+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            clear trig
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj, obj.tms_settings.addNotchFilt);
                                                obj.getiMEPinf(obj,data,stimTime,rep,round);
                                                obj.plotiMEP(obj,data,stimTime,rep, gca);
%                                                 obj.plotMEP(obj,data,stimTime,rep,round, gca);
                                                obj.objLoc.sendMEP(obj.MEP.peakToPeak(rep,round), obj.MEP.peakToPeak(rep,round), obj.MEP.duration(rep,round));
                                            else
                                                obj.MEP.iMEP(rep,round) = 0;
                                                obj.MEP.duration(rep,round)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                        clc
                                        if(obj.objMag.spObject.BytesAvailable~=0)
                                            obj.objMag.flushData
                                        end
                                        fprintf('Number of iMEPs:  %d \nStimulus %d of %d\n',nansum(obj.MEP.iMEP(1:rep,round)), rep, 5);
                                    end
                                    fprintf('Number of iMEPs:  %d \nPoint %d of %d\n',nansum(obj.MEP.iMEP(:,round)), round, obj.tms_settings.map_points);
                                    round = round + 1;
                                    if round > obj.tms_settings.map_points
                                    finish = 0;
                                    else
                                        %User can decide to go to next
                                        %point or exit
                                        if strcmpi(input('Do you want to go to next stimulation point? (y/n)','s'),'n')
                                            round = obj.tms_settings.map_points + 1;
                                            finish = 0;
                                            break
                                        end
                                    end
                                end
                                %if exited due to empty PP repeat last stimulus and
                                %continue from there
                                if set_back_int == 1
                                    set_back_int = 0;
                                    keyboard
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            magSettings = dec2bin(messageMag(6));
                            if(magSettings(4)) %exit by disabling magventure
%                                 break;
                            end
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            disp('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = []; obj.MEP = []; %keeps file small
            disp('Saving...')
            if ~isdir(obj.directories.imep); mkdir(obj.directories.map); end
            save([obj.directories.imep 'map_' time], 'obj', '-v7.3')
            obj.dataEEGEMG = []; obj.dataEEGEMG_cut = [];
            disp('Finished')
            obj.objMag.turnOnOff('off');
        end        
                
        %% General functions for check of settings
        function release(obj)
            % Function to release PTB, buffer, and hardware
            sca                         %close PTB window
            obj.objMag.disconnect();
            obj.objLoc.disconnect();
            obj.objLPT.release();
            obj.objBuf.release();
            clear instance
        end
        
        function check_buffer(obj)
            % Try to read out data and if not possible restart buffer
            try
                obj.clear_buffer(obj) % empty buffer
                pause(0.1)
                tmp = (obj.objBuf.read_data());
            catch
                disp('Connection not succesfull')
                input('Hit enter to restart')
                try
                    obj.objBuf.release();
                catch
                    disp('Trying to restart')
                end
                obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                obj.objBuf.connect();
                % Check buffer agaim
                tmp = (obj.objBuf.read_data()); %Load some data from buffer
            end
            if(isempty(tmp)) %Buffer not initialized as data wasn't recorded
                % Restart buffer
                disp('Buffer restart')
                obj.objBuf.delete();
                obj.objBuf.release();
                obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                obj.objBuf.connect();
                % Check buffer agaim
                try
                    tmp = (obj.objBuf.read_data()); %Load some data from buffer
                    if(isempty(tmp)) %Buffer still not initialized
                        % Restart buffer
                        disp('Check power packs')
                        if strcmpi(input('Retry (y/n)?','s'),'y')
                            obj.objBuf.delete();
                            obj.objBuf.release();
                            obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                            obj.objBuf.connect();
                        end
                        % Check buffer one last time
                        tmp = (obj.objBuf.read_data()); %Load some data from buffer
                        if(isempty(tmp)) %Buffer still not initialized
                            disp('Buffer still not working!')
                            beep; pause(0.5); beep
                        else
                            disp('Buffer working')
                        end
                    else
                        disp('Buffer working')
                    end
                catch
                    input('Check again')
                end
            else
                disp('Buffer working')
            end
            
            
                
        end
        
        function check_pins(obj)
            % Function to check if set pins for LPT are correct
            % Activate MagVenture
            obj.objMag.turnOnOff('on');
            obj.objMag.changeAmp(50,0); %change magventure to 50%
            obj.wait_ms(300)
            % Try default setting for stimulation
            obj.objLPT.write(obj.stim_pin, obj.lpt_ad) % stimulus and markers
            if ~strcmpi(input('Did your hear the TMS click? (y/n)','s'),'y')
                pin = 1;
                % Next try different stimulation pins(up to 10)
                while pin <= 10
                    % Try to stimulate
                    obj.objLPT.write(pin, obj.lpt_ad) % stimulus and markers
                    if strcmpi(input('Did your hear the TMS click? (y/n)','s'),'y')
                        obj.stim_pin = pin;
                        fprintf('\nChange stimulation pin to %d\n',pin)
                        break
                    else %if no stimulation was applied move to next pin
                        disp('pin: %d',pin)
                        disp('Trying next pin')
                        pin = pin + 1;
                    end
                end
            end
            
            % Try default setting for marker
            pin = 1;
            for i = 1:numel(obj.marker_pin)
                obj.objLPT.write(obj.marker_pin(i), obj.lpt_ad) % stimulus and markers
                if ~strcmpi(input('Did ONLY Localite register the marker? (y/n)','s'),'y')
                    % Next try different stimulation pins (up to 10)
                    while pin <= 10
                        % Try to stimulate
                        obj.objLPT.write(pin, obj.lpt_ad) % stimulus and markers
                        if strcmpi(input('Did ONLY Localite register the marker? (y/n)','s'),'y')
                            obj.marker_pin(i) = pin;
                            fprintf('\nChange marker pin %d to %d\n',i,pin)
                            break
                        else %if no stimulation was applied move to next pin
                            disp('Trying next pin')
                            pin = pin + 1;
                        end
                    end
                end
            end
            
            if strcmpi(input('Did nothing work? (y/n)','s'),'y')
                if strcmpi(input('Do you want to change the LPT address? (y/n)','s'),'y')
                    keyboard
                    obj.lpt_ad          = 'LPT1'; % Parallel port to use for stimulation
                end
            end
            
        end

    end
    
    methods(Static, Access = private)
        %% Functions to get info from data
        function data=filterData(obj,addNotch)
            % Function to filter last second of data
            % Take last second of target muscle and reference muscle
            if ~isfield(obj.tms_settings,'referencemuscle')
                %ExG amplifier used
                data = obj.dataEEGEMG(end-(1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))';
            else
                %DC amplifier used substract referencemuscle to get EMG signal
               data_target = obj.dataEEGEMG(end-(1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; 
               data_ref = obj.dataEEGEMG(end-(1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.referencemuscle ))';
               data = data_target - data_ref;
            end
            % remove low frequency components in the data (dat, FS, filter frequency, N, filter order, type)
            % could be changed to detrend?
            data = ft_preproc_highpassfilter(data, obj.ampSettings.SampRate, 10, 1000,'fir');
            
            if(strcmp(addNotch, 'yes'))
                %remove spectral components in specified frequency band (dat, FS, Frequency band, filter order, type)
                %helpful if noisy signal, but shouldn't be necessary
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [45 55],  1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [95 105], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [145 155], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [195 205], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [245 255], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [295 305], 1000,'fir');
            end
            
        end
        
        function getMEPinf(obj, data, stimTime, int, rep, thresh)
            % Function to get PtP and latency of signal
            % Possibility to set both to 0 if PtP is below thresh
            x_start = obj.tms_settings.mep_start;    %ms; start of MEP search
            x_end   = obj.tms_settings.mep_end;  %ms; end of MEP search
            % Calculate MEP values
            obj.MEP.minAmp(int,rep)     = abs(min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
            obj.MEP.maxAmp(int,rep)     = abs(max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
            obj.MEP.delayMax(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.maxAmp(int,rep),1);
            obj.MEP.delayMin(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.minAmp(int,rep),1);
%             obj.MEP.minAmp(int,rep)     = abs(min(data((0.001*x_start*obj.ampSettings.SampRate):(0.001*x_end*obj.ampSettings.SampRate))));
%             obj.MEP.maxAmp(int,rep)     = abs(max(data((0.001*x_start*obj.ampSettings.SampRate):(0.001*x_end*obj.ampSettings.SampRate))));
%             obj.MEP.delayMax(int,rep)   = find(abs(data(1:stimTime))== obj.MEP.maxAmp(int,rep),1);
%             obj.MEP.delayMin(int,rep)   = find(abs(data(1:stimTime))== obj.MEP.minAmp(int,rep),1);
            obj.MEP.delay(int,rep)      = min([obj.MEP.delayMin(int,rep) obj.MEP.delayMax(int,rep)])/(0.001*obj.ampSettings.SampRate); %ms
            obj.MEP.peakToPeak(int,rep) = obj.MEP.minAmp(int,rep)+obj.MEP.maxAmp(int,rep);
            % MEP threshold gate
            if obj.MEP.peakToPeak(int,rep) < thresh
                obj.MEP.minAmp(int,rep)     = 0;
                obj.MEP.maxAmp(int,rep)     = 0;
                obj.MEP.delayMax(int,rep)   = 0;
                obj.MEP.delayMin(int,rep)   = 0;
                obj.MEP.peakToPeak(int,rep) = 0;
            end
            
        end

        function getiMEPinf_Rest(obj, data, stimTime, int, rep, thresh)
            % Function to get PtP and latency of signal
            % Possibility to set both to 0 if PtP is below thresh
            x_start = obj.tms_settings.mep_start;    %ms; start of MEP search
            x_end   = obj.tms_settings.mep_end;  %ms; end of MEP search
            % Calculate MEP values
            obj.MEP.minAmp(int,rep)     = abs(min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
            obj.MEP.maxAmp(int,rep)     = abs(max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
            obj.MEP.delayMax(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.maxAmp(int,rep),1);
            obj.MEP.delayMin(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.minAmp(int,rep),1);
%             obj.MEP.minAmp(int,rep)     = abs(min(data((0.001*x_start*obj.ampSettings.SampRate):(0.001*x_end*obj.ampSettings.SampRate))));
%             obj.MEP.maxAmp(int,rep)     = abs(max(data((0.001*x_start*obj.ampSettings.SampRate):(0.001*x_end*obj.ampSettings.SampRate))));
%             obj.MEP.delayMax(int,rep)   = find(abs(data(1:stimTime))== obj.MEP.maxAmp(int,rep),1);
%             obj.MEP.delayMin(int,rep)   = find(abs(data(1:stimTime))== obj.MEP.minAmp(int,rep),1);
            obj.MEP.delay(int,rep)      = min([obj.MEP.delayMin(int,rep) obj.MEP.delayMax(int,rep)])/(0.001*obj.ampSettings.SampRate); %ms
            obj.MEP.peakToPeak(int,rep) = obj.MEP.minAmp(int,rep)+obj.MEP.maxAmp(int,rep);
            % MEP threshold gate
            
            obj.MEP.duration(int,rep) = 0; %tmp_duration/(obj.ampSettings.SampRate*0.001);
                
            if obj.MEP.peakToPeak(int,rep) >= thresh %ms
                obj.MEP.iMEP(int,rep)       = 1;
                obj.MEP.peakToPeak(int,rep) = 1; %for further plotting
            else
                obj.MEP.iMEP(int,rep)       = 0;
                obj.MEP.minAmp(int,rep)     = 0;
                obj.MEP.maxAmp(int,rep)     = 0;
                obj.MEP.delayMax(int,rep)   = 0;
                obj.MEP.delayMin(int,rep)   = 0;
                obj.MEP.delay(int,rep)      = 0;
                obj.MEP.peakToPeak(int,rep) = 0; %for further plotting
            end
        end
        
        function getiMEPinf(obj, data, stimTime, int, rep)
            % Function to detect iMEP
            % Poststim EMG has to be >= 5 ms above SD of prestim EMG
            % Calculate baseline mean and SD of prestim EMG
            base_start = -100; %ms
            base_end   = 0; %ms
            base_mean = mean(abs(data(stimTime+(0.001*base_start*obj.ampSettings.SampRate):stimTime+(0.001*base_end*obj.ampSettings.SampRate))));
            base_sd   = std(abs(data(stimTime+(0.001*base_start*obj.ampSettings.SampRate):stimTime+(0.001*base_end*obj.ampSettings.SampRate))));
            % See if datapoint exceeds mean + 2SD
            x_start = obj.tms_settings.mep_start; %ms; start of MEP search
            x_end   = obj.tms_settings.mep_end;   %ms; end of MEP search
            % Calculate how many seconds the postimulus EMG exceeded the
            % prestimulus mean by > 1 SD
            tmp = find(abs(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))> base_mean + 1 * base_sd);
            
            % Find longest consecutive vector
            tmp_rising = diff(tmp);
            tmp_count = 0; tmp_duration = 0;
            for i = 1:numel(tmp_rising)
                if tmp_rising(i) == 1
                    tmp_count = tmp_count + 1;
                else
                    if tmp_count > tmp_duration
                        tmp_count = tmp_count + 1;
                        tmp_duration = tmp_count;
                    end
                    tmp_count = 0;
                end
            end            
            obj.MEP.duration(int,rep) = tmp_duration/(obj.ampSettings.SampRate*0.001);
%             obj.MEP.duration(int,rep) = numel(tmp)/(obj.ampSettings.SampRate*0.001);
            % If duration is above 5ms consider as iMEP (Ziemann 1999) 
            if obj.MEP.duration(int,rep) >= 5 %ms
                obj.MEP.iMEP(int,rep)       = 1;
                obj.MEP.delayMax(int,rep)   = max(tmp);
                obj.MEP.delayMin(int,rep)   = min(tmp);
                obj.MEP.delay(int,rep)      = min(tmp)/(0.001*obj.ampSettings.SampRate); %ms
                obj.MEP.peakToPeak(int,rep) = 1; %for further plotting
            else
                obj.MEP.iMEP(int,rep) = 0;
                obj.MEP.peakToPeak(int,rep) = 0; %for further plotting
            end            
        end
        
        function [io_fit, io_fit_int] = fit(obj, io_curve)
            if(obj.tms_settings.numbFitParam == 3)
                [~,~,io_fit, io_fit_int]=sigm_fit(obj.tms_settings.io_int',io_curve,[0 NaN NaN NaN],[],0);
            elseif(obj.tms_settings.numbFitParam == 4)
                [~,~,io_fit, io_fit_int]=sigm_fit(obj.tms_settings.io_int',io_curve,[NaN NaN NaN NaN],[],0);
            end
        end
       
        %% Functions for plotting
        function plotMEP(obj, data, stimTime, int, run, axHandle)   
            %Plot MEP from x_start to x_end
            x_start = -50;
            x_end = obj.tms_settings.mep_end + 10;
            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
            % Plot data
            cla(axHandle)
            plot(axHandle,x, data(stimTime + (0.001*x_start*obj.ampSettings.SampRate):stimTime +(0.001*x_end*obj.ampSettings.SampRate)), 'k', 'LineWidth', 2)
            hold(axHandle)
            %Plot marker of stimTime
            plot(axHandle, [0 0], ... 
                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'g')
            y_range = [-150 150];
            % Plot left and right marker of PtP
            if obj.MEP.peakToPeak(int,run) ~= 0
                plot(axHandle, [obj.MEP.delayMin(int,run)/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMin(int,run)/(0.001*obj.ampSettings.SampRate)], ...
                    [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                plot(axHandle, [obj.MEP.delayMax(int,run)/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMax(int,run)/(0.001*obj.ampSettings.SampRate)], ...
                    [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                try
                    y_range = [-obj.MEP.minAmp(int,run) obj.MEP.maxAmp(int,run)];
                catch
                    y_range = [-150 150];
                end
            end
            hold(axHandle, 'off')
            ylim(axHandle, [min(y_range) max(y_range)])
            xlim(axHandle, [x_start x_end])
            title(axHandle, ['Stimuli number: ' num2str(run)], 'FontSize', 12)
            xlabel(axHandle, 'Time [ms]')
            ylabel(axHandle, 'Amplitude [\muV]')
            drawnow
            % Create this variable for plotting latter on
            obj.MEPepochs(int, run, :) = data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate));
            clc
        end

        function plotiMEP(obj, data, stimTime, trial, axHandle)   
            %Plot MEP from x_start to x_end
            x_start = -50;
            x_end = obj.tms_settings.mep_end + 10;
            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
            % Plot data
            cla(axHandle)
            plot(axHandle,x, abs(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))), 'k', 'LineWidth', 2)
            hold(axHandle)
            %Plot marker of stimTime
            plot(axHandle, [0 0], ... 
                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'g')
            % Plot mean and std of baseline
            base_mean = nanmean(abs(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime)));
            base_sd   = nanstd(abs(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime)));
            plot(axHandle,[x(1) x(end)], [base_mean base_mean], 'r');
            plot(axHandle,[x(1) x(end)], [(base_mean+1*base_sd) (base_mean+1*base_sd)], 'g');
            xlim([x(1) x(end)])
            % Figure properties
            try
                ylim(axHandle, [0 max(abs(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))))])
            catch
                ylim(axHandle, [0 max(abs(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime)))])
            end
            xlim(axHandle, [x_start x_end])
            title(axHandle, ['Stimuli number: ' num2str(trial)], 'FontSize', 12)
            xlabel(axHandle, 'Time [ms]')
            ylabel(axHandle, 'Amplitude [\muV]')
            hold(axHandle, 'off')
            drawnow
            clc
        end
        
        function plotInpOutCurv(obj,io_curve,io_fit,io_fit_int)
            % Plot the cross product and the turning point
            figure
            plot(obj.tms_settings.io_int,io_curve, '*r')
            hold on
            plot(io_fit_int, io_fit)
            ylim([0 max(io_curve)+20])
            xlim([min(obj.tms_settings.io_int)-1 max(obj.tms_settings.io_int)+1])
            legend({'row data' 'fitted data'})
            title('IO curve', 'FontSize', 16)
            xlabel('Intensity [%]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
        end
        
        function plotEEG(obj, stimTime, run, axHandle, ch)   
            %Plot MEP from x_start to x_end ms
            x_start = -100;
            x_end = 100;
            
            cla(axHandle)
            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
            y = obj.dataEEGEMG(end-obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames, ch))';
            % Plot data
            plot(axHandle,x, detrend(y(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))), 'k', 'LineWidth', 2)
            hold(axHandle)
            %Plot marker of stimTime
            plot(axHandle, [0 0], ... 
                [min(y(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(y(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'g')
            y_range = [-200 200];
            hold(axHandle, 'off')
            ylim(axHandle, [min(y_range) max(y_range)])
            xlim(axHandle, [x_start x_end])
            title(axHandle, ['Stimuli number: ' num2str(run)], 'FontSize', 12)
            xlabel(axHandle, 'Time [ms]')
            ylabel(axHandle, 'Amplitude [\muV]')
            drawnow
            clc
        end
        
        %% Functions for user feedback
        function [finish]=addIntIO(obj)
            % possibility to add intensity to io curve if no plateau was
            % reached
            if(strcmp(input('Add intensities? y/n \n', 's'), 'y'))
                obj.tms_settings.io_int        = [obj.InpOutCurvInt floor(obj.MT*(max(obj.IO_Settings.IOrange)+0.1))];
                obj.tms_settings.io_range  = [obj.IO_Settings.IOrange max(obj.IO_Settings.IOrange)+0.1];
                finish            = 1;
                obj.pauseFunc(obj, 0, max(obj.tms_settings.io_range)+0.05);
            else
                finish            = 0;
            end
        end

        function pauseFunc(obj, int, currentInt)
            % Pause stimulation protocol until TMS stimulus was triggered
            % manually
            playBeep = 1;
            obj.objMag.changeAmp(0,0);
            while obj.objMag.spObject.BytesAvailable~=0
                obj.objMag.flushData();
            end
            stopLoop = tic;
            while toc(stopLoop)<5
                pause(0.5)
                clc
                if int == -1
                    fprintf('ISI IS SET TO: %d.\n Press COIL button to pause\n Time to press is over in %d \n',currentInt, round(5-toc(stopLoop)));
                elseif int==0
                    fprintf('AMPLITUDE IS SET TO: %d.\n Press COIL button to pause\n Time to press is over in %d \n',currentInt, round(5-toc(stopLoop)));
                else
                    fprintf('AMPLITUDE IS SET TO: %d.\n Press COIL button to pause\n Time to press is over in %d \n',obj.tms_settings.io_int(int+1), round(5-toc(stopLoop)));
                end
                
                if(obj.objMag.spObject.BytesAvailable~=0)
                    obj.objMag.flushData();
                    while obj.objMag.spObject.BytesAvailable==0
                        
                        if(playBeep)
                            beep
                            playBeep = 0;
                        end
                        clc
                        fprintf('Press COIL button to proceed\n');
                        stopLoop = tic;
                        pause(0.5)
                    end
                    while obj.objMag.spObject.BytesAvailable~=0
                        obj.objMag.flushData();
                    end
                end
            end
            
        end
                
        function [finish, amp]=add_intensity_rmt()
            if(strcmpi(input('Add intensities? y/n \n', 's'), 'y'))
                amp     = input('Choose new intensity: ');
                finish  = 1;
            else
                finish  = 0;
                amp     = 0;
            end
        end
        
        function [finish, rep]=add_stim(obj)
            % Possiiblity to add more stimuli to the hotspot search
            inp = input('Add more stimuli?:  y/n \n', 's');
            switch inp
                case 'n'
                    finish = 0;
                    rep =  0;
                    disp('Finished!!!')
                case 'y'
                    finish = 1;
                    rep =  1;
                    obj.tms_settings.hotspot_nb_stim = ...
                        input('How many simuli should be applied? \n');
                    close all
                    figure
            end
        end
        
        %% Functions to control
        function clear_buffer(obj)
           obj.objBuf.read_data(); 
        end
        
        function wait_ms(ms)
            startTicTime = tic;
            while toc(startTicTime) < ms/1000
            end
        end
        
        function add_marker(obj,nb)
            obj.objLPT.write(obj.marker_pin(nb), obj.lpt_ad) %marker
        end
                    
        function mag_fbk = check_mag(obj)
            messageMag = obj.objMag.getData()';
            obj.objLoc.sendData(messageMag);
            if(messageMag(1,3)==2) %Manual MagVenture Stimulation
                mag_fbk = 'stimulate';
            elseif(messageMag(1,3)==1) && messageMag(4) ~= 0 %manual change of intensity
                mag_fbk = 'int_change';
            else
                mag_fbk = 'awaiting_input';
            end
        end
        
        %% Functions for stimulation
        function [data,isiTic] = stimTMS_rest(obj, amp) 
            %stimulates with specified intensity if target muscle is at rest
            obj.objMag.changeAmp(amp,0);    % change MagVen to desired stim int
            obj.wait_ms(500)                %wait for mag vent to change amp            
            data_tmp = [];                  %data matrix
            % only stimulate if no preactivation is detected
            while 1
                tmp = double((obj.objBuf.read_data())/10); % read out data
                data_tmp = cat(1,data_tmp,tmp); %append to data matrix
                if size(data_tmp,1) > 0.5*obj.ampSettings.SampRate %cut data matrix to 500ms
                    data_tmp = data_tmp(end-0.5*obj.ampSettings.SampRate:end,:);
                end
                if size(data_tmp,1) > (0.1*obj.ampSettings.SampRate)
                    if ~isfield(obj.tms_settings,'referencemuscle')
                        %ExG amplifier used
                        tmp = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                    else
                        %DC amplifier used substract referencemuscle to get EMG signal
                        tmp_target = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                        tmp_ref = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.referencemuscle ))'; %take only last 100ms of target muscle
                        tmp = tmp_target - tmp_ref;
                    end
                    tmp = detrend(tmp);                             %detrend data for further analysis
                    obj.PTB.rest_fbk(max(abs(tmp)), 20) %visual fdbk of motor activation
                    % only stimulate if EMG is between +-20µV (e.g. Takemi 2013 et al)
                    if max(abs(tmp)) < 20
                        obj.objLPT.write(obj.stim_pin, obj.lpt_ad)                 % stimulus and markers
                        isiTic = tic; %Set timer for ISI
                        obj.wait_ms(600)                            % time for post stimulus data
                        data = [data_tmp;double((obj.objBuf.read_data())/10)]; % read out data
                        obj.objMag.changeAmp(0,0);                  % change MagVen back to 0
                        break
                    else %preactivation, don't stimulate
                        disp(['Muscle preactivated: Max EMG = ' num2str(max(abs(tmp))) 'µV'])
                    end
                end
                clear tmp data
            end
        end
        
        function [data,isiTic] = stimPP_rest(obj, amp,idi)
            %stimulates with specified intensity if target muscle is at rest
            obj.objMag.changeAmp(amp,0);    % change MagVen to desired stim int
            obj.wait_ms(500)                %wait for mag vent to change amp
            data_tmp = [];                  %data matrix
            % only stimulate if no preactivation is detected
            while 1
                tmp = double((obj.objBuf.read_data())/10); % read out data
                data_tmp = cat(1,data_tmp,tmp); %append to data matrix
                if size(data_tmp,1) > 0.5*obj.ampSettings.SampRate %cut data matrix to 500ms
                    data_tmp = data_tmp(end-0.5*obj.ampSettings.SampRate:end,:);
                end
                if size(data_tmp,1) > (0.1*obj.ampSettings.SampRate)
                    %tmp = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                    if ~isfield(obj.tms_settings,'referencemuscle')
                        %ExG amplifier used
                        tmp = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                    else
                        %DC amplifier used substract referencemuscle to get EMG signal
                        tmp_target = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                        tmp_ref = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.referencemuscle ))'; %take only last 100ms of target muscle
                        tmp = tmp_target - tmp_ref;
                    end
                    tmp = detrend(tmp);                             %detrend data for further analysis
                    obj.PTB.rest_fbk(max(abs(tmp)), 20) %visual fdbk of motor activation
                    % only stimulate if EMG is between +-20µV (e.g. Takemi 2013 et al)
                    if max(abs(tmp)) < 20
%                         keyboard % following scipt has to be checked
                        obj.objLPT.write(obj.stim_pin, obj.lpt_ad)                 % stimulus and markers
                        obj.wait_ms(idi-.5) % -.5 as the pin has to be opend and closed again (takes .5 ms)
                        obj.objLPT.write(obj.stim_pin, obj.lpt_ad)                 % stimulus and markers
                        
                        
%                         io64(obj.objLPT.con, obj.objLPT.address2, obj.stim_pin);   %Stimulus 1
%                         pause_ms(.5)
%                         io64(obj.objLPT.con, obj.objLPT.address2, 0);
%                         pause_ms(obj.tms_settings.idi(run))
%                         io64(obj.objLPT.con, obj.objLPT.address2, 3);   %Stimulus 2
%                         pause_ms(.5)
%                         io64(obj.objLPT.con, obj.objLPT.address2, 0);
                        
                        isiTic = tic; %Set timer for ISI
                        obj.wait_ms(600)                            % time for post stimulus data
                        data = [data_tmp;double((obj.objBuf.read_data())/10)]; % read out data
                        obj.objMag.changeAmp(0,0);                  % change MagVen back to 0
                        break
                    else %preactivation, don't stimulate
                        disp(['Muscle preactivated: Max EMG = ' num2str(max(abs(tmp))) 'µV'])
                    end
                end
                clear tmp data
            end
        end
        
        function [data,isiTic] = stimTMS_act(obj, amp)
            % stimulate with specified intensity 
            % while Subject has to contract muscle at certain 
            % threshold to trigger stimulus
            obj.objMag.changeAmp(amp,0); % Change Stim Intensity
            obj.wait_ms(500)             % Time for MagVen to change Intensity
            data_tmp = [];                  %data matrix
            contr_nb = 0; % Set count of contraction to 0
            contr_stim = round((12-8)*rand(1)+8); %[10 15] (upper-lower limit)*randNumber+lower limit
            obj.clear_buffer(obj)   %empty buffer
            step_tic = tic;         % start step timer
            while 1 %Stimulate if MVC +- range is reached
                if toc(step_tic) >= 0.2 %take last 200ms
                    tmp = double((obj.objBuf.read_data())/10); % read out data
                    data_tmp = cat(1,data_tmp,tmp); %append to data matrix
                    clear tmp
                    if size(data_tmp,1) > 0.5*obj.ampSettings.SampRate %cut data matrix to 500ms pre stim
                        data_tmp = data_tmp(end-0.5*obj.ampSettings.SampRate:end,:);
                    end
                    % Take last 200 ms of target muscle
                    if size(data_tmp,1) > 0.2*obj.ampSettings.SampRate
                        % tmp = data_tmp(end-0.2*obj.ampSettings.SampRate:end,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                        if ~isfield(obj.tms_settings,'referencemuscle')
                            %ExG amplifier used
                            tmp = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                        else
                            %DC amplifier used substract referencemuscle to get EMG signal
                            tmp_target = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                            tmp_ref = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.referencemuscle ))'; %take only last 100ms of target muscle
                            tmp = tmp_target - tmp_ref;
                        end
                        
                    else
                        %tmp = data_tmp(:,ismember(obj.ampSettings.ChanNames,obj.tms_settings.targetmuscle))';
                        if ~isfield(obj.tms_settings,'referencemuscle')
                            %ExG amplifier used
                            tmp = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                        else
                            %DC amplifier used substract referencemuscle to get EMG signal
                            tmp_target = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.targetmuscle ))'; %take only last 100ms of target muscle
                            tmp_ref = data_tmp(end-(0.1*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.tms_settings.referencemuscle ))'; %take only last 100ms of target muscle
                            tmp = tmp_target - tmp_ref;
                        end
                    end
                    tmp = detrend(tmp);     % detrend data
                    contr_force = rms(tmp); %measure of current contraction force
                    %visual fdbk of contraction force
                    % (current contraction force, MVC, threshold,
                    % threshold_range,zoom_factor)
                    obj.PTB.m_contr(contr_force, obj.mvc.mean, obj.tms_settings.mvc_percentage, obj.tms_settings.mvc_range,1.5) %visual fdbk of contraction
                    clear tmp
                    %Check of ratio of
                    %contraction-MVC is within range
                    if  contr_force/obj.mvc.mean > obj.tms_settings.mvc_percentage-obj.tms_settings.mvc_range ...
                            && contr_force/obj.mvc.mean < obj.tms_settings.mvc_percentage+obj.tms_settings.mvc_range
                        contr_nb = contr_nb + 1;
                    else %Set count back to 0 as continous contraction
                        contr_nb = 0;
                    end
                    if contr_nb == contr_stim %correct continuous contraction for 2-3s (nb8 to 11*200ms)
                        obj.objLPT.write(obj.stim_pin, obj.lpt_ad) %stimulus and marker
                        isiTic = tic; %Set timer for ISI
                        break % Exit MVC ratio measurement
                    end
                    step_tic = tic; %reset timer
                end
            end
            obj.wait_ms(600) %600ms pst stim time for buffer to fill up
            tmp = double((obj.objBuf.read_data())/10); %get data
            data = cat(1,data_tmp, tmp); %merge pre and post stim data
            play(obj.audio.relax);
        end
                                            
    end
    
    methods(Static)
        
        function obj = lz_TMS_v5(dataSub, projectPath, ampSettings, tms_settings)
            % Initialisation
            set_path_vars;
            
            % Acquisition device
            obj.ampSettings    = ampSettings;
            obj.objBuf         = BV_BufferReader(ampSettings.ChanNumb, ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
            obj.objBuf.connect();
            
            % ParallelPort
            obj.objLPT = LPTControl.getInstance();
            obj.objLPT.connect(tms_settings.lpt_port{1},tms_settings.lpt_port{2});
            
            % Magventure
            obj.objMag = interMag.getInstance();
            obj.objMag.connect(tms_settings.mag_port)
            
            % Localite
            obj.objLoc = interLoc.getInstance();
            obj.objLoc.connect(tms_settings.loc_port)
            
            % Psych tool box for Visual Feedback
            obj.PTB                 = PsychTB_Feedback_v2.getInstance();
            obj.PTB.openWindow(obj.ptb_screen); %the screen has to be specified as it is not the last
            clc
            
            % Sound files for feedback
            [a, b] = audioread('Prep.wav');
            obj.audio.prep = audioplayer(a,b);
%             [a, b] = audioread('Contract.wav');
            [a, b] = audioread('Los_laut.wav');
            obj.audio.contract = audioplayer(a,b);
            [a, b] = audioread('Relax.wav');
            obj.audio.relax = audioplayer(a,b);
            clear a b
            
            % Variables subject            
            obj.dataSub = dataSub;
            
            % General MEP settings
            obj.tms_settings = tms_settings;
            
            % Save directories
            obj.directories.hs          = [projectPath '\data\' dataSub.initials '\hotspot\'];
            obj.directories.mvc         = [projectPath '\data\' dataSub.initials '\MVC\'];
            obj.directories.r_EEG       = [projectPath '\data\' dataSub.initials '\r_EEG\'];
            obj.directories.a_EMG       = [projectPath '\data\' dataSub.initials '\a_EMG\'];
            obj.directories.mt          = [projectPath '\data\' dataSub.initials '\MT\'];
            obj.directories.mep         = [projectPath '\data\' dataSub.initials '\MEP\'];
            obj.directories.io          = [projectPath '\data\' dataSub.initials '\IO\'];
            obj.directories.map         = [projectPath '\data\' dataSub.initials '\MAP\'];
            obj.directories.lat_current = [projectPath '\data\' dataSub.initials '\latencies\'];
            obj.directories.pp          = [projectPath '\data\' dataSub.initials '\ppTMS\'];
            obj.directories.imep        = [projectPath '\data\' dataSub.initials '\iMEP\'];
            obj.directories.iTMS        = [projectPath '\data\' dataSub.initials '\iTMS_Stimulation\'];
        end
        
        function ins = getInstance(dataSub, projectPath, ampSettings, tms_settings)
            dbstop if error
            persistent instance;
            
            if( ~strcmpi(class(instance), 'lz_TMS_v5') )
                instance = lz_TMS_v5(dataSub, projectPath, ampSettings, tms_settings);
            end
            
            ins = instance;
        end
        
    end
end