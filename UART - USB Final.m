Conf(1) = jsondecode(char(fread(fopen('uartconf.json'))));
Conf(2) = jsondecode(char(fread(fopen('usbconf.json'))));  

str = jsonencode(Conf);
new_string = strrep(str, '{', '{\n\t\t');
new_string = strrep(new_string, ',', ',\n\t\t');

fid = fopen("conf.json",'w');
fprintf(fid, new_string); 
fclose(fid);


for i=1:length(Conf)
   switch Conf(i).protocol_name
   case 'UART'
       uart= true;
        [d, f, g]=UART_Protocol(uart,1);
       
   case 'USB'
       usb= true;
        [dd, ff, gg]=USB_Protocol(usb,1);
   otherwise
       disp("error. not correct protocol, justify the conjeration file ");
   end  
end

if (Conf(1).parameters.bit_duration==Conf(2).parameters.bit_duration)& uart & usb
 create_output(d, f, g, dd, ff, gg);
 
for i=1:10
    uart= false;
    usb= false;
     [d, f, g]=UART_Protocol(uart,i);
     [dd, ff, gg]=USB_Protocol(usb,i);
        A_TTE_uart(1,i)= g ;
        A_OVD_uart(1,i)= f ;
        A_EFF_uart(1,i)= d ;
        
       A_TTE_usb(1,i)= gg ;
       A_OVD_usb(1,i)= ff ;
       A_EFF_usb(1,i)= dd ;
       
       A_data_size_usb(1,i)=gg*dd/Conf(2).parameters.bit_duration; 
       A_data_size_uart(1,i)=g*d/Conf(1).parameters.bit_duration; 

end
%Total time plotting
 figure ;
subplot(2,2,1);
plot(A_data_size_usb,A_TTE_usb);
title('UART : Total Time Vs File Size')

subplot(2,2,2);
plot(A_data_size_usb,A_TTE_uart,'g');
title('USB : Total Time Vs File Size')
subplot(2,2,[3,4]);
plot(A_data_size_usb,A_TTE_usb,'b',A_data_size_usb,A_TTE_uart,'g');
title(' UART and Total Time Vs increasing File Size')
grid on ;
figure;

%Overhead plotting
subplot(2,2,1);
plot(A_data_size_usb,A_OVD_usb);
title('USB : Overhead  Vs File Size')

subplot(2,2,2);
plot(A_data_size_usb,A_OVD_uart,'g');
title('UART : Overhead Vs File Size')

subplot(2,2,[3,4]);
plot(A_data_size_usb,A_OVD_usb,'b',A_data_size_usb,A_OVD_uart,'g');
title(' UART and USB Overhead Vs increasing File Size');
grid on ;





end
function  [a b c]=UART_Protocol (uart,n_rep)
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
inputs =repmat(inputs,n_rep,1);

% convert the input from character to binary with size of colums equal to the Uart data 
trans_data = dec2bin(inputs ,UART_data_bits);

% get the size of the input data matrix 
[numRows,numCols] = size (trans_data);

% calculate the size of the Uart Word after the start bit , stop , and parity
sum = UART_data_bits+2+UART_stop_bit;

TotalTime_uart = 0 ;

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
    TotalTime_uart =  TotalTime_uart + UART_bit_duration* numColsF;
    c=TotalTime_uart;
    Useful =  Useful + UART_data_bits;
    
    %flip the channel to be versus time and put all the data in single array
    channelf  = fliplr(channel);
    M = [M channelf];
end
%calc the Efficiency and the Overhead percentage
Efficiency_uart =  Useful /(numColsF*numRows);
a=Efficiency_uart;
Overhead_uart= 1- Efficiency_uart ;
b=Overhead_uart;


if uart
%plot a sample of 2 bytes sending versus time like as a time diagram
figure ;
Y =  double(M) - 48;
YAxix = Y (1:2*numColsF);
XAxix = [0:2*numColsF-1]*UART_bit_duration;
Z = stairs(XAxix,YAxix);
Z.LineWidth = 3;
grid on;
end


end

