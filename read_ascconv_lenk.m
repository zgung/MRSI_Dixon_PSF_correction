function [ParList,ascconv] = read_ascconv_lenk(file_path)
% read_ascconv_x_x Read ascconv header part of DICOM and Siemens raw data
% This function was written by Bernhard Strasser, July 2012.
% The function cuts out the ascconv header part of DICOM and Siemens raw data and searches for Parameters within this header. These
%
%
% [ParList,ascconv] = read_ascconv_1_2(file_path)
%
% Input: 
% -         file_path                     ...     Path of file.
%
% Output:
% -         ParList                       ...     Structure giving all the Parameters. It contains:
%           -- ParList.total_channel_no         - Number of receive-channels
%           -- ParList.ROW_raw                  - Number of measured rows (lines)
%           -- ParList.COL_raw                  - Number of measured columns (phase_encoding)
%           -- ParList.ROW                      - Number of rows (lines) AFTER zerofilling
%           -- ParList.COL                      - Number of columns (phase_encoding) AFTER zerofilling
%           -- ParList.SLC                      - Number of Slices
%           -- ParList.vecSize                  - VectorSize in spectroscopic dimension
%           -- ParList.RemoveOversampling       - Flag that determines if oversampling in spectroscopic / frequency encoding direction is removed
%
% -         ascconv                       ...     cell array of the ascconv header: ascconv{:,1} = ParameterName, ascconv{:,2} = ParameterValue 
%
%
% Feel free to change/reuse/copy the function. 
% If you want to create new versions, don't degrade the options of the function, unless you think the kicked out option is totally useless.
% Easier ways to achieve the same result & improvement of the program or the programming style are always welcome!
% File dependancy: None






%% 0. Preparations


% Define for which entries the ascconv should be searched for, to which variables it should be assigned, and to which format it should be converted.
% Search for these entries in the ascconv header part:
ParList_Search =  { 'sSliceArray.asSlice[0].dThickness'     ,'sSliceArray.asSlice[0].dPhaseFOV'         ,'sSliceArray.asSlice[0].dReadoutFOV'   ,...
                    'FinalMatrixSizePhase'        ,'FinalMatrixSizeRead'            ,'FinalMatrixSizeSlice'       ,...
                    'sSliceArray.asSlice[0].sPosition.dSag' ,'sSliceArray.asSlice[0].sPosition.dCor'    ,'sSliceArray.asSlice[0].sPosition.dTra',...
                    'sKSpace.lBaseResolution'               ,'sKSpace.lPhaseEncodingLines'              ,'sKSpace.lPartitions'                  ,...
                    'sSpecPara.sVoI.dThickness'             ,'sSpecPara.sVoI.dPhaseFOV'                 ,'sSpecPara.sVoI.dReadoutFOV'           ,...
                    'asCoilSelectMeas[0].asList[0].sCoilElementID.tElement' ,'asCoilSelectMeas[0].asList[1].sCoilElementID.tElement' ,'asCoilSelectMeas[0].asList[2].sCoilElementID.tElement',...
                    'sSliceArray.asSlice[0].dInPlaneRot'    ,'sSliceArray.asSlice[0].dThickness'        ,'VectorSize'                           ,...
                    'sTXSPEC.asNucleusInfo[0].lFrequency'   ,'sRXSPEC.bGainValid'};
% Name the structure entries of ParList like this:
ParList_Assign =  { 'FoV_z'                      ,'FoV_y'               ,'FoV_x'                ,...
                    'number_y'                   ,'number_x'            ,'number_z'             ,...
                    'fov_cntr_x'                 ,'fov_cntr_y'          ,'fov_cntr_z'           ,...
                    'notinterpfov_x'             ,'notinterpfov_y'      ,'notinterpfov_z'       ,...
                    'p_fov_z'                    ,'p_fov_y'             ,'p_fov_x'              ,...
                    'coilel1'                    ,'coilel2'             ,'coilel3'              ,...
                    'angle'                      ,'rm'                  ,'vecSize'              ,...
                    'freq'                       ,'sampint'};
