%% Stage 1: 64QAM Transmitter, Constellation (Eb/N0=10 dB), Lowpass PSD
% -----------------------------
% Initialization and parameters
% -----------------------------
Number_symbols    = 1e5;
k                 = 6;         % bits/symbol for 64QAM
Number_bits       = k*Number_symbols;
Carrier_frequency = 1e6;       % 1 MHz
Sampling_frequency= 3*Carrier_frequency;
Symbol_rate       = 1e5;       % 100 kSym/s

% -----------------------------
% Generate bit stream (serial)
% -----------------------------
bits = randi([0 1], Number_bits, 1);

% -------------------------------------------
% 1:6 Serial to Parallel (6 bits per symbol)
% -------------------------------------------
bits6 = reshape(bits, 6, []).';     % [Nsym x 6]
bitsI = bits6(:,1:3);               % I-branch (3 bits)
bitsQ = bits6(:,4:6);               % Q-branch (3 bits)

% ---------------------------------------------------------
% 8-PAM Gray mapping per branch: levels ±1, ±3, ±5, ±7
% ---------------------------------------------------------
levels8   = [-7 -5 -3 -1 1 3 5 7];                % ascending amplitudes
grayLUT8  = [0 1 3 2 6 7 5 4];     %[000 001 011 010 110 111 101 100]  binary->Gray for 3 bits
invGray8  = zeros(1,8); invGray8(grayLUT8+1) = 0:7; % Gray->binary

% Binary index from 3 bits (MSB..LSB)
bI = bitsI(:,1)*4 + bitsI(:,2)*2 + bitsI(:,3);
bQ = bitsQ(:,1)*4 + bitsQ(:,2)*2 + bitsQ(:,3);

% Gray index and amplitudes
gI = grayLUT8(bI+1).';
gQ = grayLUT8(bQ+1).';
I  = levels8(gI+1).';
Q  = levels8(gQ+1).';

% -----------------------------
% Complex envelope s(n) = I + jQ
% -----------------------------
s = I + 1j*Q;

% ------------------------------------------------
% Eb from constellation average (exact Es = 42)
% ------------------------------------------------
[Igrid,Qgrid] = meshgrid(levels8, levels8);
constPoints   = Igrid(:) + 1j*Qgrid(:);
Es            = mean(abs(constPoints).^2);  % = 42 exactly
Eb            = Es / k;

% ---------------------------------------
% AWGN at Eb/N0 = 0,5,10,15,20 dB and constellation
% ---------------------------------------
EbN0_dB_list = [0 5 10 15 20];     % dB
Nsnap        = min(5e4, numel(s)); % number of points to plot

for i = 1:numel(EbN0_dB_list)
    EbN0_dB  = EbN0_dB_list(i);
    EbN0_lin = 10^(EbN0_dB/10);
    N0       = Eb / EbN0_lin;             % Eb/N0 -> N0
    sigma2   = N0/2;                      % per real dimension (baseband)
    w        = sqrt(sigma2).*(randn(size(s)) + 1j*randn(size(s)));
    r_i      = s + w;                     % noisy constellation at this Eb/N0

    figure;
    scatter(real(r_i(1:Nsnap)), imag(r_i(1:Nsnap)), 7, '.'); grid on; axis equal;
    title(sprintf('64QAM Constellation at Eb/N0 = %g dB', EbN0_dB));
    xlabel('In-phase'); ylabel('Quadrature');
end

% -------------------------------------------
% Lowpass-equivalent PSD via periodogram
% -------------------------------------------
Lup   = 4;                          % upsample factor for discrete-time PSD
s_up  = upsample(s, Lup);           % insert zeros
B     = fir1(51, 1/Lup);            % simple interpolation LPF
s_lpf = filter(B, 1, [s_up; zeros(100,1)]);

Fs_lp = Symbol_rate * Lup;
[Px, f] = periodogram(s_lpf, [], 4096, Fs_lp, 'centered');
figure; plot(f/1e3, 10*log10(Px+eps), 'LineWidth', 1.2); grid on;
xlabel('Frequency (kHz)'); ylabel('PSD (dB/Hz)');
title('Lowpass-equivalent PSD of 64QAM');


% ----- Bonus: passband upconversion -----
try
    % Resample baseband to RF sampling rate if needed
    s_rf = resample(s_lpf, Sampling_frequency, Fs_lp);
    t    = (0:length(s_rf)-1).' / Sampling_frequency;
    xRF  = real(s_rf).*cos(2*pi*Carrier_frequency*t) - imag(s_rf).*sin(2*pi*Carrier_frequency*t);

    [PxRF, fRF] = periodogram(xRF, [], 8192, Sampling_frequency, 'centered');
    figure; plot(fRF/1e6, 10*log10(PxRF+eps), 'LineWidth', 1.2); grid on;
    xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)');
    title('Passband PSD at fc = 1 MHz');
catch
    warning('resample() unavailable; skip passband plot');
end


%% Stage 2: 64QAM Receiver and BER Curve (with theory overlay)

