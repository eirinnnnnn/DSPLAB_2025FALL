clear; clc;

%% ---------- Simulation setup ----------
N      = 10000;        % number of samples
omega  = 0.07;        % base sampling
omega_delt = 0.001;
% omega_delt = 0;
T      = 1;           % sample period 


zeta   = 0.707;       
wn     = 0.02;        % rad/sample
alpha  = 2*zeta*wn*T; 
beta   = (wn*T)^2;    

%% ---------- Reference phase design theta_k ----------
theta  = zeros(1,N);

% 1) Phase step at k_step by amount theta0 (kept constant afterward)
k_step = 800;                 % when the input changes from cos(omega k) to cos(omega k + theta0)
theta0 = 0.8*pi;              % phase step size
theta0 = 0;
theta(k_step:end) = theta0;


%% ---------- state init ----------
phi = zeros(1,N);             % VCO phase
s   = 0;                      
c   = 0;                      
eps = zeros(1,N);             


r = zeros(1,N); v = zeros(1,N);
e = 1e-6;
for k = 2:N
    % reference and VCO outputs
    r(k) = cos(omega*(k-1) + theta(k-1));
    v(k) = 2*sin((omega+omega_delt)*(k-1) + phi(k-1));

    % linear phase detector
    % eps(k) = phi(k-1) - theta(k-1);
    % eps(k) = atan2(r(k), v(k));
    % eps(k) =  ((omega+omega_delt)*(k-1) + phi(k-1)) - (omega*(k-1) + theta(k-1));
    pd_raw = v(k) * r(k);                % mixer
    alpha_lpf = exp(-0.0012);
    % alpha_lpf = exp(-0.02);
    eps(k) = (1 - alpha_lpf)*pd_raw + alpha_lpf*eps(k-1);

    % update equations
    g  = alpha * eps(k);
    s  = s + beta * eps(k);
    c  = g + s;

    phi(k) = phi(k-1) + c;
end

%% ---------- Plots ----------

tu = N;
t = (1:tu);
figure; 
theta = unwrap(theta);
phi = unwrap(phi);
plot(t, theta(1:tu), 'LineWidth',1); hold on;
plot(t, phi(1:tu),   'LineWidth',1);
legend('\theta_k (reference extra phase)','\phi_k (VCO phase)','Location','best');
xlabel('k'); ylabel('phase [rad]');
title('Reference vs. VCO phase');

figure;
plot(t, eps(1:tu), 'LineWidth',1);
xlabel('k'); ylabel('\epsilon_k [rad]');
title('Phase error');

figure;
subplot(2,1,1); plot(t, r(1:tu)); ylabel('ref r_k'); title('Waveforms');
subplot(2,1,2); plot(t, 0.5*v(1:tu)); ylabel('VCO v_k'); xlabel('k');


figure;
plot(t, r(1:tu)-0.5*v(1:tu)); ylabel('differene'); title('Waveforms');
