function [header, seg, bscan, fundus] = read_e2e(file, varargin)
%read_e2e Read .e2e file exported from Spectralis OCT (Heidelberg Engineering)
%
%   [header, segment, bscan, slo] = read_e2e(file, options)
%
%   This function reads the header, segmentation and image information 
%   contained in the .e2e/.E2E files. 
%
%   Input arguments:
%  
%   'file'           String containing the path to the .vol file to be read.          
%  
%   'varargin'       Optional parameters from the list:
%                       
%                    'visu': Visualize the scanning patter along with B-Scans
%                    and slo image.
%                       
%                    'verbose': Display header info during read.
%
%                    'full_header': Retrieve the original header with all the
%                    parameters (By default only a few important parameters are
%                    retrieved).
%
%                    'coordinates': retrieve fundus and A-Scan X, Y coordinates
%
%                    'raw_voxel': return raw pixel reflectance instead of
%                    visualization-adapted values.
%
%   Output arguments:
%  
%   'header'         Structure with .vol file header values.          
%  
%   'seg'            Segmenation data stored in the .vol file.
%
%   'bscan'          3D single image with B-Scans.
%
%   'fundus'         2D fundus image.
%   
%
%   Notes
%   -----
%   Spectralis OCT data can be exported into both E2E and vol format. We
%   recommend using the latter as it provides a better access to the header
%   information.
%
%
%   References
%   ----------
%   [1] 
%
%   Examples
%   ---------      
%   % Read all the information in a .vol file
%
%     file = 'my_oct.vol';
%     [header, segment, bscan, slo] = read_vol(file)
%     
%
%   % Read only the header (faster) of the .vol file
%     file = 'my_oct.vol';
%     header = read_vol(file)
%
%
%   David Romero-Bascones, dromero@mondragon.edu
%   Biomedical Engineering Department, Mondragon Unibertsitatea, 2022

verbose = true;

global SEG_FLAG IMAGE_FLAG NA_FLAG QUALITY_FLAG PATIENT_FLAG EYE_FLAG 
PATIENT_FLAG = 9;
EYE_FLAG     = 11;
QUALITY_FLAG = 1004;
SEG_FLAG     = 10019;
IMAGE_FLAG   = 1073741824;
NA_FLAG      = 4294967295;
CHUNK_HEADER_SIZE = 60;

fid = fopen(file, 'rb', 'l');
 
chunks = discover_chunks(fid);

% Get number of patients 4294967295 = 2^32 - 1 (all ones means not applicable)
patients = unique(chunks.patient_id);
patients(patients == NA_FLAG) = [];
n_patient = length(patients);

if n_patient > 1
    error(['Number of patients in file is > 1 (' num2str(n_patient) ')']);        
end

% Get number of series per subject
series_id = unique(chunks.series_id);
series_id(series_id == NA_FLAG) = [];
n_series = length(series_id);

if verbose
    disp(['Number of series (images) in file: ' num2str(n_series)]);
end

% Read patient data first
patient_header = read_patient_data(fid, chunks);

% Parse each series separately
header = cell(1, n_series);
bscan  = cell(1, n_series);
seg    = cell(1, n_series);
fundus = cell(1, n_series);
for i_series = 1:n_series
    chunks_series = chunks(chunks.series_id == series_id(i_series),:);

    %% Header
    header{i_series} = read_header(fid, chunks_series, patient_header);
        
    %% Bscan 
%     bscan{i_series} = read_bscan(fid, chunks_series, verbose);

    %% Segmentation
%     seg{i_series} = read_segmentation(fid, chunks_series);
     
    %% Fundus
    fundus = read_fundus(fid, chunks_series); 
     
end

% match = search_by_value(fid, chunks, 39.9414, {'*float32'})
% match = search_by_value(fid, chunks, 34.2144, {'*float32'})
% match = search_by_value(fid, chunks, 21.0941, {'*single'})

% match = struct2table(match);

chunk_id = 10004;
idx = find(chunks.type == chunk_id);

for i=1:length(idx)
    fseek(fid, chunks.start(idx(i)), -1);
%     fread(fid, CHUNK_HEADER_SIZE, '*uint8');
%     x = fread(fid, chunks.size(idx(i)), '*char')';
%     disp(x);
    
