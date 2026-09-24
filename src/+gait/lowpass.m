function y = lowpass(sig, fs, cutoff, order)
%lowpass Zero-phase 4th-order Butterworth low-pass (filtfilt).
% Corresponds to the "data smoothing / denoising" step in the Methods section.
 if nargin < 3, cutoff = 5.0; end
 if nargin < 4, order = 4; end
 sig = sig(:); % force column vector (orientation-agnostic)
 sig = gait.interpNaN(sig); % linear-interp short NaN gaps, column-preserving
 nyq = 0.5 * fs;
 wn = min(cutoff / nyq, 0.99);
 [b, a] = butter(order, wn, 'low');
 y = filtfilt(b, a, sig);
end
