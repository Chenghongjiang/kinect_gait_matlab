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
 % Orient forward by the LARGEST horizontal excursion, not by the mean velocity.
 % A TUG is an out-and-back walk (out + turn + back), so the net displacement is
 % ~0 and dot(f, mean(vel)) is only rounding-noise sized (~1.8e-2 m measured).
 % Its sign therefore flips with the differentiation scheme: MATLAB's diff
 % (forward difference) and central-difference schemes produced
 % OPPOSITE forward axes on real trials, which shifted the turn window, the
 % candidate cycles and every 6-point result. The turn-around point is ~1 m from
 % the start, far above the noise floor and independent of the implementation.
 proj = H * f;
 [~, k] = max(abs(proj));
 if proj(k) < 0, f = -f; end
 l = [-f(2); f(1)];
 com0 = com(1, :)';
end