% Tells function to which format it should convert the found string in the ascconv (remember: all values in the ascconv are strings):
ParList_Convert = {  'str2double'   ,'str2double'   ,'str2double'   ,...
                     'str2double'   ,'str2double'   ,'str2double'   ,...
                     'str2double'   ,'str2double'   ,'str2double'   ,...
                     'str2double'   ,'str2double'   ,'str2double'   ,...
                     'str2double'   ,'str2double'   ,'str2double'   ,...
                     'char'         ,'char'         ,'char'         ,...
                     'str2double'   ,'str2double'   ,'str2double'   ,...
                     'str2double'   ,'str2double'};


% Initialize ParList
for Par_no = 1:numel(ParList_Search)
    eval([ 'ParList.' ParList_Assign{Par_no} ' = NaN;' ]);
end
% open file
%file_path = ('/Volumes/Home/zgung/Desktop/phantoms/phantom_csi_test_Marek/2noshift/spec/PHANTOM_1H_MRS_BREAST.MR.PHYSIKER_MACH.0004.0001.2012.07.10.10.15.54.687500.98517272.IMA');

fid = fopen(file_path,'r');

%% 1. Track down & save ASCCONV

begin_found = 0;
ascconv = [];
sLine = 0;

while(sLine > -1)
    sLine = fgets(fid); % get string line
    if(not(begin_found))                                          % If begin of ascconv not yet found
        if(not(isempty(strfind(sLine,'### ASCCONV BEGIN ###'))))
            begin_found = true;                                   % If current line is begin of ascconv
        else
            continue                                              % If current line is not begin of ascconv --> read next line
        end
    else                                                          % If begin of ascconv has already been found
        if(not(isempty(strfind(sLine,'### ASCCONV END ###'))))    % If the end was found --> stop while loop
            break
        else
            ascconv = [ascconv; {sLine}];                         % If current line is not the end --> read in line and save it
        end
    end
end

%% 2. Display error & stop if no Ascconv found

if(not(begin_found))
    display(['Pfui Toifel! You gave me a file without any ascconv, I cannot digest that! Please remember that I am NOT an omnivore.' char(10) ...
             'I will stop here . . .'])
    return
end


%% 3. Convert ascconv

% Convert cell array of strings containing n x 2 entries. The first entries containing the parts before the '=' (pre-=) 
% and the second parts containing the parts after the '=' (post-=)

% Until now ascconv is a cell array of strings (with lets say 348 entries)

% This regexp makes ascconv to a cell array with 348 entries, each of these on its own a cell array of 2 strings
ascconv = regexp(ascconv, '=','split');

% This makes ascconv to a 2*348 = 696x1 cell array of strings; All odd cells contain the parts before the '=', all even cells the part after the '='
ascconv = transpose([ascconv{:}]);

% Now seperate the pre-= and the post-= parts, remove all white spaces before and after the entries.
ascconv = strtrim([ascconv(1:2:end) ascconv(2:2:end)]);

% Now we are happy and have our 348x2 cell array of strings.




%% 4. Search certain entries & Save these

% The following code performs these tasks:
% strfind(...): searches ascconv-ParameterNames (ascconv(:,1)) for the ParList_Search-strings. This results in a cell array, containing [] if in 
% the corresponding cell the Parametername was not found, and [n] if it was found in the corresponding cell on place n of the string;
% not(cellfun(...)): We then search each cell (--> cellfun) if it is empty, and negate the logical output, so that we get the non-empty cells.
% eval(...) We assign the found value to ParList.ParameterName, where ParameterName is determined by ParList_Assign. We also convert the values.

for Par_no = 1:numel(ParList_Search)
    Par_Logic = strfind(ascconv(:,1),ParList_Search{Par_no});    
    Par_Logic = not(cellfun('isempty',Par_Logic));
    if(find(Par_Logic) > 0)
        eval([ 'ParList.' ParList_Assign{Par_no} ' = ' ParList_Convert{Par_no} '(ascconv(Par_Logic,2));' ]);
    end
end


%% 5. Change & Correct certain values

% Convert voxel_angle (NaN for 0). 
ParList.angle(isnan(ParList.angle)) = 0;
ParList.coilel3(isnan(ParList.coilel3)) = 0;

%% 5. Postparations

fclose(fid);
