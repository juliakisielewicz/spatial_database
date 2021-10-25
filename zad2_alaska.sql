-- 1. Wyznacz liczbę budynków (tabela: popp, atrybut: f_codedesc, reprezentowane, jako punkty) 
-- położonych w odległości mniejszej niż 1000 m od głównych rzek. 
-- Budynki spełniające to kryterium zapisz do osobnej tabeli tableB.

SELECT COUNT(*) FROM popp, rivers WHERE popp.f_codedesc = 'Building' AND ST_Contains(ST_Buffer(rivers.geom, 1000.0), popp.geom);

SELECT popp.gid, popp.cat, popp.f_codedesc, popp.f_code, popp.type, popp.geom INTO tableB 
	 FROM popp, rivers WHERE popp.f_codedesc = 'Building' 
	 AND ST_Contains(ST_Buffer(rivers.geom, 1000.0), popp.geom);
	 
SELECT * FROM tableB;

-- 2.	Utwórz tabelę o nazwie airportsNew. Z tabeli airports zaimportuj nazwy lotnisk, ich geometrię, 
-- a także atrybut elev, reprezentujący wysokość n.p.m.
SELECT name, geom, elev INTO airportsNew FROM airports;

SELECT * FROM airportsNew;

-- Znajdź lotnisko, które położone jest najbardziej na zachód i najbardziej na wschód.  
SELECT name FROM airportsNew 
WHERE ST_Y(geom) = (SELECT MIN(ST_Y(geom)) FROM airportsNew) --wschod
					OR ST_Y(geom) = (SELECT MAX(ST_Y(geom)) FROM airportsNew);	--zachod
							
-- Do tabeli airportsNew dodaj nowy obiekt - lotnisko, które położone jest w punkcie środkowym drogi 
-- pomiędzy lotniskami znalezionymi w punkcie a. Lotnisko nazwij airportB. Wysokość n.p.m. przyjmij dowolną.
INSERT INTO airportsNew (name, geom, elev)
(SELECT 'airportB', 
 ST_Centroid(ST_ShortestLine((SELECT geom FROM airportsNew ORDER BY ST_Y(geom) LIMIT 1), 
							 (SELECT geom FROM airportsNew ORDER BY ST_Y(geom) DESC LIMIT 1))),
 '78.000');

SELECT * FROM airportsNew;

--3. Wyznacz pole powierzchni obszaru, który oddalony jest mniej niż 1000 jednostek 
--od najkrótszej linii łączącej jezioro o nazwie ‘Iliamna Lake’ i lotnisko o nazwie „AMBLER”

SELECT ST_Area(ST_Buffer(ST_ShortestLine(lakes.geom, airports.geom), 1000)) FROM lakes, airports 
	WHERE lakes.names = 'Iliamna Lake' AND airports.name = 'AMBLER';

--4. Napisz zapytanie, które zwróci sumaryczne pole powierzchni poligonów 
---reprezentujących poszczególne typy drzew znajdujących się na obszarze tundry i bagien (swamps). 

SELECT vegdesc, SUM(area_km2) FROM trees WHERE 
geom IN 
	(SELECT trees.geom FROM trees, tundra WHERE ST_Contains(tundra.geom, trees.geom))
OR geom IN 
	(SELECT trees.geom FROM trees, swamp WHERE ST_Contains(swamp.geom, trees.geom))
GROUP BY vegdesc;
