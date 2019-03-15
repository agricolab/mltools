%{
                           interMag.m  -  description
                               -------------------

    Facility             : Functional and Restorative Neurosurgery
                             Neurosurgical University Hospital
                                 Eberhard Karls University
    Author               : Vladislav Royter
    Email                : vladislav.royter@uni-tuebingen.de
    Created on           : 16.01.2015
    Description          : Serial communication interface for the Magventure system
%}

classdef interMag < handle
    
    properties
        isConnected
        spObject
        crcTable
    end
    
    methods(Access = public)
        function connect(obj, comPort, varargin)
            if(~obj.isConnected)
                obj.spObject = serial(comPort,'BaudRate',38400);
                set(obj.spObject,'DataBits',8,'Parity','none','FlowControl','none', 'StopBits', 1)
                fopen(obj.spObject);
                obj.isConnected = 1;
            end
        end
        
        function changeAmp(obj, amp1, amp2)
            
            startFlag = hex2dec('FE');
            length    = 3;
            command   = 1;
            message   = [command amp1 amp2];
            CRC8      = obj.calcCRC8(obj, message);
            endFlag   = hex2dec('FF');
            
            packet    = [startFlag length message CRC8 endFlag]';
            
            if(obj.isConnected)
                fwrite(obj.spObject,packet)
            end
            
        end
        
        function turnOnOff(obj, onOff)
            
            startFlag = hex2dec('FE');
            length    = 2;
            command   = 2;
            
            switch onOff
                case 'off'
                    onOff = 0;
                case 'on'
                    onOff = 1;
            end
            
            message   = [command onOff];
            CRC8      = obj.calcCRC8(obj, message);
            endFlag   = hex2dec('FF');
            
            packet    = [startFlag length message CRC8 endFlag]';
            
            if(obj.isConnected)
                fwrite(obj.spObject,packet)
            end
            
        end
        
        function singleTrig(obj)
            
            startFlag = hex2dec('FE');
            length    = 2;
            command   = 3;
            trig      = 1;
            message   = [command trig];
            
            CRC8      = obj.calcCRC8(obj, message);
            endFlag   = hex2dec('FF');
            
            packet    = [startFlag length message CRC8 endFlag]';
            
            if(obj.isConnected)
                fwrite(obj.spObject,packet)
            end
            
        end
        
        function startTrain(obj)
            
            startFlag = hex2dec('FE');
            length    = 1;
            command   = 4;
            CRC8      = obj.calcCRC8(obj, command);
            endFlag   = hex2dec('FF');
            
            packet    = [startFlag length command CRC8 endFlag]';
            
            if(obj.isConnected)
                fwrite(obj.spObject,packet)
            end
            
        end
        
        
        function getStatus(obj)
            
            startFlag = hex2dec('FE');
            length    = 1;
            command   = 5; %0
            CRC8      = 63; %63
            endFlag   = hex2dec('FF');
            
            packet    = [startFlag length command CRC8 endFlag]';
            
            if(obj.isConnected)
                fwrite(obj.spObject,packet)
            end
            
        end
        
        function data=getData(obj)
            
            data = fread(obj.spObject, obj.spObject.BytesAvailable,'uchar');
            
        end
        
        function sendData(obj, data)
           fwrite(obj.spObject,data)
        end
        
        function flushData(obj)
%             if(obj.spObject.BytesAvailable~=0)
%                  fread(obj.spObject, obj.spObject.BytesAvailable,'uchar');     
%             end
            flushinput(obj.spObject);
            flushoutput(obj.spObject);
        end
        
        function disconnect(obj, varargin)
            if(obj.isConnected)
                fclose(obj.spObject);
            end
        end
        
    end
    
    methods(Static)
        function ins = getInstance()
            persistent instance;
            
            if( ~strcmpi(class(instance), 'interMag') )
                instance = interMag();
            end
            
            ins = instance;
        end
        
    end
    
    
    methods(Static, Access = private)
        function obj = interMag()
            obj.isConnected   = 0;
            obj.spObject      = 0;
            obj.crcTable      = [0, 94, 188, 226, 97, 63, 221, 131, 194, 156, 126, 32, 163, 253, 31, 65, ...
                157, 195, 33, 127, 252, 162, 64, 30, 95, 1, 227, 189, 62, 96, 130, 220,  ...
                35, 125, 159, 193, 66, 28, 254, 160, 225, 191, 93, 3, 128, 222, 60, 98,  ...
                190, 224, 2, 92, 223, 129, 99, 61, 124, 34, 192, 158, 29, 67, 161, 255,  ...
                70, 24, 250, 164, 39, 121, 155, 197, 132, 218, 56, 102, 229, 187, 89, 7, ...
                219, 133, 103, 57, 186, 228, 6, 88, 25, 71, 165, 251, 120, 38, 196, 154, ...
                101, 59, 217, 135, 4, 90, 184, 230, 167, 249, 27, 69, 198, 152, 122, 36, ...
                248, 166, 68, 26, 153, 199, 37, 123, 58, 100, 134, 216, 91, 5, 231, 185, ...
                140, 210, 48, 110, 237, 179, 81, 15, 78, 16, 242, 172, 47, 113, 147, 205, ...
                17, 79, 173, 243, 112, 46, 204, 146, 211, 141, 111, 49, 178, 236, 14, 80, ...
                175, 241, 19, 77, 206, 144, 114, 44, 109, 51, 209, 143, 12, 82, 176, 238, ...
                50, 108, 142, 208, 83, 13, 239, 177, 240, 174, 76, 18, 145, 207, 45, 115, ...
                202, 148, 118, 40, 171, 245, 23, 73, 8, 86, 180, 234, 105, 55, 213, 139, ...
                87, 9, 235, 181, 54, 104, 138, 212, 149, 203, 41, 119, 244, 170, 72, 22, ...
                233, 183, 85, 11, 136, 214, 52, 106, 43, 117, 151, 201, 74, 20, 246, 168, ...
                116, 42, 200, 150, 21, 75, 169, 247, 182, 232, 10, 84, 215, 137, 107, 53];
            
        end
        
        function crc=calcCRC8(obj, Data)
            
            crc         = 0;
            
            for i=1:size(Data,2)
                crc = obj.crcTable(1,bitand(bitxor(crc, Data(1,i)), 255)+1);
            end
            
        end
        
        function filledByte=fillByte(Data)
            
            tmp = dec2bin(Data);
            for i = 1:size(tmp,2)
                filledByte(1,i)   = str2num(tmp(1,i));
            end, clear tmp
            filledByte = num2str(padarray(filledByte', 8-size(filledByte,2), 'pre'));
            
        end
    end
end