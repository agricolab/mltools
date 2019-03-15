%{
                           lz_TMS_v2.m  -  description
                               -------------------

    Facility             : Functional and Restorative Neurosurgery
                             Neurosurgical University Hospital
                                 Eberhard Karls University
    Author               : Vladislav Royter adapted by Lukas Ziegler
    Email                : ziegler.swv@gmail.com
    Created on           : 22/04/2016
    Description          : Assessment of hotspot, motor threshold, input
                           output and SICI/LICI curves
    Additional info      : LPT2 = Marker and stimulus (always buffer marker)
                            2:   stimulus
                            3:   stimulus + localite
%}

classdef lz_TMS_v2 < handle
    
    properties
        dataEEGEMG
        dataEEGEMG_cut
        objMag
        objBuf
        objLoc
        objLPT
        MEP
        mep1
        corticalmap_settings
        tep_settings
        corticalmap_response
        interneuron
        InpOutCurvInt
        InpOutCurv
        MEPepochs
        dataSub
        Directories
        InpOutCurvFit
        InpOutCurvFitInt
        MT
        si_1mv
        fitParam
        ampSettings
        hotSpotSettings
        IO_Settings
        MEP_Settings
        int_s1
    end
    
    methods(Access = public)
        
        function release(obj)
            obj.objMag.disconnect();
            obj.objLoc.disconnect();
            obj.objLPT.release();
            obj.objBuf.delete();
            obj.objBuf.release();
        end
        
        function hotSpot(obj)
            dbstop if error
            clc
            obj.objMag.flushData();
            obj.dataEEGEMG = [];
            int = 1;
            rep    = 1;
            quit   = 0;
            finish = 1;
            amp = input('Choose amplitude: ');
            obj.objMag.changeAmp(0,0);
            while finish
                while rep<=obj.hotSpotSettings.Iterations
                    if( obj.objMag.spObject.BytesAvailable~=0)
                        switch obj.objMag.spObject.BytesAvailable
                            case 8
                                fprintf('Current amplitude: %d \n',amp)
                                messageMag = obj.objMag.getData()';
                                obj.objLoc.sendData(messageMag);
                                if(messageMag(1,3)==2)
                                    obj.objMag.changeAmp(amp,0);
                                    pause_ms(500)
                                    obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                    pause(1)
                                    obj.objMag.changeAmp(0,0);
                                    tmp = double((obj.objBuf.read_data())/10);
                                    if(isempty(tmp))
                                        display('Power pack empty!!!')
                                        break;
                                    else
                                        obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                        clear tmp
                                    end
                                    if(~isempty(obj.dataEEGEMG))
                                        trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                        stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                        if(stimTime > 40 && ~isnan(stimTime))
                                            data = obj.filterData(obj, obj.hotSpotSettings.addNotchFilt);
                                            obj.getMEPinf(obj,data,stimTime,int,rep, 'MEP');
                                            obj.plotMEP(obj,data,stimTime,int,rep, gca, 'MEP');
                                            obj.objLoc.sendMEP(obj.MEP.maxAmp(int,rep)+obj.MEP.minAmp(int,rep),obj.MEP.maxAmp(int,rep), obj.MEP.delay(int,rep));
                                        else
                                            obj.MEP.minAmp(int,rep)  = 0;
                                            obj.MEP.maxAmp(int,rep)  = 0;
                                            obj.MEP.delay(int,rep)   = 0;
                                        end
                                        
                                    end
                                    if(obj.objMag.spObject.BytesAvailable~=0)
                                        obj.objMag.flushData
                                    end
                                    obj.objMag.getStatus()
                                    rep = rep + 1;
                                elseif(messageMag(1,3)==1)
                                    clc
                                    if messageMag(4) ~= 0
                                        amp = input('Choose new stimulation intensity: ');
                                        clc
                                        obj.objMag.changeAmp(0,0);
                                        fprintf('Current stimulation intensity: %d \n',amp)
                                    end
                                end
                            case 16
                                messageMag = obj.objMag.getData()';
                                obj.objLoc.sendData(messageMag);
                                magSettings = dec2bin(messageMag(6));
                                if(magSettings(4))
                                    quit = 1;
                                    break;
                                end
                            case 24
                                messageMag = obj.objMag.getData()';
                                obj.objLoc.sendData(messageMag);
                            otherwise
