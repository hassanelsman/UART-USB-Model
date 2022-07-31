%reading the json file and get the paramerters of the usb from it 
USBConf = jsondecode(char(fread(fopen('usbconf.json'))));  

USB_Idle = 1;
USB_Sync_Pattern = USBConf.parameters.sync_pattern;
USB_Pid= USBConf.parameters.pid;
USB_Address= USBConf.parameters.dest_address;%is that will include in the conf or we add it ?
USB_Payload_size= USBConf.parameters.payload;
USB_bit_duration = USBConf.parameters.bit_duration;

%reading the input file and turn it to binary 
%for ww = 1 : 3
inputs = fread(fopen('inputdata.txt'));

%inputs =repmat(inputs,ww,1);

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
Total_Useful_Time_USB = USB_bit_duration * filesize(1,1);
efficiency_USB = 1* Total_Useful_Time_USB / Total_Time_USB ; 
overhead_USB = 1 - efficiency_USB ;


% plot a sample of 2 packets sending versus time like as a time diagram
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

%put  the output data in a structure 
O(2).protocol_name = "UART";
O(2).outputs.total_tx_time = Total_Time_USB ;
O(2).outputs.overhead = overhead_USB ;
O(2).outputs.efficiency = efficiency_USB ;

% encode the structure to json code and make it pretty
str = jsonencode(O);
new_string = strrep(str, '{', '{\n\t\t');
new_string = strrep(new_string, ',', ',\n\t\t');

% Write the string to file
fid = fopen("Output_usb.json",'w');
fprintf(fid, new_string); 
fclose(fid);

%A_TTE(1,ww)= Total_Time_USB ;
%A_OVD(1,ww)= overhead_USB ;
%A_EFF(1,ww)= efficiency_USB ;
%A_Axix(1,ww);
%plot
%end