function  [aa bb cc]=USB_Protocol (usb,n_rep)
%reading the json file and get the paramerters of the usb from it 
USBConf = jsondecode(char(fread(fopen('usbconf.json'))));  

USB_Idle = 1;
USB_Sync_Pattern = USBConf.parameters.sync_pattern;
USB_Pid= USBConf.parameters.pid;
USB_Address= USBConf.parameters.dest_address;%is that will include in the conf or we add it ?
USB_Payload_size= USBConf.parameters.payload;
USB_bit_duration = USBConf.parameters.bit_duration;

%reading the input file and turn it to binary 
inputs = fread(fopen('inputdata.txt'));
inputs =repmat(inputs,n_rep,1);
trans_data = dec2bin(inputs ,8);

%sync pattern to binary
T_Sync=double(transpose(USB_Sync_Pattern))-48;
% reshape the input data to be formed from LSB to MSB in one column
data0=double(trans_data)-48;
data1=fliplr(data0); 
data2=transpose(data1); 
data3=reshape(data2,[],1);

%address to binary and to be in column
add=double(USB_Address)-48;
add_f= fliplr(add);
add_t=transpose(add_f);

%Pid and calculate the number of packets
filesize=size(data3);
last_bytes=rem(filesize(1,1)/8,USB_Payload_size);
numof_packets=(((filesize(1,1)/8)-last_bytes)/USB_Payload_size);


%creating the PID matrix 
packetID=[1:numof_packets];
packetID=rem(packetID,2^(USB_Pid-4)); %as if PID is more than 2^(PID-4)
packetID=transpose(packetID);
paceetID_b=double(dec2bin(packetID,4))-48;
paceetID_v=transpose(fliplr(paceetID_b));
paceetID_c=not(paceetID_v);

%justify the components in one matrix
sync_p_matrix=repmat(T_Sync,1,numof_packets);
packetID_matrix=cat(1,paceetID_v,paceetID_c);
address_matrix=repmat(add_t,1,numof_packets);
SizeOfCompletePackets = filesize(1,1)-last_bytes*8;
data_matrix=reshape(data3(1:SizeOfCompletePackets),[USB_Payload_size*8,numof_packets]);
%contacination for all componets of usb packet in one matrix
packets_matrix = cat(1,sync_p_matrix,packetID_matrix,address_matrix,data_matrix);

%add bit stuffing in every packet
nrzi_tansmitted_packets=[];
EOD=[0;0;0];

for x=1:numof_packets
a_packet=packets_matrix(:,x);
count=0;
stuffcount=0;
[M N]=size(a_packet);
j=1;
while j<=M-5+stuffcount
    for i=j:j+5
        if a_packet(i)==1
            count=count+1;
        else
            count=0;
            break;
        end
    
    end
    
    if(count ==6)
        a_packet=[a_packet(1:j+5);0;a_packet(j+6 : end)];
        count=0;
        stuffcount=stuffcount+1;
    end
    j=j+1;    
end
%size_of_a_packet(:,x)=length(a_packet);
%nrz_tansmitted_packets=[nrz_tansmitted_packets  a_packet];


%coverting each packet to NRZI

b_packet=a_packet;

%for first bit in the packet
idle=1;
   if b_packet(1)==1
        b_packet(1)=idle;
   else
       b_packet(1)=not(idle); 
   end

%for the rest for the packet from 2:end
  [M N]=size(b_packet);
    for j=2:M
     if b_packet(j)==1
         b_packet(j)=b_packet(j-1);
     else
         b_packet(j)=not(b_packet(j-1)); 
     end
    
    end
    
size_of_a_packet(:,x)=length(a_packet);

% addin the end of the packet
b_packet = [b_packet ; EOD];
size_of_b_packet(:,x)=length(b_packet);
nrzi_tansmitted_packets=[nrzi_tansmitted_packets ; b_packet ];

end


%--------------------------------------------------------------------------------------------------
%--------------------------------------------------------------------------------------------------
FsizeNC(1,1)=0;
if (last_bytes~=0)
numof_NC_packets=numof_packets+1;
    