%                                 display('otherwise')
                                messageMag = obj.objMag.getData()';
                                messageMag = messageMag(end-7:end);
                                obj.objLoc.sendData(messageMag);
                        end
                    end
                end
                if(~quit || ~isempty(obj.dataEEGEMG))
                    [~, sortMEPs]  = sort(obj.MEP.peakToPeak);
                    var       = 0;
                    clear tmp1 tmp2
                    figure,
                    if(sum(sortMEPs) > 0)
                        for MEPnumb = 1:size(sortMEPs, 2)
                            x_start = -50;
                            x_end = obj.MEP_Settings.end + 10;
                            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
                            if(MEPnumb/9==round((MEPnumb/9)))
                                var          = MEPnumb-1;
                                figure
                            end
                            subplot(3,3,MEPnumb-var)
                            plot(x,squeeze(obj.MEPepochs(int,sortMEPs(int,MEPnumb),:)),'k', 'LineWidth', 2)
                            hold on
                            plot([obj.MEP.delayMin(int,sortMEPs(int,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMin(int,sortMEPs(1,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                            plot([obj.MEP.delayMax(int,sortMEPs(int,MEPnumb))/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMax(int,sortMEPs(int,MEPnumb))/(0.001*obj.ampSettings.SampRate)], ...
                                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                            hold off
                            y_range = [-obj.MEP.minAmp(int,sortMEPs(int,MEPnumb)) obj.MEP.maxAmp(int,sortMEPs(int,MEPnumb))];
                            if min(y_range) == 0; y_range = [-100 100]; end
                            ylim([min(y_range) max(y_range)])
                            clear y_range
                            xlim([x_start x_end])
                            title(sprintf('MEP number: %d\n PtP: %d\nMaxPeak: %d, Latency: %d',sortMEPs(int,MEPnumb), ...
                                round(obj.MEP.peakToPeak(sortMEPs(int,MEPnumb))), round(obj.MEP.maxAmp(sortMEPs(int,MEPnumb))), ...
                                round(obj.MEP.delay(sortMEPs(int,MEPnumb)))))
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
                    obj.MEPepochs = [];
                    save([obj.Directories.HotSpot num2str(rep)], 'obj', '-v7.3')
                    obj.MEP = [];
                    obj.dataEEGEMG = [];
                end
                [finish, rep] = obj.getInput(obj);
            end
        end
        
        function motorThreshManual(obj)
            obj.objMag.flushData();
            obj.dataEEGEMG = [];
            run = 1;
            finish = 1;
            exit_run = 1; 
            amp = input('Choose amplitude: ');
            obj.objMag.changeAmp(0,0);
            while finish %general exit
                if( obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2)  %change in current in magventure
                                while finish %exit from run x
                                    obj.objMag.changeAmp(amp,0);
                                    pause_ms(500)
                                    display(['Current intensity: ' num2str(amp)])
                                    while exit_run %exit earlier if there are at least 5 MEPs above threshold
                                        for rep = 1:obj.hotSpotSettings.iterations_rmt
                                            if rep ~= 1 %ISI of 5 +- 1.25 s
                                                pause(4 -1.25 +2.5*rand(1))
                                            end
                                            display(['Rep: ' num2str(rep)])
                                            obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                            pause(1)
                                            tmp = (obj.objBuf.read_data()/10);
                                            if(isempty(tmp))
                                                display('Power pack empty!!!')
                                                break;
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj, obj.hotSpotSettings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, 'MEP');
                                                    obj.plotMEP(obj,data,stimTime,run,rep, gca, 'MEP');
                                                    obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                                else
                                                    obj.MEP.minAmp(run,rep)  = 0;
                                                    obj.MEP.maxAmp(run,rep)  = 0;
                                                    obj.MEP.delay(run,rep)   = 0;
                                                end
                                            end
                                            %Exit earlier if 5 MEPs detected or 5 can't be reached
                                            tmp = sum(double(obj.MEP.peakToPeak(run,:)>obj.MEP_Settings.thresholdMaxAmp));
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
                                            x_end = obj.MEP_Settings.end + 10;
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
                                            peakToPeak(run,:)>obj.MEP_Settings.thresholdMaxAmp))) ' out of 10' ] ...
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
                                    else display('Finished')
                                    end
                                end
                            elseif(messageMag(1,3)==1) %change of amplitude via magventure
                                clc
                                if messageMag(4) ~= 0   %not a change to 0 as this is induced by the program
                                    amp = input('Choose new stimulation intensity: ');
                                    clc
                                    obj.objMag.changeAmp(0,0);
                                    fprintf('Current stimulation intensity: %d \n',amp)
                                end
                            end
                        case 16
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            magSettings = dec2bin(messageMag(6));
                            if(magSettings(4))
                                break;
                            end
                        case 24
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                        otherwise
                            display('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = [];
            save([obj.Directories.motorTresh], 'obj', '-v7.3')
            obj.MEP = [];
            obj.dataEEGEMG = [];
        end
                    
        function get_opt_ipi(obj)
            obj.dataEEGEMG = [];
            time = input('Time: ','s');
            if exist([obj.Directories.opt_ipi 'ipi_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            obj.objMag.flushData();
            finish  = 1;
            ipi_n = 1;
            set_back_int = 0;
            obj.interneuron.ipi = obj.interneuron.ipi(randperm(numel(obj.interneuron.ipi))); %random order of IPIs
            for j = 1:numel(obj.interneuron.ipi) %show order of ISIs
                fprintf('ISI %d: %1.1d \n', j, obj.interneuron.ipi(j))
            end
            if strcmpi(input('Continue (Enter/n): ','s'),'n') %Continue after protocol is set on Magventure
                finish=0;
            end
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2)
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(floor(1.1*obj.MT),0);
                                    pause(1)
                                    for rep = 1:10  %apply 10 stimuli for each IPI
                                        if rep ~= 1 %ISI of 5 +- 1.25 s
                                            pause(4 -1.25 +2.5*rand(1))
                                        end
                                        fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.interneuron.ipi(ipi_n))
                                        obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                        if(obj.objMag.spObject.BytesAvailable~=0)
                                            messageMag = obj.objMag.getData()';
                                            obj.objLoc.sendData(messageMag);
                                        end
                                        pause(1)
                                        tmp = double((obj.objBuf.read_data())/10);
                                        if(isempty(tmp))
                                            display('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut  = obj.dataEEGEMG;
                                                obj.dataEEGEMG      = [];
                                                obj.objBuf.delete();
                                                obj.objBuf.release();
                                                obj.objBuf = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                obj.objBuf.connect();
                                                set_back_int = 1;
                                                break
                                            else break;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            stimTime     = stimTime + floor(0.001*obj.interneuron.ipi(ipi_n)*obj.ampSettings.SampRate); %so that the MEP triggered by the S2 is analyzed
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,ipi_n,rep, 'MEP');
                                                obj.plotMEP(obj, data, stimTime, ipi_n, rep, h1, 'MEP')
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
                                    boxplot(obj.MEP.peakToPeak(1:ipi_n,:)', obj.interneuron.ipi(1:ipi_n))
                                    xlabel(h2, 'IPI [ms]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Opt IPI'; [num2str(ipi_n) ' out of ' num2str(numel(obj.interneuron.ipi))]}, 'FontSize', 12)
                                    drawnow
                                    if(ipi_n<length(obj.interneuron.ipi))
                                        if set_back_int;
                                            ipi_n = ipi_n - 1;
                                            set_back_int = 0;
                                        end
                                        ipi_n = ipi_n + 1;
                                        obj.pauseFunc(obj, -1, obj.interneuron.ipi(ipi_n));
                                    else finish = 0;
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
            plot(obj.interneuron.ipi,nanmean(obj.MEP.peakToPeak,2),'+')
            title('IPI MEPs', 'FontSize', 16)
            xlabel('ISI [ms]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
            
            obj.MEPepochs = [];
            save([obj.Directories.opt_ipi 'ipi_' time], 'obj', '-v7.3')
            obj.MEP = [];
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end

        function get_opt_idi(obj)
            obj.dataEEGEMG = [];
            time = input('Time: ','s');
            if exist([obj.Directories.opt_ipi 'idi_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            obj.objMag.flushData();
            finish  = 1;
            run = 1;
            set_back_int = 0;
            obj.interneuron.idi = obj.interneuron.idi(randperm(numel(obj.interneuron.idi))); %random order of IPIs
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2)
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(floor(1.1*obj.MT),0);
                                    pause(1)
                                    % Single Pulse
                                    if obj.interneuron.idi(run) == 0
                                        for rep = 1:10  %apply 10 SP stimuli
                                            if rep ~= 1 %ISI of 5 +- 1.25 s
                                                pause(4 -1.25 +2.5*rand(1))
                                            end
                                            fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.interneuron.idi(run))
                                            obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                            if(obj.objMag.spObject.BytesAvailable~=0)
                                                messageMag = obj.objMag.getData()';
                                                obj.objLoc.sendData(messageMag);
                                            end
                                            pause(1)
                                            tmp = double((obj.objBuf.read_data())/10);
                                            if(isempty(tmp))
                                                display('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.objBuf.delete();
                                                    obj.objBuf.release();
                                                    obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                    obj.objBuf.connect();
                                                    set_back_int = 1;
                                                    break
                                                else break;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
%                                                 stimTime     = stimTime + floor(0.001*obj.interneuron.idi(run)*obj.ampSettings.SampRate); %so that the MEP triggered by the S2 is analyzed
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, 'MEP');
                                                    obj.plotMEP(obj, data, stimTime, run, rep, h1, 'MEP')
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
                                            if rep ~= 1 %ISI of 5 +- 1.25 s
                                                pause(4 -1.25 +2.5*rand(1))
                                            end
                                            fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.interneuron.idi(run))
                                            io64(obj.objLPT.con, obj.objLPT.address2, 3);   %Stimulus 1
                                            pause_ms(.5)
                                            io64(obj.objLPT.con, obj.objLPT.address2, 0);
                                            pause_ms(obj.interneuron.idi(run)-.5)
                                            io64(obj.objLPT.con, obj.objLPT.address2, 3);   %Stimulus 2
                                            pause_ms(.5)
                                            io64(obj.objLPT.con, obj.objLPT.address2, 0);
                                            if(obj.objMag.spObject.BytesAvailable~=0)
                                                messageMag = obj.objMag.getData()';
                                                obj.objLoc.sendData(messageMag);
                                            end
                                            pause(1)
                                            tmp = double((obj.objBuf.read_data())/10);
                                            if(isempty(tmp))
                                                display('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.objBuf.delete();
                                                    obj.objBuf.release();
                                                    obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                    obj.objBuf.connect();
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    set_back_int = 1;
                                                    break
                                                else break;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
%                                                 stimTime     = stimTime + floor(0.001*obj.interneuron.idi(run)*obj.ampSettings.SampRate); %so that the MEP triggered by the S2 is analyzed
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, 'MEP');
                                                    obj.plotMEP(obj, data, stimTime, run, rep, h1, 'MEP')
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
                                    boxplot(obj.MEP.peakToPeak(1:run,:)', obj.interneuron.idi(1:run))
                                    xlabel(h2, 'IPI [ms]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Opt IPI'; [num2str(run) ' out of ' num2str(numel(obj.interneuron.idi))]}, 'FontSize', 12)
                                    drawnow
                                    if(run<length(obj.interneuron.idi))
                                        if set_back_int;
                                            run = run - 1;
                                            set_back_int = 0;
                                        end
                                        run = run + 1;
                                        obj.pauseFunc(obj, -1, obj.interneuron.idi(run));
                                    else finish = 0;
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
            plot(obj.interneuron.idi,nanmean(obj.MEP.peakToPeak,2),'+')
            title('IPI MEPs', 'FontSize', 16)
            xlabel('ISI [ms]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
            
            obj.MEPepochs = [];
            save([obj.Directories.opt_idi 'idi_' time], 'obj', '-v7.3')
            obj.MEP = [];
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end
        
        function get_opt_idi_125(obj)
            obj.dataEEGEMG = [];
            time = input('Time: ','s');
            if exist([obj.Directories.opt_ipi 'idi_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            obj.objMag.flushData();
            finish  = 1;
            run = 1;
            set_back_int = 0;
            obj.interneuron.idi = obj.interneuron.idi(randperm(numel(obj.interneuron.idi))); %random order of IPIs
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2)
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(floor(1.25*obj.MT),0);
                                    pause(1)
                                    % Single Pulse
                                    if obj.interneuron.idi(run) == 0
                                        for rep = 1:10  %apply 10 SP stimuli
                                            if rep ~= 1 %ISI of 5 +- 1.25 s
                                                pause(4 -1.25 +2.5*rand(1))
                                            end
                                            fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.interneuron.idi(run))
                                            obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                            if(obj.objMag.spObject.BytesAvailable~=0)
                                                messageMag = obj.objMag.getData()';
                                                obj.objLoc.sendData(messageMag);
                                            end
                                            pause(1)
                                            tmp = double((obj.objBuf.read_data())/10);
                                            if(isempty(tmp))
                                                display('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    obj.objBuf.delete();
                                                    obj.objBuf.release();
                                                    obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                    obj.objBuf.connect();
                                                    set_back_int = 1;
                                                    break
                                                else break;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, 'MEP');
                                                    obj.plotMEP(obj, data, stimTime, run, rep, h1, 'MEP')
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
                                            if rep ~= 1 %ISI of 5 +- 1.25 s
                                                pause(4 -1.25 +2.5*rand(1))
                                            end
                                            fprintf('Rep: %d \n IPI: %3.1f \n', rep, obj.interneuron.idi(run))
                                            io64(obj.objLPT.con, obj.objLPT.address2, 3);   %Stimulus 1
                                            pause_ms(.5)
                                            io64(obj.objLPT.con, obj.objLPT.address2, 0);
                                            pause_ms(obj.interneuron.idi(run)-.5)
                                            io64(obj.objLPT.con, obj.objLPT.address2, 3);   %Stimulus 2
                                            pause_ms(.5)
                                            io64(obj.objLPT.con, obj.objLPT.address2, 0);
                                            if(obj.objMag.spObject.BytesAvailable~=0)
                                                messageMag = obj.objMag.getData()';
                                                obj.objLoc.sendData(messageMag);
                                            end
                                            pause(1)
                                            tmp = double((obj.objBuf.read_data())/10);
                                            if(isempty(tmp))
                                                display('Power pack empty!!!')
                                                if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                    obj.objBuf.delete();
                                                    obj.objBuf.release();
                                                    obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                    obj.objBuf.connect();
                                                    obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                    obj.dataEEGEMG = [];
                                                    set_back_int = 1;
                                                    break
                                                else break;
                                                end
                                            else
                                                obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                                clear tmp
                                            end
                                            if(~isempty(obj.dataEEGEMG))
                                                trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                                stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
%                                                 stimTime     = stimTime + floor(0.001*obj.interneuron.idi(run)*obj.ampSettings.SampRate); %so that the MEP triggered by the S2 is analyzed
                                                if isempty(stimTime); stimTime = NaN; end
                                                if(stimTime > 40 && ~isnan(stimTime))
                                                    data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                    obj.getMEPinf(obj,data,stimTime,run,rep, 'MEP');
                                                    obj.plotMEP(obj, data, stimTime, run, rep, h1, 'MEP')
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
                                    boxplot(obj.MEP.peakToPeak(1:run,:)', obj.interneuron.idi(1:run))
                                    xlabel(h2, 'IPI [ms]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Opt IPI'; [num2str(run) ' out of ' num2str(numel(obj.interneuron.idi))]}, 'FontSize', 12)
                                    drawnow
                                    if(run<length(obj.interneuron.idi))
                                        if set_back_int;
                                            run = run - 1;
                                            set_back_int = 0;
                                        end
                                        run = run + 1;
                                        obj.pauseFunc(obj, -1, obj.interneuron.idi(run));
                                    else finish = 0;
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
            plot(nanmean(obj.MEP.peakToPeak,2), obj.interneuron.idi)
            title('IPI MEPs', 'FontSize', 16)
            xlabel('IDI [ms]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
            
            obj.MEPepochs = [];
            save([obj.Directories.opt_idi 'idi_' time], 'obj', '-v7.3')
            obj.MEP = [];
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            obj.objMag.turnOnOff('off');
        end

        function getInpOutCurve(obj)
            obj.dataEEGEMG = [];
            time = input('Time: ','s');
            if exist([obj.Directories.InpOutCurve '_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            obj.objMag.flushData();
            finish  = 1;
            int     = 1;
            set_back_int = 0;
            obj.InpOutCurvInt = obj.InpOutCurvInt(randperm(numel(obj.InpOutCurvInt))); %random order of intensities
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2)
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(obj.InpOutCurvInt(1,int),0);
                                    pause(1)
                                    display(['Current intensity: ' num2str(int) ' ' num2str(obj.InpOutCurvInt(1,int)) '%'])
                                    for rep = 1:10
                                        if rep ~= 1 %ISI of 5 +- 1.25 s
                                            pause(4 -1.25 +2.5*rand(1)) 
                                        end
                                        display(['Rep: ' num2str(rep)])
                                        obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                        if(obj.objMag.spObject.BytesAvailable~=0)
                                            messageMag = obj.objMag.getData()';
                                            obj.objLoc.sendData(messageMag);
                                        end
                                        pause(1)
                                        tmp = double((obj.objBuf.read_data())/10);
                                        if(isempty(tmp))
                                            display('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.objBuf.delete();
                                                obj.objBuf.release();
                                                obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                obj.objBuf.connect();
                                                set_back_int = 1;
                                                break
                                            else break;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,int,rep, 'MEP');
                                                obj.plotMEP(obj, data, stimTime, int, rep, h1, 'MEP')
                                                obj.objLoc.sendMEP(obj.MEP.maxAmp(int,rep)+obj.MEP.minAmp(int,rep),obj.MEP.maxAmp(int,rep), obj.MEP.delay(int,rep));
                                            else
                                                obj.MEP.minAmp(int,rep)  = 0;
                                                obj.MEP.maxAmp(int,rep)  = 0;
                                                obj.MEP.delay(int,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    obj.InpOutCurv(1,int)     =  mean(obj.MEP.peakToPeak(int,:));
                                    cla(h2);
                                    boxplot(obj.MEP.peakToPeak(1:int,:)', obj.InpOutCurvInt(1:int))
                                    xlabel(h2, 'Intensity [%]')
                                    ylabel(h2, 'MEP PeakToPeak [\muV]')
                                    title({'Input Output Curve'; [num2str(int) ' out of ' num2str(size(obj.InpOutCurvInt,2))]}, 'FontSize', 12)
                                    drawnow                    
                                    if(int>=length(obj.InpOutCurvInt))
                                        obj.fit(obj, obj.IO_Settings.numbFitParam);
                                        obj.plotInpOutCurv(obj);
                                        [finish] = obj.addIntIO(obj);
                                        figure
                                        h1=subplot(2,1,1);
                                        h2=subplot(2,1,2);
                                    else
                                        obj.pauseFunc(obj, int, 1);
                                    end
                                    int = int + 1;
                                    if set_back_int; 
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
                            display('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = [];
            save([obj.Directories.InpOutCurve '_' time], 'obj', '-v7.3')
            obj.MEP = [];
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            obj.InpOutCurv = [];
            obj.InpOutCurvInt = [];
            obj.InpOutCurvFitInt = [];
            obj.objMag.changeAmp(0,0)
        end
        
        function getTEP(obj)
            obj.dataEEGEMG = [];
            time = input('Time: ','s');
            if exist([obj.Directories.TEP '_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            obj.objMag.flushData();
            finish  = 1;
            run     = 1;
            set_back_int = 0;
            while finish
                if(obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2)
                                h1=subplot(2,1,1);
                                h2=subplot(2,1,2);
                                while finish
                                    obj.objMag.changeAmp(floor(1.1*obj.MT),0);
                                    pause(1)
                                    for rep = 1:obj.tep_settings.iterations
                                        if rep ~= 1 %ISI of 5 +- 1.25 s
                                            pause(4 -1.25 +2.5*rand(1)) 
                                        end
                                        display(['Rep: ' num2str(rep)])
                                        obj.objLPT.write(3, 'LPT2') %stimulus and markers
                                        if(obj.objMag.spObject.BytesAvailable~=0)
                                            messageMag = obj.objMag.getData()';
                                            obj.objLoc.sendData(messageMag);
                                        end
                                        pause(1)
                                        tmp = double((obj.objBuf.read_data())/10);
                                        if(isempty(tmp)) %Data wasn't recorded
                                            display('Power pack empty!!!')
                                            if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                                obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                                obj.dataEEGEMG = [];
                                                obj.objBuf.delete();
                                                obj.objBuf.release();
                                                obj.objBuf         = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                                obj.objBuf.connect();
                                                set_back_int = 1;
                                                break
                                            else break;
                                            end
                                        else
                                            obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp); %save buffer data
                                            clear tmp
                                        end
                                        if(~isempty(obj.dataEEGEMG))
                                            trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                            stimTime     = find(trig, 1, 'last'); %Last entry in marker channel
                                            if isempty(stimTime); stimTime = NaN; end
                                            if(stimTime > 40 && ~isnan(stimTime))
                                                data = obj.filterData(obj,obj.IO_Settings.addNotchFilt);
                                                obj.getMEPinf(obj,data,stimTime,run,rep, 'MEP');
                                                obj.plotMEP(obj, data, stimTime, run, rep, h1, 'MEP')
                                                obj.plotEEG(obj, stimTime, rep, h2, obj.tep_settings.eeg_ch)
                                                obj.objLoc.sendMEP(obj.MEP.maxAmp(run,rep)+obj.MEP.minAmp(run,rep),obj.MEP.maxAmp(run,rep), obj.MEP.delay(run,rep));
                                            else
                                                obj.MEP.minAmp(run,rep)  = 0;
                                                obj.MEP.maxAmp(run,rep)  = 0;
                                                obj.MEP.delay(run,rep)   = 0;
                                                obj.objLoc.sendMEP(0,0,0);
                                            end
                                        end
                                    end
                                    if run >= obj.tep_settings.runs
                                        finish = 0;
                                    else
                                        obj.pauseFunc(obj,0,floor(1.1*obj.MT));
                                    end
                                    
                                    if set_back_int == 1; %repeat last stimulus as it wasn't recorded
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
                            display('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = [];
            display('Saving...')
            save([obj.Directories.TEP '_' time], 'obj', '-v7.3')
            display('Saved')
            obj.MEP = [];
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            obj.objMag.changeAmp(0,0)
        end
                        
        function get_corticalmap_v2(obj)
            obj.dataEEGEMG = [];
            time = input('Time: ','s');
            if exist([obj.Directories.corticalmap '_' time '.mat'],'file') == 2
                time = input('File exists already. Redo Time: ','s');
            end
            dbstop if error
            pause(1)
            obj.objMag.flushData();
            finish = 1; %Exit if round>rand_walk_iterations
            round =1; %spot of location in 10x10 grid
            set_back_int = 0;
            obj.objMag.changeAmp(0,0);
            while finish
                if( obj.objMag.spObject.BytesAvailable~=0)
                    switch obj.objMag.spObject.BytesAvailable
                        case 8
                            messageMag = obj.objMag.getData()';
                            obj.objLoc.sendData(messageMag);
                            if(messageMag(1,3)==2) %test location; stim triggered by hand
                                obj.objMag.changeAmp(floor(1.1*obj.MT),0);
                                pause(1)
                                while round<=obj.corticalmap_settings.rand_walk_iterations %stays in loop until end of iterations %apply x stimuli at different loations
                                    if round ~= 1 %pause between stimuli of 5 +-25%
                                        pause(2 -1 +rand(1))
                                    end
                                    obj.objLPT.write(3, 'LPT2') %stimulus wo localite marker
                                    pause(1)
                                    tmp = double((obj.objBuf.read_data())/10);
                                    if(isempty(tmp))
                                        display('Power pack empty!!!')
                                        if strcmpi(input('did you change the powerpacks (y/n)?','s'),'y')
                                            obj.dataEEGEMG_cut = obj.dataEEGEMG;
                                            obj.dataEEGEMG = [];
                                            obj.objBuf.delete();
                                            obj.objBuf.release();
                                            obj.objBuf = BV_BufferReader(obj.ampSettings.ChanNumb, obj.ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
                                            obj.objBuf.connect();
                                            set_back_int = 1;
                                            break %not perfect yet
                                        else break;
                                        end
                                    else
                                        obj.dataEEGEMG = cat(1,obj.dataEEGEMG, tmp);
                                        clear tmp
                                    end
                                    if(~isempty(obj.dataEEGEMG))
                                        trig         = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate)+1:end,obj.ampSettings.ChanNumb+1)'; %last 2 seconds of marker channel
                                        stimTime     = find(trig, 1, 'last'); %Last entry of marker in marker channel
                                        if(stimTime > 40 && ~isnan(stimTime))
                                            data = obj.filterData(obj, obj.hotSpotSettings.addNotchFilt);
                                            obj.getMEPinf(obj,data,stimTime,1,round, 'MEP_map_v2'); %at 3rd rep set loc marker
                                            obj.plotMEP(obj,data,stimTime,1,round, gca, 'MEP');
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
                                    fprintf('MEP peak-to-peak:  %.2f \nStimulus %d of %i\n',nanmean(obj.MEP.peakToPeak(1,round)), round, obj.corticalmap_settings.rand_walk_iterations);
%                                     obj.objMag.changeAmp(0,0);
                                    round = round + 1;
                                    if round > obj.corticalmap_settings.rand_walk_iterations
                                    finish = 0;
                                    end
                                end
                                %if exited due to empty PP repeat last stimulus and
                                %continue from there
                                if set_back_int == 1;
                                    set_back_int = 0;
                                    pause(7) %not perfect
                                end
                                
                            elseif(messageMag(1,3)==1)
                                clc
                                display(['Current amplitude: ' num2str(floor(1.1*obj.MT))])
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
                            display('otherwise')
                            messageMag = obj.objMag.getData()';
                            messageMag = messageMag(end-7:end);
                            obj.objLoc.sendData(messageMag);
                    end
                end
            end
            obj.MEPepochs = [];
            display('Saving...')
            save([obj.Directories.corticalmap '_' time], 'obj', '-v7.3')
            obj.MEP = [];
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            clc
            display('Finished')
            obj.objMag.changeAmp(0,0)
        end


    end
    
    methods(Static, Access = private)
        
        function data=filterData(obj,addNotch)
            dbstop if error
            if isempty(obj.MEP_Settings.referencemuscle)
                % Take last 2 seconds of target muscle
                data = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.MEP_Settings.targetmuscle ))';
            else
               data_target = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.MEP_Settings.targetmuscle ))'; 
               data_ref = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, obj.MEP_Settings.referencemuscle ))';
               data = data_target - data_ref;
            end
            % remove low frequency components in the data (dat, FS, filter frequency, N, filter order, type)
            data = ft_preproc_highpassfilter(data, obj.ampSettings.SampRate, 10, 1000,'fir');
            %remove spectral components in specified frequency band (dat, FS, Frequency band, filter order, type)
%             data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [45 55],  1000,'fir');
            
            if(strcmp(addNotch, 'yes'))
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [95 105], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [145 155], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [195 205], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [245 255], 1000,'fir');
                data = ft_preproc_bandstopfilter(data, obj.ampSettings.SampRate, [295 305], 1000,'fir');
            end
            
        end
        
        function getMEPinf(obj, data, stimTime, int, rep, type)   %latency = 5 ms therefore check between x_start - x_end ms
            x_start = obj.MEP_Settings.start;    %ms; start of MEP search
            x_end   = obj.MEP_Settings.end;  %ms; end of MEP search
            if strcmpi(type, 'MEP')   %MEP with thresholdMaxAmp (50µV)
                obj.MEP.minAmp(int,rep)     = abs(min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.MEP.maxAmp(int,rep)     = abs(max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.MEP.delayMax(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.maxAmp(int,rep),1);
                obj.MEP.delayMin(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.minAmp(int,rep),1);
                obj.MEP.delay(int,rep)      = min([obj.MEP.delayMin(int,rep) obj.MEP.delayMax(int,rep)])/(0.001*obj.ampSettings.SampRate); %ms
                obj.MEP.peakToPeak(int,rep) = obj.MEP.minAmp(int,rep)+obj.MEP.maxAmp(int,rep);
                if obj.MEP.peakToPeak(int,rep) < obj.MEP_Settings.thresholdMaxAmp
                    obj.MEP.minAmp(int,rep)     = 0;
                    obj.MEP.maxAmp(int,rep)     = 0;
                    obj.MEP.delayMax(int,rep)   = 0;
                    obj.MEP.delayMin(int,rep)   = 0;
                    obj.MEP.peakToPeak(int,rep) = 0;
                end
            elseif strcmpi(type, 'MEP1')    %MEP with threshold_si (1mV)
                obj.mep1.minAmp(int,rep)     = abs(min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.mep1.maxAmp(int,rep)     = abs(max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.mep1.delayMax(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.mep1.maxAmp(int,rep),1);
                obj.mep1.delayMin(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.mep1.minAmp(int,rep),1);
                obj.mep1.delay(int,rep)      = min([obj.mep1.delayMin(int,rep) obj.mep1.delayMax(int,rep)])/(0.001*obj.ampSettings.SampRate); %ms
                obj.mep1.peakToPeak(int,rep) = obj.mep1.minAmp(int,rep)+obj.mep1.maxAmp(int,rep);
                if obj.mep1.peakToPeak(int,rep) < obj.MEP_Settings.threshold_si
                    obj.mep1.minAmp(int,rep)     = 0;
                    obj.mep1.maxAmp(int,rep)     = 0;
                    obj.mep1.delayMax(int,rep)   = 0;
                    obj.mep1.delayMin(int,rep)   = 0;
                    obj.mep1.peakToPeak(int,rep) = 0;
                end
            elseif strcmpi(type, 'MEP_map')    %MEP with threshold_si (1mV)
                obj.MEP.minAmp(int,rep)     = abs(min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.MEP.maxAmp(int,rep)     = abs(max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.MEP.delayMax(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.maxAmp(int,rep),1);
                obj.MEP.delayMin(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.minAmp(int,rep),1);
                obj.MEP.delay(int,rep)      = min([obj.MEP.delayMin(int,rep) obj.MEP.delayMax(int,rep)])/(0.001*obj.ampSettings.SampRate); %ms
                obj.MEP.peakToPeak(int,rep) = obj.MEP.minAmp(int,rep)+obj.MEP.maxAmp(int,rep);
                %upon last stimulus send information to localite
                if rep == 3
                    tmp    = nanmean(obj.MEP.peakToPeak(int,:));
                    obj.objLPT.write(1, 'LPT2') % loc marker
                    if ~(tmp < obj.MEP_Settings.thresholdMaxAmp)
                        obj.objLoc.sendMEP(tmp, obj.MEP.minAmp(int,1), obj.MEP.delay(int,1));
                    end
                    clear tmp
                end
            elseif strcmpi(type, 'MEP_map_v2')    %MEP with threshold_si (1mV)
                obj.MEP.minAmp(int,rep)     = abs(min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.MEP.maxAmp(int,rep)     = abs(max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate))));
                obj.MEP.delayMax(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.maxAmp(int,rep),1);
                obj.MEP.delayMin(int,rep)   = find(abs(data(stimTime:stimTime+(0.001*x_end*obj.ampSettings.SampRate)))==obj.MEP.minAmp(int,rep),1);
                obj.MEP.delay(int,rep)      = min([obj.MEP.delayMin(int,rep) obj.MEP.delayMax(int,rep)])/(0.001*obj.ampSettings.SampRate); %ms
                obj.MEP.peakToPeak(int,rep) = obj.MEP.minAmp(int,rep)+obj.MEP.maxAmp(int,rep);
            end
        end
        
        function plotMEP(obj, data, stimTime, int, run, axHandle, type)   %Plot MEP from x_start to x_end ms
            x_start = -50;
            x_end = obj.MEP_Settings.end + 10;
            
            cla(axHandle)
            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
            % Plot data
            plot(axHandle,x, data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)), 'k', 'LineWidth', 2)
            hold(axHandle)
            %Plot marker of stimTime
            plot(axHandle, [0 0], ... 
                [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'g')
            y_range = [-150 150];
            % Plot marker of PtP
            if strcmpi(type, 'MEP')
                if obj.MEP.peakToPeak(int,run) ~= 0
                    plot(axHandle, [obj.MEP.delayMin(int,run)/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMin(int,run)/(0.001*obj.ampSettings.SampRate)], ...
                        [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                    plot(axHandle, [obj.MEP.delayMax(int,run)/(0.001*obj.ampSettings.SampRate) obj.MEP.delayMax(int,run)/(0.001*obj.ampSettings.SampRate)], ...
                        [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                    y_range = [-obj.MEP.minAmp(int,run) obj.MEP.maxAmp(int,run)];
                end
            elseif strcmpi(type, 'MEP1')
                if obj.mep1.peakToPeak(int,run) ~= 0
                    plot(axHandle, [obj.mep1.delayMin(int,run)/(0.001*obj.ampSettings.SampRate) obj.mep1.delayMin(int,run)/(0.001*obj.ampSettings.SampRate)], ...
                        [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                    plot(axHandle, [obj.mep1.delayMax(int,run)/(0.001*obj.ampSettings.SampRate) obj.mep1.delayMax(int,run)/(0.001*obj.ampSettings.SampRate)], ...
                        [min(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))  max(data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)))], 'r')
                    y_range = [-obj.mep1.minAmp(int,run) obj.mep1.maxAmp(int,run)];
                end
            end
            hold(axHandle, 'off')
            ylim(axHandle, [min(y_range) max(y_range)])
            xlim(axHandle, [x_start x_end])
            title(axHandle, ['Stimuli number: ' num2str(run)], 'FontSize', 12)
            xlabel(axHandle, 'Time [ms]')
            ylabel(axHandle, 'Amplitude [\muV]')
            drawnow
            obj.MEPepochs(int, run, :) = data(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate));
            clc
        end
        
        function plotEEG(obj, stimTime, run, axHandle, ch)   %Plot MEP from x_start to x_end ms
            x_start = -100;
            x_end = 100;
            
            cla(axHandle)
            x = (x_start:1000/obj.ampSettings.SampRate:x_end);
            y = obj.dataEEGEMG(end-(2*obj.ampSettings.SampRate):end,ismember(obj.ampSettings.ChanNames, ch))';
            % Plot data
            plot(axHandle,x, y(stimTime+(0.001*x_start*obj.ampSettings.SampRate):stimTime+(0.001*x_end*obj.ampSettings.SampRate)), 'k', 'LineWidth', 2)
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
                
        function fit(obj, numberParam)
            if(numberParam == 3)
                [obj.fitParam,~,obj.InpOutCurvFit, obj.InpOutCurvFitInt]=sigm_fit(obj.InpOutCurvInt',obj.InpOutCurv,[0 NaN NaN NaN],[],0);
            elseif(numberParam == 4)
                [obj.fitParam,~,obj.InpOutCurvFit, obj.InpOutCurvFitInt]=sigm_fit(obj.InpOutCurvInt',obj.InpOutCurv,[NaN NaN NaN NaN],[],0);
            end
        end
        
        function plotInpOutCurv(obj)
            % Plot the cross product and the turning point
            figure
            plot(obj.InpOutCurvInt,obj.InpOutCurv, '*r')
            hold on
            plot(obj.InpOutCurvFitInt, obj.InpOutCurvFit)
            ylim([0 max(obj.InpOutCurv)+20])
            xlim([min(obj.InpOutCurvInt)-1 max(obj.InpOutCurvInt)+1])
            legend({'row data' 'fitted data'})
            title('IO curve', 'FontSize', 16)
            xlabel('Intensity [%]')
            ylabel('MEP PeakToPeak [\muV]')
            drawnow
        end
                                
        function pauseFunc(obj, int, currentInt)
            dbstop if error
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
                    fprintf('AMPLITUDE IS SET TO: %d.\n Press COIL button to pause\n Time to press is over in %d \n',obj.InpOutCurvInt(int+1), round(5-toc(stopLoop)));
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
        
        function [finish, rep]=getInput(obj)
            inp = input('Proceed?:  y/n \n', 's');
            switch inp
                case 'n'
                    finish = 0;
                    rep =  0;
                    display('Finished!!!')
                case 'y'
                    finish = 1;
                    rep =  1;
                    obj.hotSpotSettings.Iterations = ...
                        input('How many simuli should be applied? \n');
%                     if(strcmp('y', input('Close all figures? y/n \n', 's')))
                        close all
%                     end
                    figure
            end
        end
        
        function [finish, amp]=add_intensity_rmt()
            if(strcmpi(input('Add intensities? y/n \n', 's'), 'y'));
                amp     = input('Choose new intensity: ');
                finish  = 1;
            else
                finish  = 0;
                amp     = 0;
            end
        end
        
        function [finish]=addIntIO(obj)
            if(strcmp(input('Add intensities? y/n \n', 's'), 'y'));
                obj.InpOutCurvInt        = [obj.InpOutCurvInt floor(obj.MT*(max(obj.IO_Settings.IOrange)+0.1))];
                obj.IO_Settings.IOrange  = [obj.IO_Settings.IOrange max(obj.IO_Settings.IOrange)+0.1];
                finish            = 1;
                obj.pauseFunc(obj, 0, max(obj.IO_Settings.IOrange)+0.05);
            else
                finish            = 0;
            end
        end
        
    end
    
    methods(Static)
        
        function  obj = lz_TMS_v2(dataSub, projectPath, ampSettings, ...
                hotSpotSettings,... 
                IO_Settings, MEP_Settings, interneuron, corticalmap_settings, tep_settings)
            % Initialisation
            set_path_vars; % Really important to execute this line!!!
            
            % ParallelPort
            obj.objLPT = LPTControl.getInstance();
            obj.objLPT.connect();
            
            % Magventure
            obj.objMag = interMag.getInstance();
            obj.objMag.connect('COM15')
            
            % Localite
            obj.objLoc = interLoc.getInstance();
            obj.objLoc.connect('COM16') % COM10
            
            % Acquisition devices
            obj.ampSettings    = ampSettings;
            obj.objBuf         = BV_BufferReader(ampSettings.ChanNumb, ampSettings.SampRate, 'get_marker', '1', 'resolution', '0');
            obj.objBuf.connect();
            
            % Variables subject            
            obj.dataSub = dataSub;
            
            % General MEP settings
            obj.MEP_Settings = MEP_Settings;
            
            % MT settings 5 out of 10
            obj.hotSpotSettings = hotSpotSettings;
            
            % Cortical Map Settings (Send localite pTp info)
            obj.corticalmap_settings = corticalmap_settings;
            
            % Settings fot the IO curve
            obj.IO_Settings = IO_Settings;
            
            %Settings for the SICI/LICI curve
            obj.interneuron = interneuron;
            
            obj.tep_settings = tep_settings;
            
            % Variables for MEP
            obj.dataEEGEMG = [];
            obj.dataEEGEMG_cut = [];
            obj.InpOutCurvInt = [];
            obj.MEP = 0;
            obj.mep1 = 0;
            obj.InpOutCurv = 0;
            obj.InpOutCurvFitInt = [];
            obj.corticalmap_response = 0;
            obj.MEPepochs      = [];
            obj.int_s1 = [];
            obj.Directories.HotSpot      = [projectPath '\data\' dataSub.initials '\HotSpot\HotSpot'];
            obj.Directories.motorTresh   = [projectPath '\data\' dataSub.initials '\RMT\RMT'];
            obj.Directories.InpOutCurve         = [projectPath '\data\' dataSub.initials '\InpOutCurve\InpOutCurve'];
%             obj.Directories.synaptic_plasticity = [projectPath '\data\' dataSub.initials '\synaptic_plasticity\synaptic_plasticity'];
            obj.Directories.opt_idi             = [projectPath '\data\' dataSub.initials '\opt_interval\'];
            obj.Directories.opt_ipi             = [projectPath '\data\' dataSub.initials '\opt_interval\'];
            obj.Directories.corticalmap         = [projectPath '\data\' dataSub.initials '\corticalmap\corticalmap'];
            obj.Directories.TEP                 = [projectPath '\data\' dataSub.initials '\TEP\TEP'];
            obj.MT               = [];
            obj.si_1mv             = [];
            obj.fitParam         = [];
            if(~isdir([projectPath '\data\' dataSub.initials '\InpOutCurve']))
                mkdir([projectPath '\data\' dataSub.initials '\HotSpot'])
                mkdir([projectPath '\data\' dataSub.initials '\RMT'])
                mkdir([projectPath '\data\' dataSub.initials '\InpOutCurve'])
%                 mkdir([projectPath '\data\' dataSub.initials '\synaptic_plasticity'])
                mkdir([projectPath '\data\' dataSub.initials '\corticalmap'])
                mkdir([projectPath '\data\' dataSub.initials '\opt_interval'])
                mkdir([projectPath '\data\' dataSub.initials '\TEP'])
            end
            
        end
        
        function ins = getInstance(dataSub, projectPath, ampSettings, hotSpotSettings, ...
                IO_Settings, MEP_Settings, interneuron, corticalmap_settings,tep_settings)
            persistent instance;
            
            if( ~strcmpi(class(instance), 'lz_TMS_v2') )
                instance = lz_TMS_v2(dataSub, projectPath, ampSettings, hotSpotSettings, ...
                    IO_Settings, MEP_Settings, interneuron, corticalmap_settings,tep_settings);
            end
            
            ins = instance;
        end
        
    end
end