clear;
filename = 'gebogen.csv';
[Row,Column, RowChanged, ColumnChanged] = textread(filename,'%*u %f %f %f %f %*f %*f','delimiter',';','headerlines',1);

% % To create test data
 %count = 33;
 %noise = 10000;
 %for n = (1:count)    
 %    for m = (1:count)
 %        b = (n-1)*count+m;
 %        Column(b) = m;
 %        Row(b) = n;
 %        ColumnChanged(b) = Column(b) + noise * (rand(1) - 0.5);
 %        RowChanged(b) = Row(b)+ noise * (rand(1) - 0.5);
 %        
 %        valid(b) = 1;
 %    end
 %end

RowChanged = RowChanged - Row;
ColumnChanged = ColumnChanged - Column;

Objektschnittweite = 710 / 1000; % in m
Brennweite = 16 / 1000; % in m
n = 1.51;
d = 0.85/1000; % in m
Bildhoehe = 2748;
Bildbreite = 3840;
pixelGroesse = 1.67 * 10^-6; % in m pro pixel

count = numel(Row);
index = Row * Bildbreite + Column;
[SortedByIndex, Indices] = sort(index, 'ascend');
beta = 1 / (1 - Objektschnittweite/Brennweite);
Mittelpunkt = [(Bildbreite-1)/2 (Bildhoehe-1)/2];
for i=1:count
    sortedRow(i) = Row(Indices(i));
    sortedColumn(i) = Column(Indices(i));
    sortedRowChanged(i) = RowChanged(Indices(i));
    sortedColumnChanged(i) = ColumnChanged(Indices(i));

end
Row = sortedRow;
Column = sortedColumn;
RowChanged = sortedRowChanged;
ColumnChanged = sortedColumnChanged;

valid = ones(1,count);
for i=1:count
    centeredX(i) = (Column(i) - Mittelpunkt(1)) * pixelGroesse / beta;
    centeredY(i) = (Row(i) - Mittelpunkt(2)) * pixelGroesse / beta;
    xAlpha(i) = atan2(centeredX(i),Objektschnittweite);
    yAlpha(i) = atan2(centeredY(i),Objektschnittweite);
    if(centeredX(i) == 0 && centeredY(i) == 0)
        valid(i) = 0;
    end
end

columnChangedReal = pixelGroesse * ColumnChanged;
rowChangedReal = pixelGroesse * RowChanged;

ObjektDiffX = columnChangedReal./beta;
ObjektDiffY = rowChangedReal./beta;

gammaX = ObjektDiffX./sqrt((ObjektDiffX/Objektschnittweite).^2 + 1);
gammaX = gammaX * n / (d * (n-1)) - xAlpha;

gammaY = ObjektDiffY./sqrt((ObjektDiffY./Objektschnittweite).^2 + 1);
gammaY = gammaY * n / (d * (n-1)) - yAlpha;



% Create matrices from vectors
sqrtCount = sqrt(count);
Row_Mat = zeros(sqrtCount,sqrtCount);
Column_Mat = zeros(sqrtCount,sqrtCount);
xGradient_Mat = zeros(sqrtCount,sqrtCount);
yGradient_Mat = zeros(sqrtCount,sqrtCount);
for n = 1:sqrtCount
    for m = 1:sqrtCount
        b = (n-1) * sqrtCount + m;
        Row_Mat(n,m) = centeredY(b);
        Column_Mat(n,m) = centeredX(b);        
        if valid(b) ~= 0            
            xGradient_Mat(n,m) = atan(gammaY(b));
            yGradient_Mat(n,m) = atan(gammaX(b));
        end
    end
end

% Get the delta matrices
deltaRow_Mat = zeros(sqrtCount,sqrtCount);
deltaColumn_Mat = zeros(sqrtCount,sqrtCount);
for n = 1 : sqrtCount
    if n ~= 1 
        deltaRow_Mat(n,:) = Row_Mat(n,:) - Row_Mat(n-1,:);
        deltaColumn_Mat(:,n) = Column_Mat(:,n) - Column_Mat(:,n-1);
    end
end

%Do the interpolation here
Height_Mat = zeros(sqrtCount,sqrtCount);
for n = (1:sqrtCount)
    for m = (1:sqrtCount)        
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

%[X,Y] = meshgrid(1:sqrtCount,1:sqrtCount);

%Plot stuff
%surf(Row_Mat,Column_Mat,Height_Mat)
figure (1)
plot3(Row_Mat,Column_Mat,Height_Mat,'.')
figure (2)
%hold on
surf(Row_Mat,Column_Mat,Height_Mat)
xlabel('x');
ylabel('y');

 figure(3)
 quiver(Column,Row,ColumnChanged,RowChanged)

