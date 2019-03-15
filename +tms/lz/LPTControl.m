classdef LPTControl < handle
    properties
        is_connected
        address1
        address2
        
        con;
        status;
    end
    
    methods(Access = public)
        function connect(obj, varargin)
            if( ~obj.is_connected )
                obj.con    = io64;
                obj.status = io64(obj.con);
            
                if( ~isempty(varargin) )
                    obj.address1 = hex2dec( varargin{1} );
                    obj.address2 = hex2dec( varargin{2} );
                else
                    obj.address1  = hex2dec('DFE8'); % I/O range LPT1     
                    obj.address2  = hex2dec('DFF8'); % I/O range LPT2
                end
            end
        end
        
        function write(obj, val, PPNumber)
            switch PPNumber
                case 'LPT1', address = obj.address1;
                case 'LPT2', address = obj.address2;
            end
            io64(obj.con,address, val);               % stimulate - close the port
            time = tic; while toc(time) < 0.0005; end   % wait before opening the port again
            io64(obj.con,address, 0);                 % get ready for next stimulation - open the port
        end
        
        function val = read(obj)
            val = io64(obj.con, obj.address1);
        end
        
        function release(obj)
            try
                obj.is_connected = 0;
                clear io64;
                obj.con = [];
            catch
                warning('io64 not released correctly');
            end
        end
        
        
    end
    methods(Static)
        function ins = getInstance()
            persistent instance;
            
            if( ~strcmpi(class(instance), 'LPTControl') )
                instance = LPTControl();
            end
            
            ins = instance;
        end
    end
    
    methods(Access = private)
        function obj = LPTControl()
            obj.is_connected   = 0;
            obj.address1       = 0;
            obj.address2       = 0;
        end
    end
    
end

