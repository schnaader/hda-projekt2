filename = '20180502122649086_Data.csv';
[Row,Column,xAngle,yAngle] = textread(filename,'%*u %f %f %*f %*f %f %f','delimiter',';','headerlines',1);

%Let the rows and columns start at 0
minRow = min(Row);
minColumn = min(Column);
Row = Row - minRow;
Column = Column - minColumn;

length = sqrt(numel(Row));

%Get the norm vectors and change the read out vectors to matrices
norm = zeros(length,length,3);
for n = (1:length)
    for m = (1:length)
    b = (n-1)* length + m;
    norm(n,m,1) = sin(xAngle(b))*cos(yAngle(b)); %x
    norm(n,m,2) = sin(xAngle(b))*sin(yAngle(b)); %y
    norm(n,m,3) = cos(yAngle(b));                %z
    ColumnMat(n,m) = Column(b);
    RowMat(n,m) = Row(b);
    end
end

%Do the interpolation here
approximation = zeros(length,length);
for n = (1:length)
    for m = (1:length)        
        if(n==1 && m==1)   
            approximation(n,m) = 0;
        elseif(n==1)
            approximation(n,m) = norm(n,m,1) / norm(n,m,3) * (ColumnMat(n,m) - ColumnMat(n,m-1)); %only interpolate in x direction
        elseif(m==1)
            approximation(n,m) = norm(n,m,2) / norm(n,m,3) * (RowMat(n,m) - RowMat(n-1,m)); %only interpolate in y direction
        else
            approximation(n,m) = (norm(n,m,1) / norm(n,m,3) * (ColumnMat(n,m) - ColumnMat(n,m-1)) + norm(n,m,2) / norm(n,m,3) * (RowMat(n,m) - RowMat(n-1,m)))/2; %average from x and y direction
        end
    end
end

%Plot stuff
surf(RowMat,ColumnMat,approximation)

