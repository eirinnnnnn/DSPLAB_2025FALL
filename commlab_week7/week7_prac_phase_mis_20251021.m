clear; clc;

%% ---------- Simulation setup ----------
N = 10000;
omegaI   = 0.07;       % I (cos) frequency
delta_w  = 0.001;      % mismatch
omegaQ   = omegaI + delta_w;  % Q (sin) frequency
T = 1;

zeta = 0.707;  wn = 0.02;
alpha = 2*zeta*wn*T;  beta = (wn*T)^2;

%% ---------- Optional extra phase on input (step) ----------
theta_off = zeros(1,N);
k_step = 800;  theta0 = 0;  theta_off(k_step:end)=theta0;

%% ---------- states ----------
phi = zeros(1,N); s=0; c=0; eps=zeros(1,N);
I = zeros(1,N);  Q=zeros(1,N);  v=zeros(1,N);  thetahat=zeros(1,N);

%% ---------- main loop ----------
for k = 2:N
    % Input with I/Q freq mismatch
    I(k-1) = cos(omegaI*(k-1) + theta_off(k-1));
    Q(k-1) = 2*sin(omegaQ*(k-1) + theta_off(k-1));  % scaled as in slide

    % Measured reference phase from mismatched I/Q
    thetahat(k-1) = atan2(Q(k-1), I(k-1));

    % (for viewing) VCO waveform at nominal I frequency
    v(k) = 2*sin(omegaI*(k-1) + phi(k-1));

    % DPLL with delayed PD input
    eps(k) = phi(k-1) - thetahat(k-1);

    g = alpha*eps(k);
    s = s + beta*eps(k);
    c = g + s;

    phi(k) = phi(k-1) - c;
end

%% ---------- plots ----------
tu=N; t=1:tu;
figure; plot(t,unwrap(thetahat(1:tu)),'LineWidth',1); hold on;
plot(t,unwrap(phi(1:tu)),'LineWidth',1);
legend('\hat\theta_k (from I/Q mismatch)','\phi_k'); xlabel('k'); ylabel('phase [rad]');
title('Lock under I/Q frequency mismatch');

figure; plot(t,eps(1:tu),'LineWidth',1);
xlabel('k'); ylabel('\epsilon_k'); title('Phase error (shows beat ripple at \Delta\omega)');

figure; subplot(2,1,1); plot(t,I(1:tu)); title('Input I/Q');
ylabel('I = cos(\omega_I k)'); subplot(2,1,2);
plot(t,Q(1:tu)); ylabel('Q = 2 sin(\omega_Q k)'); xlabel('k');