%critical case (not full size for all packet (last packet)
data4 = data3(SizeOfCompletePackets+1:filesize(1,1));
%create PID vector for the last packet 
NC_packetID=rem(numof_NC_packets,2^(USB_Pid-4));
NC_packetID=double(dec2bin(NC_packetID))-48;
NC_packetID=transpose(fliplr(NC_packetID));
NC_packetID=[NC_packetID ; not(NC_packetID)];

%contacination
packets_NC_matrix = cat(1,T_Sync,NC_packetID,add_t,data4);


%add bit stuffing in the last Not Complete
countNC=0;
stuffcountNC=0;
[MNC NNC]=size(packets_NC_matrix);
jj=1;
while jj<=MNC-5+stuffcountNC   
    for ii=jj:jj+5
        if packets_NC_matrix(ii)==1
            countNC=countNC+1;
        else
            countNC=0;
            break;
        end
    
    end 
    
    
    if(countNC ==6)
        packets_NC_matrix=[packets_NC_matrix(1:jj+5);0;packets_NC_matrix(jj+6 : end)];
        countNC=0;
        stuffcountNC=stuffcountNC+1;
         
    end
        jj=jj+1;
end
size_of_a_NC_packet(:,1)=length(packets_NC_matrix);

%coverting the last Not Complete packet to NRZI
%for first bit in the packet
idle=1;
   if packets_NC_matrix(1)==1
        packets_NC_matrix(1)=idle;
   else
       packets_NC_matrix(1)=not(idle); 
   end

%for the rest for the packet from 2:end
  [MNC NNC]=size(packets_NC_matrix);
    for jj=2:MNC
     if packets_NC_matrix(jj)==1
         packets_NC_matrix(jj)=packets_NC_matrix(jj-1);
     else
         packets_NC_matrix(jj)=not(packets_NC_matrix(jj-1)); 
     end
    
    end

%creating the last shap of transmitted packet
finale_transmitted_NC_packets = cat(1,packets_NC_matrix,EOD);
FsizeNC = size(finale_transmitted_NC_packets);

end

%calculate the percentage overhead, and the efficiency
FsizeC  = size(nrzi_tansmitted_packets);
Total_Time_USB = USB_bit_duration * (FsizeC(1,1)+FsizeNC(1,1));
cc=Total_Time_USB;
Total_Useful_Time_USB = USB_bit_duration * filesize(1,1);
efficiency_USB =  Total_Useful_Time_USB / Total_Time_USB ; 
aa=efficiency_USB;
overhead_USB = 1 - efficiency_USB ;
bb=overhead_USB;

if usb
%plot a sample of 2 packets sending versus time like as a time diagram
figure ;
P1Axix = [nrzi_tansmitted_packets(1:size_of_b_packet(1,1))];
X1Axix = [0:size_of_b_packet(1,1)-1]*USB_bit_duration;
Z = stairs(X1Axix,P1Axix);

figure ;
P2Axix = [nrzi_tansmitted_packets(size_of_b_packet(1,1)+1:size_of_b_packet(1,1)+size_of_b_packet(1,2))];
X2Axix = [size_of_b_packet(1,1):size_of_b_packet(1,1)+size_of_b_packet(1,2)-1]*USB_bit_duration;
Z = stairs(X2Axix,P2Axix);
%Z.LineWidth = 2;
grid on;
end

end

function create_output(d,f,g,dd,ff,gg)

    % put  the output data in a structure 

       O(1).protocol_name = "UART";
       O(1).outputs.total_tx_time = g ;
       O(1).outputs.overhead = f ;
       O(1).outputs.efficiency = d ;
       
    O(2).protocol_name = "USB";
    O(2).outputs.total_tx_time = gg ;
    O(2).outputs.overhead = ff ;
    O(2).outputs.efficiency = dd ;

       
    str = jsonencode(O);
    new_string = strrep(str, '{', '{\n\t\t');
    new_string = strrep(new_string, ',', ',\n\t\t');

    fid = fopen("output.json",'w');
    fprintf(fid, new_string); 
    fclose(fid);
end
