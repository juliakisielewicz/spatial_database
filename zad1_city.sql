-- 2.	Utwórz pustą bazę danych.
CREATE DATABASE city;
CREATE SCHEMA plan;
-- 3.	Dodaj funkcjonalności PostGIS’a do bazy poleceniem CREATE EXTENSION postgis;

CREATE EXTENSION postgis;

-- 4.	Na podstawie poniższej mapy utwórz trzy tabele: 
--buildings (id, geometry, name), roads (id, geometry, name), poi (id, geometry, name).

CREATE TABLE plan.buildings (
id INT PRIMARY KEY,
geom GEOMETRY,
_name VARCHAR(10));

SELECT * FROM plan.buildings
--
--DROP TABLE plan.roads;
--DROP TABLE plan.poi
CREATE TABLE plan.roads (
id INT PRIMARY KEY,
geom GEOMETRY,
_name VARCHAR(10));

CREATE TABLE plan.poi (
id INT PRIMARY KEY,
geom GEOMETRY,
_name VARCHAR(1));


-- 5.	Współrzędne obiektów oraz nazwy (np. BuildingA) należy odczytać z mapki umieszczonej poniżej. 
--Układ współrzędnych ustaw jako niezdefiniowany.

INSERT INTO plan.buildings VALUES
(
	1,
	ST_GeomFromText('POLYGON((8.0 4.0, 10.5 4.0, 10.5 1.5, 8.0 1.5, 8.0 4.0))'),
	'BuildingA'
),
(
	2,
	ST_GeomFromText('POLYGON((4.0 7.0, 6.0 7.0, 6.0 5.0, 4.0 5.0, 4.0 7.0))'),
	'BuildingB'

),
(
	3,
	ST_GeomFromText('POLYGON((3.0 8.0, 5.0 8.0, 5.0 6.0, 3.0 6.0, 3.0 8.0))'),
	'BuildingC'

),
(
	4,
	ST_GeomFromText('POLYGON((9.0 9.0, 10.0 9.0, 10.0 8.0, 9.0 8.0, 9.0 9.0))'),
	'BuildingD'

),
(
	5,
	ST_GeomFromText('POLYGON((1.0 2.0, 2.0 2.0, 2.0 1.0, 1.0 1.0, 1.0 2.0))'),
	'BuildingF'

);

INSERT INTO plan.roads VALUES
(
	1,
	ST_GeomFromText('LINESTRING(0.0 4.5, 12.0 4.5)'),
	'RoadX'
),
(
	2,
	ST_GeomFromText('LINESTRING(7.5 10.5, 7.5 0.0)'),
	'RoadY'
);

INSERT INTO plan.poi VALUES
(
	1,
	ST_GeomFromText('POINT(1.0 3.5)'),
	'G'
),
(
	2,
	ST_GeomFromText('POINT(5.5 1.5)'),
	'H'
),
(
	3,
	ST_GeomFromText('POINT(9.5 6.0)'),
	'I'
),
(
	4,
	ST_GeomFromText('POINT(6.5 6.0)'),
	'J'
),
(
	5,
	ST_GeomFromText('POINT(6.0 9.5)'),
	'K'
);

--ZAPYTANIA
-- a.	Wyznacz całkowitą długość dróg w analizowanym mieście.  
SELECT SUM(ST_Length(geom)) AS TotalRoadsLength  FROM plan.roads;

-- b.	Wypisz geometrię (WKT), pole powierzchni oraz obwód poligonu reprezentującego budynek o nazwie BuildingA. 
SELECT ST_AsEWKT(geom) AS WKT, ST_Area(geom) AS Area, ST_Perimeter(geom) AS Perimeter 
FROM plan.buildings WHERE _name = 'BuildingA';

-- c.	Wypisz nazwy i pola powierzchni wszystkich poligonów w warstwie budynki. Wyniki posortuj alfabetycznie.  
SELECT _name, ST_Area(geom) AS Area FROM plan.buildings ORDER BY _name;

-- d.	Wypisz nazwy i obwody 2 budynków o największej powierzchni.  
SELECT _name, ST_Perimeter(geom) AS Perimetr FROM plan.buildings ORDER BY ST_Area(geom) DESC LIMIT 2;
-- uwzględniając budynki o takiej samej powierzchni
SELECT _name, ST_Perimeter(geom) AS Perimetr FROM plan.buildings 
WHERE ST_Area(geom) IN (SELECT ST_Area(geom) FROM plan.buildings LIMIT 2);

-- e.	Wyznacz najkrótszą odległość między budynkiem BuildingC a punktem G.  
SELECT ST_Distance(buildings.geom, poi.geom) AS Distance FROM plan.buildings, plan.poi
WHERE buildings._name = 'BuildingC' AND poi._name = 'G';

-- f.	Wypisz pole powierzchni tej części budynku BuildingC, 
-- która znajduje się w odległości większej niż 0.5 od budynku BuildingB. 
SELECT ST_Area(geom) AS Area FROM plan.buildings 
WHERE _name = 'BuildingC' AND geom NOT IN (SELECT ST_Buffer(geom, 0.5) FROM plan.buildings WHERE _name = 'BuildingB');
-- czy da się ST_Difference dla tej samej tabeli?

-- g.	Wybierz te budynki, których centroid (ST_Centroid) znajduje się powyżej drogi o nazwie RoadX. 
SELECT buildings._name FROM plan.buildings 
	WHERE ST_Contains((SELECT ST_Buffer(roads.geom, 
		(SELECT ST_Distance(ST_Centroid(buildings.geom), roads.geom) AS dist 
		FROM plan.buildings, plan.roads WHERE roads._name = 'RoadX' ORDER BY dist DESC LIMIT 1) + 1, 'side=left') 
	FROM plan.roads WHERE roads._name = 'RoadX'), ST_Centroid(buildings.geom));
 
-- 8. Oblicz pole powierzchni tych części budynku BuildingC i poligonu o współrzędnych (4 7, 6 7, 6 8, 4 8, 4 7), 
--które nie są wspólne dla tych dwóch obiektów.
SELECT ST_Area(ST_SymDifference(geom, ST_GeomFromText('POLYGON((4.0 7.0, 6.0 7.0, 6.0 8.0, 4.0 8.0, 4.0 7.0))')))
FROM plan.buildings WHERE _name = 'BuildingC';