% -----------------------------
% Parameters as per assignment
% -----------------------------
Number_symbols = 2e5;                 % Increase for final report if needed
k              = 6;                    % bits/symbol for 64QAM
Number_bits    = k*Number_symbols;
EbN0_range     = 0:20;                 % in dB
BER            = [];                   % will store BER per Eb/N0 point

% -----------------------------------------
% Constellation and Gray coding (per axis)
% -----------------------------------------
levels8  = [-7 -5 -3 -1 1 3 5 7];              % 8-PAM amplitudes (I and Q)
grayLUT8 = [0 1 3 2 6 7 5 4];                  % binary->Gray (3-bit)
invGray8 = zeros(1,8); invGray8(grayLUT8+1) = 0:7;  % Gray->binary

% -----------------------------------------
% Compute Es and Eb from the constellation
% -----------------------------------------
[Igrid, Qgrid] = meshgrid(levels8, levels8);
Es = mean(abs(Igrid(:) + 1j*Qgrid(:)).^2);     % exact average Es (=42)
Eb = Es / k;                                   % bit energy for 64QAM

% -----------------------------------------
% Sanity check: noiseless channel (Eb/N0=inf)
% -----------------------------------------
% TX: bits -> symbols
bits = randi([0 1], Number_bits, 1);
b6   = reshape(bits, 6, []).';
bitsI = b6(:,1:3); bitsQ = b6(:,4:6);
bI = bitsI(:,1)*4 + bitsI(:,2)*2 + bitsI(:,3);
bQ = bitsQ(:,1)*4 + bitsQ(:,2)*2 + bitsQ(:,3);
gI = grayLUT8(bI+1).'; gQ = grayLUT8(bQ+1).';
s  = levels8(gI+1).' + 1j*levels8(gQ+1).';

% RX: r = s (noiseless)
r = s;

% Demap by nearest-level slicing per axis
[~,idxI] = min(abs(real(r) - levels8), [], 2);
[~,idxQ] = min(abs(imag(r) - levels8), [], 2);

gIh = idxI-1; gQh = idxQ-1;              % Gray indices 0..7
bIh = invGray8(gIh+1).'; bQh = invGray8(gQh+1).';

