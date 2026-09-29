function [f, l, com0] = buildSubjectFrame(data)
%buildSubjectFrame Estimate the subject-centred frame from CoM horizontal motion.
% f : (2x1) forward (walking) unit vector in the camera X-Z plane
% l : (2x1) leftward (lateral) unit vector, perpendicular to f
% com0 : (3x1) centre-of-mass position at the first frame
% The forward axis is the principal component (PCA) of the CoM horizontal
% displacement (SpineBase / HipLeft / HipRight mean), oriented by the sign of
% the LARGEST horizontal excursion (turn-around point). The mean forward
% velocity is NOT used: an out-and-back TUG has ~zero net displacement, so
% its sign is set by rounding noise and flips with the differentiation scheme.
 J = data.joints;
 N = data.N;
 com = zeros(N, 3); cnt = 0;
 for j = {'SpineBase', 'HipLeft', 'HipRight'}
 if isfield(J, j{1})
 com(:, 1) = com(:, 1) + J.(j{1}).X;
 com(:, 2) = com(:, 2) + J.(j{1}).Y;
 com(:, 3) = com(:, 3) + J.(j{1}).Z;
 cnt = cnt + 1;
 end
 end
 com = com / cnt;
 hx = gait.interpNaN(com(:, 1));
 hz = gait.interpNaN(com(:, 3));
 H = [hx, hz] - [hx(1), hz(1)];
 C = cov(H);
 [V, D] = eig(C);
 [~, imax] = max(diag(D));
 f = V(:, imax);
 % Orient forward by the LARGEST horizontal excursion (turn-around point):
 % the net displacement of an out-and-back TUG is ~0, so dot(f, mean(vel))
 % is rounding-noise sized and its sign is differentiation-scheme dependent.
 proj = H * f;
 [~, k] = max(abs(proj));
 if proj(k) < 0, f = -f; end
 l = [-f(2); f(1)];
 com0 = com(1, :)';
end
