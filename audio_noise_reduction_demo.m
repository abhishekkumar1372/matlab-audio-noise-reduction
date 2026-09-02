function results = audio_noise_reduction_demo(inputFile)
% AUDIO_NOISE_REDUCTION_DEMO Demonstrates audio denoising with a band-pass filter.
%
% Run with no arguments to generate a reproducible noisy two-tone signal.
% To process a WAV file instead, pass its path as inputFile. The script writes
% noisy_audio.wav, denoised_audio.wav, and denoising_results.png to this folder.

if nargin < 1
    inputFile = '';
end

rng(42);
outputDirectory = fileparts(mfilename('fullpath'));

if isempty(inputFile)
    fs = 16000;
    durationSeconds = 4;
    t = (0:1/fs:durationSeconds-1/fs)';
    cleanAudio = 0.60*sin(2*pi*440*t) + 0.25*sin(2*pi*880*t);
    cleanAudio = cleanAudio / max(abs(cleanAudio));
else
    [cleanAudio, fs] = audioread(inputFile);
    if size(cleanAudio, 2) > 1
        cleanAudio = mean(cleanAudio, 2);
    end
    cleanAudio = cleanAudio / max(max(abs(cleanAudio)), eps);
    t = (0:numel(cleanAudio)-1)' / fs;
end

% Add broadband noise and low-frequency hum to simulate a noisy recording.
whiteNoise = 0.18 * randn(size(cleanAudio));
hum = 0.12 * sin(2*pi*60*t);
noisyAudio = cleanAudio + whiteNoise + hum;

% Retain the useful speech/music band while rejecting hum and high-frequency noise.
filterOrder = 6;
passbandHz = [100 3400];
[b, a] = butter(filterOrder, passbandHz/(fs/2), 'bandpass');
denoisedAudio = filtfilt(b, a, noisyAudio);

inputSnrDb = calculateSnr(cleanAudio, noisyAudio - cleanAudio);
outputSnrDb = calculateSnr(cleanAudio, denoisedAudio - cleanAudio);

% Normalise safely before writing audio artifacts.
noisyToWrite = noisyAudio / max(max(abs(noisyAudio)), 1);
denoisedToWrite = denoisedAudio / max(max(abs(denoisedAudio)), 1);
audiowrite(fullfile(outputDirectory, 'noisy_audio.wav'), noisyToWrite, fs);
audiowrite(fullfile(outputDirectory, 'denoised_audio.wav'), denoisedToWrite, fs);

plotSamples = min(round(0.05 * fs), numel(t));
figure('Color', 'w', 'Position', [100 100 1100 720]);
subplot(2, 2, 1);
plot(t(1:plotSamples), cleanAudio(1:plotSamples), 'LineWidth', 1);
title('Clean Signal'); xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2, 2, 2);
plot(t(1:plotSamples), noisyAudio(1:plotSamples), 'LineWidth', 1);
title(sprintf('Noisy Signal (SNR %.2f dB)', inputSnrDb));
xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2, 2, 3);
plot(t(1:plotSamples), denoisedAudio(1:plotSamples), 'LineWidth', 1);
title(sprintf('Denoised Signal (SNR %.2f dB)', outputSnrDb));
xlabel('Time (s)'); ylabel('Amplitude'); grid on;

subplot(2, 2, 4);
plotSpectrum(noisyAudio, fs, 'Noisy'); hold on;
plotSpectrum(denoisedAudio, fs, 'Denoised');
title('Frequency-Domain Comparison'); xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
legend('Noisy', 'Denoised'); grid on; xlim([0 5000]);

exportgraphics(gcf, fullfile(outputDirectory, 'denoising_results.png'), 'Resolution', 150);

results = struct('sampleRate', fs, 'inputSnrDb', inputSnrDb, ...
    'outputSnrDb', outputSnrDb, 'snrImprovementDb', outputSnrDb-inputSnrDb);
fprintf('Input SNR: %.2f dB\nOutput SNR: %.2f dB\nImprovement: %.2f dB\n', ...
    results.inputSnrDb, results.outputSnrDb, results.snrImprovementDb);
end

function valueDb = calculateSnr(signal, noise)
valueDb = 10*log10(sum(signal.^2) / max(sum(noise.^2), eps));
end

function plotSpectrum(signal, fs, labelText)
sampleCount = numel(signal);
frequencyAxis = (0:floor(sampleCount/2))' * fs / sampleCount;
spectrum = abs(fft(signal)) / sampleCount;
plot(frequencyAxis, 20*log10(spectrum(1:numel(frequencyAxis)) + eps), ...
    'DisplayName', labelText, 'LineWidth', 1);
end