%     fseek(fid, chunks.start(idx(i)), -1);
%     fread(fid, CHUNK_HEADER_SIZE, '*uint8');
%     x8 = fread(fid, chunks.size(idx(i)), '*uint8')';
%     x16 = fread(fid, chunks.size(idx(i))/2, '*uint16')';
%     x32 = fread(fid, chunks.size(idx(i))/3, '*uint32')';
   %     disp(laterality');
    
    parse_chunk(fid, chunk_id);

    
end

function match = search_by_value(fid, chunks, value, types)

match = struct;
i_match = 1;
for i=1:size(chunks,1)
    chunk_type = chunks.type(i);
    start   = chunks.start(i);
    n_bytes = chunks.size(i);

    disp(['Chunk ' num2str(i) '/' num2str(size(chunks,1))]);
    
    fseek(fid, start, -1);
    fread(fid, 60, '*uint8');
    
    x = {};
    types_all = {};
    for j=1:length(types)
        switch types{j}
            case '*float32'
                x{end+1} = fread(fid, n_bytes/4, '*float32');
                
                fseek(fid, start, -1);
                fread(fid, 61, '*uint8');                
                x{end+1} = fread(fid, n_bytes/4, '*float32');
                
                fseek(fid, start, -1);
                fread(fid, 62, '*uint8');                
                x{end+1} = fread(fid, n_bytes/4, '*float32');
                
                fseek(fid, start, -1);                
                fread(fid, 63, '*uint8');
                x{end+1} = fread(fid, n_bytes/4, '*float32');       
                
                types_all(end+1:end+4) = {'*single_0','*single_1','*single_2','*single_3'};

            case '*single'
                x{end+1} = fread(fid, n_bytes/4, '*single');
                
                fseek(fid, start, -1);
                fread(fid, 61, '*uint8');                
                x{end+1} = fread(fid, n_bytes/4, '*single');
                
                fseek(fid, start, -1);
                fread(fid, 62, '*uint8');                
                x{end+1} = fread(fid, n_bytes/4, '*single');
                
                fseek(fid, start, -1);                
                fread(fid, 63, '*uint8');
                x{end+1} = fread(fid, n_bytes/4, '*single');       
                
                types_all(end+1:end+4) = {'*single_0','*single_1','*single_2','*single_3'};

            case '*uint8'
                x{end+1} = fread(fid, n_bytes, '*uint8');
                types_all{end+1} = '*uint8';
            case '*uint16'
                x{end+1} = fread(fid, n_bytes/2, '*uint16');
                
                fseek(fid, start, -1);
                fread(fid, 61, '*uint8');
                x{end+1} = fread(fid, n_bytes/2, '*uint16');
                
                types_all(end+1:end+2) = {'*uint16_0','*uint16_1'};
            case '*uint32'
                x{end+1} = fread(fid, n_bytes/4, '*int32');
                
                fseek(fid, start, -1);
                fread(fid, 61, '*uint8');                
                x{end+1} = fread(fid, n_bytes/4, '*int32');
                
                fseek(fid, start, -1);
                fread(fid, 62, '*uint8');                
                x{end+1} = fread(fid, n_bytes/4, '*int32');
                
                fseek(fid, start, -1);                
                fread(fid, 63, '*uint8');
                x{end+1} = fread(fid, n_bytes/4, '*int32');
                
                
                types_all(end+1:end+4) = {'*uint32_0','*uint32_1','*uint32_2','*uint32_3'};
        end                
    end
    
    for j=1:length(x)
%         idx = find(x{j} == value);
        idx = find(abs(x{j} - value)<= 0.0001);
        
        for ii=1:length(idx)
            match(i_match).idx = i;
            match(i_match).chunk_type = chunk_type;
            match(i_match).data_type = types_all{j};
            match(i_match).pos = idx(ii);
                        
            i_match = i_match + 1;
        end
    end
end

function chunks = discover_chunks(fid)
% Read header
magic1   = string(fread(fid, 12, '*char')');
version1 = fread(fid, 1, '*uint32');
unknown1 = fread(fid, 9, '*uint16');
unknown2 = fread(fid, 1, '*uint16');

% Directory
magic2      = string(fread(fid, 12, '*char')');
version2    = fread(fid, 1, '*uint32');
unknown3    = fread(fid, 9, '*uint16');
unknown4    = fread(fid, 1, '*uint16');
num_entries = fread(fid, 1, '*uint32');
current     = fread(fid, 1, '*uint32');
zeros2      = fread(fid, 1, '*uint32');
unknown5    = fread(fid, 1, '*uint32');

chunks = struct;
i_main = 1;
i_chunk = 1;
while current ~=0% List of chunks
    fseek(fid, current, -1);

    magic3       = string(fread(fid, 12, '*char')');
    version3     = fread(fid, 1, '*uint32');
    unknown6     = fread(fid, 9, '*uint16');
    unknown7     = fread(fid, 1, '*uint16');
    num_entries2 = fread(fid, 1, '*uint32');
    unknown8     = fread(fid, 1, '*uint32');
    prev         = fread(fid, 1, '*uint32');
    unknown9     = fread(fid, 1, '*uint32');

    current = prev;

    for i=1:num_entries2
        pos        = fread(fid, 1, '*uint32');
        start      = fread(fid, 1, '*uint32');
        size       = fread(fid, 1, '*uint32');
        zero       = fread(fid, 1, '*uint32');
        patient_id = fread(fid, 1, '*uint32');
        study_id   = fread(fid, 1, '*uint32');
        series_id  = fread(fid, 1, '*uint32');
        bscan_id   = fread(fid, 1, '*uint32');
        unknown    = fread(fid, 1, '*uint16');
        zero2      = fread(fid, 1, '*uint16');
        type       = fread(fid, 1, '*uint32');
        unknown11  = fread(fid, 1, '*uint32');

        if size > -10
            
            chunks(i_chunk).patient_id = patient_id;
            chunks(i_chunk).series_id  = series_id;
            chunks(i_chunk).bscan_id   = bscan_id;
            chunks(i_chunk).type       = type;
            chunks(i_chunk).pos        = pos;
            chunks(i_chunk).start      = start;
            chunks(i_chunk).size       = size;

            i_chunk = i_chunk + 1;
        end
    end

    disp(['Read element ' num2str(i_main)]);
    
    i_main = i_main + 1;
end

chunks = struct2table(chunks);

function header = read_patient_data(fid, chunks)
global PATIENT_FLAG

start = chunks.start(chunks.type == PATIENT_FLAG);
fseek(fid, start, -1);
header = parse_chunk(fid, PATIENT_FLAG);

function header = read_header(fid, chunks, header)
global EYE_FLAG

start = chunks.start(chunks.type == EYE_FLAG);
fseek(fid, start(1), -1);
data = parse_chunk(fid, EYE_FLAG);

header.eye = data.eye;

% To be filled to read scale, dimensions, quality...

function bscan = read_bscan(fid, chunks, verbose)
global IMAGE_FLAG NA_FLAG

is_image = chunks.type == IMAGE_FLAG;
is_bscan = chunks.bscan_id ~= NA_FLAG;
     
bscan_id = chunks.bscan_id(is_image & is_bscan);     
n_bscan = length(bscan_id);

if verbose
    disp(['Reading ' num2str(n_bscan) ' bscans']);
end
     
bscan_id = sort(bscan_id);
     
for i_bscan=1:n_bscan
    is_bscan = chunks.bscan_id == bscan_id(i_bscan);

    start = chunks.start(is_bscan & is_image);
    fseek(fid, start, -1);

    data = parse_chunk(fid, IMAGE_FLAG);

    % This can be eliminated if the header is built before
    if i_bscan == 1
       bscan = nan(data.n_axial, data.n_ascan, n_bscan);             
    end

    bscan(:, :, i_bscan) = data.bscan;
end  
    
function fundus = read_fundus(fid, chunks)
global IMAGE_FLAG NA_FLAG

is_image     = chunks.type == IMAGE_FLAG;
is_not_bscan = chunks.bscan_id == NA_FLAG;

start = chunks.start(is_image & is_not_bscan);
fseek(fid, start, -1);

data   = parse_chunk(fid, IMAGE_FLAG);
fundus = data.fundus;
     
function seg = read_segmentation(fid, chunks)
global SEG_FLAG NA_FLAG
layer_names = {'ILM',     'BM',      'RNFL_GCL', 'GCL_IPL', ...
               'IPL_INL', 'INL_OPL', 'OPL_ONL', 'unknown', 'ELM', ...
               'unknown', 'unknown', 'unknown','unknown','unknown', ...
               'MZ_EZ',   'OSP_IZ',  'IZ_RPE'};
           
is_seg = chunks.type == SEG_FLAG;

bscan_id = unique(chunks.bscan_id);
bscan_id(bscan_id == NA_FLAG) = [];
n_bscan  = length(bscan_id);

seg = struct;
for i_bscan=1:n_bscan
    is_bscan = chunks.bscan_id == bscan_id(i_bscan);
    
    start = chunks.start(is_seg & is_bscan);
    n_layer = length(start);
    for i_layer=1:n_layer
        fseek(fid, start(i_layer), -1);
        data = parse_chunk(fid, SEG_FLAG);        
        
        layer = layer_names{data.layer_id + 1};
        seg.(layer)(i_bscan, :) = data.seg;
    end
end

% Invalid values coded as 0 --> better have nan to avoid wrong computations
layer_names = fields(seg);
for i_layer=1:length(layer_names)
    layer = layer_names{i_layer};
    seg.(layer)(seg.(layer) == 0) = nan;
end

function data = parse_chunk(fid, type)
global SEG_FLAG IMAGE_FLAG PATIENT_FLAG QUALITY_FLAG EYE_FLAG

% We can probably skip chunk header as that info is not really useful
magic4     = string(fread(fid, 12, '*char')');
unknown    = fread(fid, 2, '*uint32');
pos        = fread(fid, 1, '*uint32');
c_size     = fread(fid, 1, '*uint32');
zero       = fread(fid, 1, '*uint32');
patient_id = fread(fid, 1, '*int32');
study_id   = fread(fid, 1, '*int32');
series_id  = fread(fid, 1, '*int32');
bscan_id   = fread(fid, 1, '*uint32');
ind        = fread(fid, 1, '*uint16');
unknown2   = fread(fid, 1, '*uint16');
c_type     = fread(fid, 1, '*uint32');
unknown3   = fread(fid, 1, '*uint32');

switch type
    case 3
        text = fread(fid, 12, '*char');
        
    case 7
        eye = fread(fid, 1, '*char');
        
    case PATIENT_FLAG % patient info
        name       = deblank(fread(fid, 31, '*char')');
        surname    = deblank(fread(fid, 66, '*char')');
        birth_date = fread(fid, 1, '*uint32');
        sex        = fread(fid, 1, '*char');
        
        birth_date = (birth_date/64) - 14558805;  % to julian date
        birth_date = datetime(birth_date, 'ConvertFrom', 'juliandate');
        
        data.name       = name;
        data.surname    = surname;
        data.birth_date = birth_date;
        
        if sex == 'M'
            data.sex = 'male';
        elseif sex == 'F'
            data.sex = 'female';
        else
            data.sex = 'unknown';
        end        
        
    case EYE_FLAG
        unknown = fread(fid, 14, '*char');
        eye     = fread(fid, 1, '*char');  % Laterality
        unknown = fread(fid, 14, '*uint8');
  
        if eye == 'L'
            data.eye = 'OS';
        elseif eye == 'R'
            data.eye = 'OD';
        else
            warning("Unknown laterality value");
            data.eye = 'unknown';
        end
    case 13
        device = fread(fid, 260, '*char')';
        
    case 52
        code = fread(fid, 97, '*char');
    case 53
        code = fread(fid, 97, '*char');        
        
    case QUALITY_FLAG
        unknown = fread(fid, 39, '*single');
        quality = fread(fid, 1, '*single');
        
    case SEG_FLAG  % segmentation
        unknown  = fread(fid, 1, '*uint32');
        layer_id = fread(fid, 1, '*uint32');
        unknown  = fread(fid, 1, '*uint32');
        n_ascan  = fread(fid, 1, '*uint32');
        
        seg      = fread(fid, n_ascan, '*float32');
        
        data.layer_id = layer_id;
        data.n_ascan  = n_ascan;
        data.seg      = seg;

    case IMAGE_FLAG  % image data
        data_size  = fread(fid, 1, '*int32');
        image_type = fread(fid, 1, '*int32');
        n_pixel    = fread(fid, 1, '*int32');
        
        switch image_type
            case 33620481 % fundus
                width  = fread(fid, 1, '*int32');
                height = fread(fid, 1, '*int32');
                bytes  = fread(fid, n_pixel, '*uint8');
                
                fundus = reshape(bytes, [width height]);
                fundus = permute(fundus, [2 1]);
                
                data.fundus     = fundus;
                data.n_x_fundus = width;
                data.n_y_fundus = height;
            case 35652097 % b-scan 
                n_axial = fread(fid, 1, '*int32');
                n_ascan = fread(fid, 1, '*int32');
                bytes   = double(fread(fid, n_pixel, '*uint16'));
                
                % Old implementation (intuitive but very slow)
                %  bin      = dec2bin(bytes);
                %  exponent = bin2dec(bin(:, 1:6));
                %  mantissa = bin2dec(bin(:, 7:end));
                
                exponent = floor(bytes / 2^10);
                mantissa = mod(bytes, 2^10);

                a        = (1 + mantissa) / 2^10;
                b        = 2 .^ (exponent - 63);
                bscan    = a .* b;
                
                bscan = reshape(bscan, [n_ascan n_axial]);
                bscan = permute(bscan, [2 1]);

                data.n_ascan = n_ascan;
                data.n_axial = n_axial;
                data.bscan   = bscan;
            otherwise
                warning('Unknown image type');
        end
    case  1073751825 % looks like a time series
%         unknown = fread(fid, 300,'*uint8');
        
    otherwise
        error("Unknown chunk type");
end
