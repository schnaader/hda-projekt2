clear;
filename = '20180525102331232_Data.csv';
[Row,Column,valid,xAngle,yAngle] = textread(filename,'%*u %f %f %f %*f %f %f','delimiter',';','headerlines',1);

% To create test data
% count = 16;
% noise = 0;
% for n = (1:count)    
%     for m = (1:count)
%         b = (n-1)*count+m;
%         Column(b) = m + noise * (rand(1) - 0.5);
%         Row(b) = n + noise * (rand(1) - 0.5);
%         
% %         xAngle((n-1)*count+m) = sin(2 * pi * ((n-1)*count+m));
% %         yAngle((n-1)*count+m) = cos(2 * pi * ((n-1)*count+m));
%         
%         %xAngle(b) = sin(n /count * pi);
%         %yAngle(b) = cos(m /count * pi);
%         %xAngle(b) = 1;
%         %yAngle(b) = 0;
%     end
% end

% Let the rows and columns start at 0
Row = Row - min(Row);
Column = Column - min(Column);

% Determine the size
length = sqrt(numel(Row));

% Create matrices from vectors
Row_Mat = zeros(length,length);
Column_Mat = zeros(length,length);
xGradient_Mat = zeros(length,length);
yGradient_Mat = zeros(length,length);
for n = 1:length
    for m = 1:length
        b = (n-1) * length + m;
        Row_Mat(n,m) = Row(b);
        Column_Mat(n,m) = Column(b);
        
        if valid(b) ~= 0            
            xGradient_Mat(n,m) = atan(xAngle(b));
            yGradient_Mat(n,m) = atan(yAngle(b));
        end
    end
end

% Get the delta matrices
deltaRow_Mat = zeros(length,length);
deltaColumn_Mat = zeros(length,length);
for n = 1 : length
    if n ~= 1 
        deltaRow_Mat(n,:) = Row_Mat(n,:) - Row_Mat(n-1,:);
        deltaColumn_Mat(:,n) = Column_Mat(:,n) - Column_Mat(:,n-1);
    end
end

%Do the interpolation here
Height_Mat = zeros(length,length);
for n = (1:length)
    for m = (1:length)        
        if(n==1 && m==1)   
            Height_Mat(n,m) = 0;
        elseif(n==1)
            % only interpolate in x direction
            Height_Mat(n,m) = Height_Mat(n,m-1) + deltaColumn_Mat(n,m) *  xGradient_Mat(m,n); 
        elseif(m==1)
            %only interpolate in y direction
            Height_Mat(n,m) = Height_Mat(n-1,m) + deltaRow_Mat(n,m) *  yGradient_Mat(m,n); 
        else
            %average from x and y direction
            xPart = Height_Mat(n, m-1) + deltaColumn_Mat(n,m) *  xGradient_Mat(m,n);
            yPart = Height_Mat(n-1, m) + deltaRow_Mat(n,m) *  yGradient_Mat(m,n);
            Height_Mat(n,m) = mean([xPart, yPart]);
        end
    end
end

%Plot stuff
surf(Row_Mat,Column_Mat,Height_Mat)

