% open and read the configration_file.json 
UartConf = jsondecode(char(fread(fopen('uartconf.json'))));

% make the configration parametar
UART_start_bit = 0;
UART_stop_bit = UartConf.parameters.stop_bits;
UART_data_bits = UartConf.parameters.data_bits;
UART_parity = UartConf.parameters.parity;
UART_bit_duration = UartConf.parameters.bit_duration;

% read the input_file.txt
inputs = fread(fopen('inputdata.txt'));
%for ww =1 : 3
%    inputs =repmat(inputs,ww,1);

% convert the input from character to binary with size of colums equal to the Uart data 
trans_data = dec2bin(inputs ,UART_data_bits);

% get the size of the input data matrix 
[numRows,numCols] = size (trans_data);

% calculate the size of the Uart Word after the start bit , stop , and parity
sum = UART_data_bits+2+UART_stop_bit;

TotalTime = 0 ;

% switch to choose the size if the parity is none
switch UART_parity
    case 'none'
        channel = char(zeros(1,sum-1));
    case 'even'
        channel = char(zeros(1,sum));
    case 'odd'
        channel = char(zeros(1,sum));
    otherwise
        fprintf("error in Configration ");
end

M=[];
Useful = 0 ;

% loop to the dimension of matrix input row by row 
for i=1:numRows
    holding_register = trans_data(i,:);
    
    % send the start bit in the channel
    channel(1,1)='0';
    
    parity = 0 ;
    % loop to the dimension of matrix colum  by colum in the row 
    for x=0:(UART_data_bits-1);
        channel = circshift(channel,1);
        %send the LSB in the MSB in the channel after shiftig the previos.
        channel(1,1)=holding_register(1,8-x);
        %convert the first bit to double
        a = double(channel(1,1))-48;
        %XOR the first bit with the prev. to calc the parity
        parity = xor(a,parity);
    end
    
    % switch to change the parity if ODD or Even the add it.
    switch UART_parity
        case 'odd'
            parity = ~parity ;
            channel = circshift(channel,1);
            channel(1,1)= double (parity + 48 );
        case 'even'
            channel = circshift(channel,1);
            channel(1,1)= double (parity + 48 );
    end
    % add the stop bit
        switch UART_stop_bit
        case 1
             channel = circshift(channel,1);
             channel(1,1)='1';
        case 2
             channel = circshift(channel,1);
             channel(1,1)='1';
             channel = circshift(channel,1);
             channel(1,1)='1';
        end
    

    [numRowsF,numColsF] = size (channel);
    
    %calc the total time and the total useful bits  
    TotalTime =  TotalTime + UART_bit_duration* numColsF;
    Useful =  Useful + UART_data_bits;
    
    %flip the channel to be versus time and put all the data in single array
    channelf  = fliplr(channel);
    M = [M channelf];
end
%calc the Efficiency and the Overhead percentage
Efficiency = 1 * Useful /(numColsF*numRows);
Overhead = 1- Efficiency ;

% put  the output data in a structure 
O(1).protocol_name = "UART";
O(1).outputs.total_tx_time = TotalTime ;
O(1).outputs.overhead = Overhead ;
O(1).outputs.efficiency = Efficiency ;

%plot a sample of 2 bytes sending versus time like as a time diagram
figure ;
Y =  double(M) - 48;
YAxix = Y (1:2*numColsF);
XAxix = [0:2*numColsF-1]*UART_bit_duration;
Z = stairs(XAxix,YAxix);
Z.LineWidth = 3;
grid on;

% encode the structure to json code and make it pretty
str = jsonencode(O);
new_string = strrep(str, '{', '{\n\t\t');
new_string = strrep(new_string, ',', ',\n\t\t');

% Write the string to file
fid = fopen("Output_uart.json",'w');
fprintf(fid, new_string); 
fclose(fid);

%A_TTE(1,ww)= TotalTime ;
%A_OVD(1,ww)= Overhead ;
%A_EFF(1,ww)= Efficiency ;
%A_Axix(1,ww);
%plot
%end