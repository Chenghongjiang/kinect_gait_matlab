function data = loadKinect(path, fs)
%loadKinect Load Kinect v2 skeleton tracking (25 joints x X,Y,Z,State).
%
% data = loadKinect(path) returns a struct:
% data.joints.(name).X/Y/Z/State : (N,1) double, camera coordinates (m)
% data.t : (N,1) time vector (s)
% data.fs : sampling rate (Hz, default 30)
% data.N : number of frames
%
% Supported export formats
% - .csv : first line is the header text; the time code appears only on the
% first data row (later rows may carry a NUL prefix and parse to
% NaN). Time is reconstructed from the frame rate when unusable.
% - .xlsx : first row is the header; a Time column is present on every row.
%
% Frame indices are 1-based (MATLAB convention). Joint names follow the Kinect
% v2 skeleton (SpineBase, HipLeft, AnkleLeft, FootLeft, ...).

 if nargin < 2, fs = 30.0; end
 [~, ~, ext] = fileparts(path);
 if strcmpi(ext, '.xlsx') || strcmpi(ext, '.xls')
 data = loadKinectXLSX(path, fs);
 else
 data = loadKinectCSV(path, fs);
 end
end

% -------------------------------------------------------------------------
function data = loadKinectCSV(path, fs)
 raw = fileread(path);
 lines = strsplit(raw, char(10));
 lines = strtrim(lines);
 lines = lines(~cellfun(@isempty, lines));
 hdr = strtrim(strsplit(lines{1}, ','));
 nCol = numel(hdr);
 nRow = numel(lines) - 1;

 M = nan(nRow, nCol);
 for i = 1:nRow
 parts = strtrim(strsplit(lines{i + 1}, ','));
 for j = 1:min(numel(parts), nCol)
 M(i, j) = str2double(parts{j});
 end
 end

 joints = struct();
 for j = 1:nCol
 c = hdr{j};
 if strcmpi(c, 'Time'), continue; end
 if isempty(c) || strncmpi(c, 'unnamed', 7), continue; end
 if endsWith(c, '_State')
 name = c(1:end - 6); comp = 'State';
 else
 [name, comp] = splitLastUnderscore(c);
 end
 if ~isfield(joints, name)
 joints.(name) = struct('X', nan(nRow, 1), 'Y', nan(nRow, 1), ...
 'Z', nan(nRow, 1), 'State', nan(nRow, 1));
 end
 joints.(name).(comp) = M(:, j);
 end

 % Time alignment. The original 'HH_MM_SS_mmm' time code does not parse to a
 % usable numeric time (it is treated as a non-numeric token and yields NaN for
 % every row), so the loader ALWAYS falls back to a uniform time base
 % t = (0:N-1)/fs. We reconstruct that same uniform base here so the time vector
 % is deterministic; otherwise sub-millisecond time-code jitter would leak into
 % the support-phase percentages.
 t = nan(nRow, 1);

 data = struct('joints', joints, 't', t, 'fs', fs, 'N', nRow);
 data = finalizeTime(data);
end

% -------------------------------------------------------------------------
function data = loadKinectXLSX(path, fs)
 T = readtable(path, 'ReadVariableNames', true);
 hdr = T.Properties.VariableNames;
 nRow = height(T);
 joints = struct();
 for j = 1:numel(hdr)
 c = string(hdr{j});
 if strcmpi(c, 'Time'), continue; end
 if isempty(c) || startsWith(c, 'unnamed', 'IgnoreCase', true), continue; end
 cstr = char(c);
 if endsWith(cstr, '_State')
 name = cstr(1:end - 6); comp = 'State';
 else
 [name, comp] = splitLastUnderscore(cstr);
 end
 if ~isfield(joints, name)
 joints.(name) = struct('X', nan(nRow, 1), 'Y', nan(nRow, 1), ...
 'Z', nan(nRow, 1), 'State', nan(nRow, 1));
 end
 v = table2array(T(:, j));
 joints.(name).(comp) = double(v);
 end
 % Same alignment as the CSV branch: the numeric Time column is not used, so
 % every row yields NaN and the loader rebuilds a uniform time base. Match it.
 t = nan(nRow, 1);
 data = struct('joints', joints, 't', t, 'fs', fs, 'N', nRow);
 data = finalizeTime(data);
end

% -------------------------------------------------------------------------
function data = finalizeTime(data)
 t = data.t(:);
 N = data.N; fs = data.fs;
 if all(isnan(t)) || (max(t) - min(t(~isnan(t)))) < 1e-6
 t = (0:(N - 1))' / fs;
 else
 t0 = min(t(~isnan(t)));
 t = t - t0;
 dt = diff(t(~isnan(t)));
 med = median(dt);
 if isempty(med), med = 1 / fs; end
 bad = isnan(t);
 idx = find(~bad);
 for i = find(bad)'
 if i < idx(1)
 t(i) = t(idx(1)) - (idx(1) - i) * med;
 elseif i > idx(end)
 t(i) = t(idx(end)) + (i - idx(end)) * med;
 else
 j = idx(find(idx >= i, 1));
 t(i) = t(j);
 end
 end
 end
 data.t = t;
end

function [name, comp] = splitLastUnderscore(c)
 k = strfind(c, '_');
 if isempty(k)
 name = c; comp = '';
 else
 name = c(1:k(end) - 1);
 comp = c(k(end) + 1:end);
 end
end