% Convert 0..7 to 3 bits (MSB..LSB)
recI = [floor(bIh/4), floor(mod(bIh,4)/2), mod(bIh,2)];
recQ = [floor(bQh/4), floor(mod(bQh,4)/2), mod(bQh,2)];
rx_bits_noiseless = reshape([recI recQ].', [], 1);

errors0 = sum(bits ~= rx_bits_noiseless);
assert(errors0==0, 'Noiseless receiver failed (nonzero errors).');

% -----------------------------------------
% BER loop over Eb/N0 = 0:20 dB
% -----------------------------------------
BER = zeros(numel(EbN0_range),1);
firstZeroBER = NaN;

for idx = 1:numel(EbN0_range)
    EbN0_dB  = EbN0_range(idx);
    EbN0_lin = 10.^(EbN0_dB/10);
    N0       = Eb / EbN0_lin;                  % from Eb/N0 definition
    sigma2   = N0/2;                           % per real dimension

    % TX: fresh bits for this Eb/N0
    bits = randi([0 1], Number_bits, 1);
    b6   = reshape(bits, 6, []).';
    bitsI = b6(:,1:3); bitsQ = b6(:,4:6);
    bI = bitsI(:,1)*4 + bitsI(:,2)*2 + bitsI(:,3);
    bQ = bitsQ(:,1)*4 + bitsQ(:,2)*2 + bitsQ(:,3);
    gI = grayLUT8(bI+1).'; gQ = grayLUT8(bQ+1).';
    s  = levels8(gI+1).' + 1j*levels8(gQ+1).';

    % AWGN
    w = sqrt(sigma2).*(randn(Number_symbols,1) + 1j*randn(Number_symbols,1));
    r = s + w;

    % RX: nearest-level slicing per axis
[~,idxI] = min(abs(real(r) - levels8), [], 2);
[~,idxQ] = min(abs(imag(r) - levels8), [], 2);

    gIh = idxI-1; gQh = idxQ-1;
    bIh = invGray8(gIh+1).'; bQh = invGray8(gQh+1).';

    recI = [floor(bIh/4), floor(mod(bIh,4)/2), mod(bIh,2)];
    recQ = [floor(bQh/4), floor(mod(bQh,4)/2), mod(bQh,2)];
    rx_bits = reshape([recI recQ].', [], 1);

    errors = sum(bits ~= rx_bits);
    BER(idx) = errors/Number_bits;

    if BER(idx)==0 && isnan(firstZeroBER)
        firstZeroBER = EbN0_dB;
    end
end

% -----------------------------------------
% Theoretical 64QAM BER (Gray, square, AWGN)
% Pb ≈ (4/k)*(1-1/sqrt(M)) * Q( sqrt(3*k/(M-1)*Eb/N0) )
% Q(x) = 0.5*erfc(x/sqrt(2))
% -----------------------------------------
M = 64;
ebn0 = 10.^(EbN0_range/10);
Pb_th = (4/k).*(1-1/sqrt(M)).*0.5.*erfc( sqrt( 3*k/(M-1).*ebn0 )/sqrt(2) );

% -----------------------------------------
% Plot BER (sim vs theory) and report zero-BER SNR
% -----------------------------------------
figure;
semilogy(EbN0_range, BER, 'o-','LineWidth',1.6); grid on; hold on;
semilogy(EbN0_range, Pb_th, '--','LineWidth',1.8);
xlabel('Eb/N0 (dB)'); ylabel('BER');
title('64QAM BER vs Eb/N0: Simulation Vs Theory');
legend('Simulation','Theory','Location','southwest');

if ~isnan(firstZeroBER)
    fprintf('First Eb/N0 with zero BER (simulation): %.1f dB\n', firstZeroBER);
else
    fprintf('No zero-BER point observed in 0..20 dB range.\n');
end


%% Bonus: 16QAM BER curve and power-efficiency comparison vs 64QAM
% Gray-coded 4-PAM per axis for 16QAM, nearest-level slicing with bsxfun

rng default;

EbN0_range = 0:20;                 % dB
Ns_bns     = 2e5;                  % symbols per SNR for bonus (adjust as needed)
targetBER  = 1e-3;                 % set the report's target BER here

% ---- 16QAM definitions ----
levels4   = [-3 -1 1 3];           % 4-PAM levels per axis
grayLUT4  = [0 1 3 2];             % binary->Gray (2-bit)
invGray4  = zeros(1,4); invGray4(grayLUT4+1) = 0:3;  % Gray->binary
k16       = 4;  M16 = 16;

[I4,Q4]   = meshgrid(levels4, levels4);
Es16      = mean(abs(I4(:)+1j*Q4(:)).^2);     % average symbol energy
Eb16      = Es16/k16;

BER16     = zeros(numel(EbN0_range),1);

for ii = 1:numel(EbN0_range)
    EbN0_dB  = EbN0_range(ii);
    EbN0_lin = 10^(EbN0_dB/10);
    N0       = Eb16 / EbN0_lin;
    sigma2   = N0/2;

    % TX: random bits -> Gray 4-PAM per axis
    bits = randi([0 1], Ns_bns*k16, 1);
    b4   = reshape(bits, 4, []).';
    bI   = b4(:,1)*2 + b4(:,2);                % binary index 0..3
    bQ   = b4(:,3)*2 + b4(:,4);
    gI   = grayLUT4(bI+1).'; gQ = grayLUT4(bQ+1).';
    s16  = levels4(gI+1).' + 1j*levels4(gQ+1).';

    % AWGN
    w    = sqrt(sigma2).*(randn(Ns_bns,1)+1j*randn(Ns_bns,1));
    r16  = s16 + w;

    % RX: nearest-level slicer per axis (safe on all releases via bsxfun)
    [~,idxI] = min(abs(bsxfun(@minus, real(r16), levels4)), [], 2);
    [~,idxQ] = min(abs(bsxfun(@minus, imag(r16), levels4)), [], 2);
    gIh = idxI-1; gQh = idxQ-1;                % Gray indices 0..3
    bIh = invGray4(gIh+1).'; bQh = invGray4(gQh+1).';

    % binary index -> 2 bits (MSB..LSB)
    recI = [floor(bIh/2), mod(bIh,1*2)];       % [MSB, LSB]
    recQ = [floor(bQh/2), mod(bQh,1*2)];
    rx_bits = reshape([recI recQ].', [], 1);

    BER16(ii) = mean(rx_bits ~= bits);
end

% ---- 64QAM theory for comparison (reuse your 64QAM sim or theory) ----
k64   = 6;  M64 = 64;
ebn0  = 10.^(EbN0_range/10);
Pb16  = (4/k16).*(1-1/sqrt(M16)).*0.5.*erfc( sqrt( 3*k16/(M16-1).*ebn0 )/sqrt(2) );
Pb64  = (4/k64).*(1-1/sqrt(M64)).*0.5.*erfc( sqrt( 3*k64/(M64-1).*ebn0 )/sqrt(2) );

% ---- Plots: 16QAM Sim vs Theory ----
figure; semilogy(EbN0_range, BER16, 'o-','LineWidth',1.5); grid on; hold on;
semilogy(EbN0_range, Pb16,  '--','LineWidth',1.8);
xlabel('Eb/N0 (dB)'); ylabel('BER');
title('16QAM BER vs Eb/N0: Simulation and Theory');
legend('16QAM Simulation','16QAM Theory','Location','southwest');

% ---- Power-efficiency comparison at target BER ----
% Use interp1 on theory to read off Eb/N0 where BER equals target
EbN0_16 = interp1(Pb16, EbN0_range, targetBER, 'linear', 'extrap');
EbN0_64 = interp1(Pb64, EbN0_range, targetBER, 'linear', 'extrap');
fprintf('At BER = %.1e: 16QAM requires ~%.2f dB, 64QAM requires ~%.2f dB; delta = %.2f dB (theory)\n', ...
        targetBER, EbN0_16, EbN0_64, EbN0_64 - EbN0_16);
