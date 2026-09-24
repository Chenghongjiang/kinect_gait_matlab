function pre = preprocessJoints(data, cutoff, order)
%preprocessJoints NaN-interpolate and low-pass filter X/Y/Z of every joint.
% Returns a struct mirroring `data` with smoothed joint coordinates.
 if nargin < 2, cutoff = 5.0; end
 if nargin < 3, order = 4; end
 fs = data.fs;
 joints = struct();
 fn = fieldnames(data.joints);
 comps = {'X', 'Y', 'Z', 'State'};
 for k = 1:numel(fn)
 name = fn{k};
 J = data.joints.(name);
 d = struct();
 for c = 1:4
 comp = comps{c};
 v = J.(comp);
 if ismember(comp, {'X', 'Y', 'Z'})
 d.(comp) = gait.lowpass(v, fs, cutoff, order);
 else
 d.(comp) = double(v);
 end
 end
 joints.(name) = d;
 end
 pre = struct('joints', joints, 't', data.t, 'fs', fs, 'N', data.N);
end
