clear;
% Pfad und Dateiname der CSV-Datei (wird vom Halcon-Skript erstellt)
filename = 'Gebogen.csv';
% Aus der CSV werden die Positionen der Referenzpunkte sowie deren
% Verschiebung (jeweils in Pixeln) extrahiert
[Row,Column, RowChanged, ColumnChanged] = textread(filename,'%*u %f %f %f %f %*f %*f','delimiter',';','headerlines',1);

 % Dieser Block kann auskommentiert werden, um Testdaten zu erzeugen,
 % statt Daten aus der CSV einzulesen
 %
 % count = 33;
 % noise = 10000; % Kann genutzt werden, um den Werten künstliches Rauschen
 % hinzuzufügen
 % for n = (1:count)    
 %    for m = (1:count)
 %        b = (n-1)*count+m;
 %        Column(b) = m;
 %        Row(b) = n;
 %        ColumnChanged(b) = Column(b) + noise * (rand(1) - 0.5);
 %        RowChanged(b) = Row(b)+ noise * (rand(1) - 0.5);
 %        
 %        valid(b) = 1;
 %    end
 % end

% Diese Werte müssen gegebenenfalls an die Gegebenheiten des jeweiligen
% Aufbaus angepasst werden
Objektschnittweite = 710 / 1000; % in m
Brennweite = 16 / 1000; % in m
n = 1.51; % Brechwert des Materials
d = 0.85/1000; % Dicke der Oberfläche, in m
Bildhoehe = 2748;
Bildbreite = 3840;
pixelGroesse = 1.67 * 10^-6; % in m, Seitenlänge eines Pixels

RowChanged = RowChanged - Row;
ColumnChanged = ColumnChanged - Column;

% Die Referenzpunkte können in der CSV in beliebiger Reihenfolge vorliegen,
% für den weiteren Ablauf hier ist es aber notwendig, sie zu sortieren
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

% Wenn Referenzpunkte in Halcon nicht zugeordnet werden konnten, bekommen
% sie als Position (0, 0) zugewiesen. Diese Punkte werden in der
% valid-Liste als ungültige Punkte markiert.
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

% Abstand der Punkte in Meter statt Pixel, durch den Abbildungsmaßstab von
% Bildkoordinaten in Objektkoordinaten
ObjektDiffX = (pixelGroesse * ColumnChanged) ./ beta;
ObjektDiffY = (pixelGroesse * RowChanged) ./ beta;

% Verkippungswinkel in X- sowie Y-Richtung
gammaX = ObjektDiffX./sqrt((ObjektDiffX/Objektschnittweite).^2 + 1);
gammaX = gammaX * n / (d * (n-1)) - xAlpha;

gammaY = ObjektDiffY./sqrt((ObjektDiffY./Objektschnittweite).^2 + 1);
gammaY = gammaY * n / (d * (n-1)) - yAlpha;

% Matrix mit den aus den Winkeln erhaltenen Steigungen erstellen
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
            % Ermitteln der Steigung (Länge der Gegenkathete eines Dreiecks mit Winkel
            % Gamma)
            xGradient_Mat(n,m) = atan(gammaY(b));
            yGradient_Mat(n,m) = atan(gammaX(b));
        end
    end
end

% Abstandsmatrizen erstellen, die die Abstände der Punkte zu ihren Nachbarn
% in Pixeln beinhalten
deltaRow_Mat = zeros(sqrtCount,sqrtCount);
deltaColumn_Mat = zeros(sqrtCount,sqrtCount);
for n = 1 : sqrtCount
    if n ~= 1 
        deltaRow_Mat(n,:) = Row_Mat(n,:) - Row_Mat(n-1,:);
        deltaColumn_Mat(:,n) = Column_Mat(:,n) - Column_Mat(:,n-1);
    end
end

% Berechnung und Interpolation der Oberfläche
% Startpunkt der Rekonstruktion ist die linke obere Ecke. Entlang der Ränder
% ist die Rekonstruktion dann eindeutig, zu allen anderen Punkten führen
% dann zwei Wege (von links sowie von oben), von diesen beiden wird der
% Mittelwert verwendet.
Height_Mat = zeros(sqrtCount,sqrtCount);
for n = (1:sqrtCount)
    for m = (1:sqrtCount)        
        if(n==1 && m==1)   
            Height_Mat(n,m) = 0;
        elseif(n==1)
            % Rand in X-Richtung
            Height_Mat(n,m) = Height_Mat(n,m-1) + deltaColumn_Mat(n,m) *  xGradient_Mat(m,n); 
        elseif(m==1)
            % Rand in Y-Richtung
            Height_Mat(n,m) = Height_Mat(n-1,m) + deltaRow_Mat(n,m) *  yGradient_Mat(m,n); 
        else
            % Durchschnitt der aus der X- sowie Y-Richtung kommenden Höhen
            xPart = Height_Mat(n, m-1) + deltaColumn_Mat(n,m) * xGradient_Mat(m,n);
            yPart = Height_Mat(n-1, m) + deltaRow_Mat(n,m) * yGradient_Mat(m,n);
            Height_Mat(n,m) = mean([xPart, yPart]);
        end
    end
end

% Plots erstellen

% Plot der Referenzpunkte ohne Interpolation
figure (1)
plot3(Row_Mat,Column_Mat,Height_Mat,'.')

% Rekonstruktion der Oberfläche mit maßstabsgetreuen Achsen
figure (2)
hold on
surf(Row_Mat*1000,Column_Mat*1000,Height_Mat*1000)
xlabel('x / mm');
ylabel('y / mm');
zlabel('z / mm');
axis equal

% Plot der Verschiebungsvektoren der Referenzpunkte
% figure(3)
% quiver(Column,Row,ColumnChanged,RowChanged)