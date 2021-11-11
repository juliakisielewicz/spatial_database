CREATE EXTENSION postgis;

DROP TABLE obiekty;

CREATE TABLE obiekty
(id INT PRIMARY KEY,
_name VARCHAR(10),
geom GEOMETRY);


INSERT INTO obiekty VALUES
(
	1,
	'obiekt1',
	ST_GeomFromText('COMPOUNDCURVE((0 1, 1 1), CIRCULARSTRING(1 1, 2 0, 3 1), CIRCULARSTRING(3 1, 4 2, 5 1), (5 1, 6 1))')
),
(
	2,
	'obiekt2',
	ST_GeomFromText('CURVEPOLYGON(COMPOUNDCURVE((10 6, 14 6), CIRCULARSTRING(14 6, 16 4, 14 2), CIRCULARSTRING(14 2, 12 0, 10 2), (10 2, 10 6)),
				   COMPOUNDCURVE(CIRCULARSTRING(11 2, 12 3, 13 2), CIRCULARSTRING(13 2, 12 1, 11 2)))')
),
(
	3,
	'obiekt3',
	ST_GeomFromText('MULTICURVE((10 17, 12 13), (12 13, 7 15), (7 15, 10 17))')
),
(
	4,
	'obiekt4',
	ST_GeomFromText('MULTICURVE((20 20, 25 25), (25 25, 27 24), (27 24, 25 22), (25 22, 26 21), (26 21, 22 19), (22 19, 20.5 19.5))')
),
(
	5,
	'obiekt5',
	ST_GeomFromText('MULTIPOINT(30 30 59, 38 32 234)')
),
(
	6,
	'obiekt6',
	ST_GeomFromText('GEOMETRYCOLLECTION(LINESTRING(1 1, 3 2), POINT(4 2))')
);

SELECT id, ST_CurveToLine(geom), _name FROM obiekty;

--1
SELECT ST_Area(ST_Buffer(
	ST_ShortestLine((SELECT obiekty.geom FROM obiekty WHERE obiekty._name = 'obiekt3'), 
					(SELECT obiekty.geom FROM obiekty WHERE obiekty._name = 'obiekt4')),
						5));

--2
SELECT ST_IsClosed(obiekty.geom) FROM obiekty WHERE obiekty._name = 'obiekt4';

UPDATE obiekty
		SET geom = (SELECT ST_MakePolygon(ST_AddPoint(ST_LineMerge(ST_CurveToLine(obiekty.geom)), 
													  (SELECT ST_StartPoint(ST_LineMerge(ST_CurveToLine(obiekty.geom))))))
					FROM obiekty WHERE obiekty._name = 'obiekt4')
		WHERE obiekty._name = 'obiekt4';
	
--3
INSERT INTO obiekty 
(SELECT 7, 'obiekt7',
	(SELECT ST_Collect((SELECT obiekty.geom FROM obiekty WHERE obiekty._name = 'obiekt3'), 
			   		   (SELECT obiekty.geom FROM obiekty WHERE obiekty._name = 'obiekt4')))
);

SELECT obiekty._name, ST_GeometryType(obiekty.geom), ST_CurveToLine(obiekty.geom) FROM obiekty WHERE obiekty._name = 'obiekt7';

--4 
SELECT (ST_Area(ST_Union(ST_Buffer(ST_CurveToLine(obiekty.geom), 5)))) FROM obiekty WHERE NOT ST_HasArc(obiekty.geom);

--SELECT ST_Union(ST_Buffer(ST_CurveToLine(obiekty.geom), 5)) FROM obiekty WHERE NOT ST_HasArc(obiekty.geom);


