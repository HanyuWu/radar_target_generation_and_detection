clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Frequency of operation = 77GHz
% Max Range = 200m
% Range Resolution = 1 m
% Max Velocity = 100 m/s
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%speed of light = 3e8
%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant
targetPosition = 50;
targetVelocity = 50;



%% FMCW Waveform Generation

% *%TODO* :
% Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.

sweepBandwidth = 3e8/2/1; % 1.5e9 Hz = 1.5 GHz
Tchirp = 5.5*2*200/3e8; % 7.33e-6 s
Slope = sweepBandwidth/Tchirp; % 2.05e14

%Operating carrier frequency of Radar 
fc= 77e9;             %carrier freq

                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

for i=1:length(t)         
    
    
    % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    r_t(i) = t(i) * targetVelocity + targetPosition;
    td(i) = (2*r_t(i)) / 3e8; % time delay
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    Tx(i) = cos(2*pi*(fc*(t(i)) + (0.5*Slope*t(i)^2)));
    Rx(i) = cos(2*pi*(fc*(t(i)-td(i)) + (0.5*Slope*(t(i)-td(i))^2))); 
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i).*Rx(i); 
    
end

%% RANGE MEASUREMENT


 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
Mix = reshape(Mix,[Nr,Nd]);     %t=linspace(0,Nd*Tchirp,Nr*Nd); 

 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
fft1D = fft(Mix); 
norFft1D = fft1D/Nr;

 % *%TODO* :
% Take the absolute value of FFT output
norFft1D = abs(norFft1D);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
finalFft1D = norFft1D(1:Nr/2+1);


%plotting the range
figure ('Name','Range from First FFT')
% subplot(2,1,1)

 % *%TODO* :
 % plot FFT output 

plot(finalFft1D)
axis ([0 200 0 1]);
ylabel('Normalized Amplitude')
xlabel('Range');


%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);
test = sig_fft2;

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map

% *%TODO* :
%Select the number of Training Cells in both the dimensions.
Tr = 10;
Td = 8;

% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
Gr = 4;
Gd = 4;

% *%TODO* :
% offset the threshold by SNR value in dB
offset = 1.5;


% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
[rRow, vCol] = size(RDM);
noise_level = zeros(rRow-2*(Tr+Gr), vCol-2*(Td+Gd));
[nRow, nCol] = size(noise_level);
CFAR = zeros(size(RDM));

% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.


   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR
window = ones(2*Tr+2*Gr+1,2*Td+2*Gd+1);
window(Tr+1:Tr+2*Gr+1,Td+1:Td+2*Gd+1) = 0;
window = window/((2*Tr+2*Gr+1)*(2*Td+2*Gd+1) - (2*Gr+1)*(2*Gd+1));


for i = 1:nRow
    for j = 1:nCol
        rowInRDM = i+Tr+Gr;
        colInRDM = j+Td+Gd;
        sliceRDM = RDM(rowInRDM-Tr-Gr:rowInRDM+Tr+Gr,colInRDM-Td-Gd:colInRDM+Td+Gd);
        noise_level(i,j) = pow2db(sum(sum(db2pow(window.*sliceRDM))))+ offset;

% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 

    end
end

noise_level = padarray(noise_level,[Tr+Gr,Td+Gd],1e5,'both');
CFAR = RDM.*(RDM>noise_level);

% *%TODO* :
%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.
figure('Name','CA-CFAR Filtered RDM')
surf(doppler_axis,range_axis,CFAR);
colorbar;


 
 