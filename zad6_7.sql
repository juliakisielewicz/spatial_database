ALTER SCHEMA schema_name RENAME TO kisielewicz;

CREATE EXTENSION postgis_raster;

----------------------------------------------------------------------
-- 1. Przecięcie rastra z wektorem.
CREATE TABLE kisielewicz.intersects AS
SELECT a.rast, b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';

--serial primary key:
alter table kisielewicz.intersects
add column rid SERIAL PRIMARY KEY;

--indeks przestrzenny
CREATE INDEX idx_intersects_rast_gist ON kisielewicz.intersects
USING gist (ST_ConvexHull(rast));

--raster constraints
-- schema::name table_name::name raster_column::name
SELECT AddRasterConstraints('kisielewicz'::name,
'intersects'::name,'rast'::name);

-----------------------------------------------------------------------------

--2. Obcinanie rastra na podstawie wektora.
--ST_CLip: 'true' znaczy, że ucięte do części wspólnej zakresów
CREATE TABLE kisielewicz.clip AS
SELECT ST_Clip(a.rast, b.geom, true), b.municipality
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality like 'PORTO';

-----------------------------------------------------------------------------
--3. Połączenie wielu kafelków w jeden raster.
CREATE TABLE kisielewicz.union AS
SELECT ST_Union(ST_Clip(a.rast, b.geom, true))
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast);
-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--Tworzenie rastrów z wektorów
CREATE TABLE kisielewicz.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--połączenie
DROP TABLE kisielewicz.porto_parishes; --> drop table porto_parishes first
CREATE TABLE kisielewicz.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1
)
SELECT ST_Union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

--kafelki 
--'true' - wszystkie kafelki maja takie same wymiary
DROP TABLE kisielewicz.porto_parishes; --> drop table porto_parishes first
CREATE TABLE kisielewicz.porto_parishes AS
WITH r AS (
SELECT rast FROM rasters.dem
LIMIT 1 )
SELECT st_tile(st_union(ST_AsRaster(a.geom,r.rast,'8BUI',a.id,-32767)),128,128,true,-32767) AS rast
FROM vectors.porto_parishes AS a, r
WHERE a.municipality ilike 'porto';

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--Konwertowanie rastrów na wektory

--ST_Intersection (zwraca pary geometria-piksel; wolniejsze od ST_Clip)
create table kisielewicz.intersection as
SELECT a.rid,(ST_Intersection(b.geom,a.rast)).geom,(ST_Intersection(b.geom,a.rast)).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);


--ST_DumpAsPolygons
CREATE TABLE kisielewicz.dumppolygons AS
SELECT a.rid,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).geom,(ST_DumpAsPolygons(ST_Clip(a.rast,b.geom))).val
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--Analiza rastrów

--1. wyodrębnianie pasm
CREATE TABLE kisielewicz.landsat_nir AS
SELECT rid, ST_Band(rast,4) AS rast
FROM rasters.landsat8;

--2. wycięcie rastra z innego rastra
CREATE TABLE kisielewicz.paranhos_dem AS
SELECT a.rid, ST_Clip(a.rast, b.geom, true) AS rast
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.parish ilike 'paranhos' and ST_Intersects(b.geom,a.rast);

--nachylenie (slope)
CREATE TABLE kisielewicz.paranhos_slope AS
SELECT a.rid,ST_Slope(a.rast,1,'32BF','PERCENTAGE') as rast
FROM kisielewicz.paranhos_dem AS a;

--reklasyfikacja
CREATE TABLE kisielewicz.paranhos_slope_reclass AS
SELECT a.rid,ST_Reclass(a.rast,1,']0-15]:1, (15-30]:2, (30-9999:3', '32BF',0)
FROM kisielewicz.paranhos_slope AS a;


--statystyki kafelków
SELECT st_summarystats(a.rast) AS stats
FROM kisielewicz.paranhos_dem AS a;

--statystyki całego rastra
SELECT st_summarystats(ST_Union(a.rast))
FROM kisielewicz.paranhos_dem AS a;

--lepsza kontrola
WITH t AS (
SELECT st_summarystats(ST_Union(a.rast)) AS stats
FROM kisielewicz.paranhos_dem AS a
)
SELECT (stats).min,(stats).max,(stats).mean FROM t;


--statystyka poligonów parish
WITH t AS (
SELECT b.parish AS parish, st_summarystats(ST_Union(ST_Clip(a.rast, b.geom,true))) AS stats
FROM rasters.dem AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
group by b.parish
)
SELECT parish,(stats).min,(stats).max,(stats).mean FROM t;


--wyodrębnianie wartości piksela w punkcie
SELECT b.name, st_value(a.rast,(ST_Dump(b.geom)).geom)
FROM
rasters.dem a, vectors.places AS b
WHERE ST_Intersects(a.rast,b.geom)
ORDER BY b.name;


--TPI - wysokość względem sąsiednich pikseli
create table kisielewicz.tpi30 as
select ST_TPI(a.rast,1) as rast
from rasters.dem a;

CREATE INDEX idx_tpi30_rast_gist ON kisielewicz.tpi30
USING gist (ST_ConvexHull(rast));

--Dodanie constraintów:
SELECT AddRasterConstraints('kisielewicz'::name, 'tpi30'::name,'rast'::name);

--rozwiązanie dla Porto
create table kisielewicz.tpi30_porto as
select ST_TPI(a.rast,1) as rast
from rasters.dem a, vectors.porto_parishes AS b
WHERE ST_Intersects(a.rast, b.geom) AND b.municipality ilike 'porto';
--Dodanie indeksu przestrzennego:
CREATE INDEX idx_tpi30_porto_rast_gist ON kisielewicz.tpi30_porto
USING gist (ST_ConvexHull(rast));
--Dodanie constraintów:
SELECT AddRasterConstraints('kisielewicz'::name, 'tpi30_porto'::name,'rast'::name);

-----------------------------------------------------------------------------
-----------------------------------------------------------------------------
--Algebra map

--wyrażenie
CREATE TABLE kisielewicz.porto_ndvi AS
WITH r AS (
SELECT a.rid, ST_Clip(a.rast, b.geom, true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, 1,
r.rast, 4,
'([rast2.val] - [rast1.val]) / ([rast2.val] + [rast1.val])::float','32BF'
) AS rast
FROM r;


CREATE INDEX idx_porto_ndvi_rast_gist ON kisielewicz.porto_ndvi
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('kisielewicz'::name, 'porto_ndvi'::name,'rast'::name);


--funkcja zwrotna

create or replace function kisielewicz.ndvi(
value double precision [] [] [],
pos integer [][],
VARIADIC userargs text []
)
RETURNS double precision AS
$$
BEGIN
--RAISE NOTICE 'Pixel Value: %', value [1][1][1];-->For debug purposes
RETURN (value [2][1][1] - value [1][1][1])/(value [2][1][1]+value [1][1][1]); --> NDVI calculation!
END;
$$
LANGUAGE 'plpgsql' IMMUTABLE COST 1000;


CREATE TABLE kisielewicz.porto_ndvi2 AS
WITH r AS (
SELECT a.rid,ST_Clip(a.rast, b.geom,true) AS rast
FROM rasters.landsat8 AS a, vectors.porto_parishes AS b
WHERE b.municipality ilike 'porto' and ST_Intersects(b.geom,a.rast)
)
SELECT
r.rid,ST_MapAlgebra(
r.rast, ARRAY[1,4],
'kisielewicz.ndvi(double precision[], integer[],text[])'::regprocedure, --> This is the function!
'32BF'::text
) AS rast
FROM r;

CREATE INDEX idx_porto_ndvi2_rast_gist ON kisielewicz.porto_ndvi2
USING gist (ST_ConvexHull(rast));

SELECT AddRasterConstraints('kisielewicz'::name, 'porto_ndvi2'::name,'rast'::name);



--funkcja tpi


--tpi4ma

CREATE OR REPLACE FUNCTION public._st_tpi4ma(IN value double precision[],IN pos integer[],VARIADIC userargs text[])
    RETURNS double precision
    LANGUAGE 'plpgsql'
    IMMUTABLE
    PARALLEL SAFE
    COST 100
    
AS $BODY$
	DECLARE
		x integer;
		y integer;
		z integer;

		Z1 double precision;
		Z2 double precision;
		Z3 double precision;
		Z4 double precision;
		Z5 double precision;
		Z6 double precision;
		Z7 double precision;
		Z8 double precision;
		Z9 double precision;

		tpi double precision;
		mean double precision;
		_value double precision[][][];
		ndims int;
	BEGIN
		ndims := array_ndims(value);
		-- add a third dimension if 2-dimension
		IF ndims = 2 THEN
			_value := public._ST_convertarray4ma(value);
		ELSEIF ndims != 3 THEN
			RAISE EXCEPTION 'First parameter of function must be a 3-dimension array';
		ELSE
			_value := value;
		END IF;

		-- only use the first raster passed to this function
		IF array_length(_value, 1) > 1 THEN
			RAISE NOTICE 'Only using the values from the first raster';
		END IF;
		z := array_lower(_value, 1);

		IF (
			array_lower(_value, 2) != 1 OR array_upper(_value, 2) != 3 OR
			array_lower(_value, 3) != 1 OR array_upper(_value, 3) != 3
		) THEN
			RAISE EXCEPTION 'First parameter of function must be a 1x3x3 array with each of the lower bounds starting from 1';
		END IF;

		-- check that center pixel isn't NODATA
		IF _value[z][2][2] IS NULL THEN
			RETURN NULL;
		-- substitute center pixel for any neighbor pixels that are NODATA
		ELSE
			FOR y IN 1..3 LOOP
				FOR x IN 1..3 LOOP
					IF _value[z][y][x] IS NULL THEN
						_value[z][y][x] = _value[z][2][2];
					END IF;
				END LOOP;
			END LOOP;
		END IF;

		-------------------------------------------------
		--|   Z1= Z(-1,1) |  Z2= Z(0,1)	| Z3= Z(1,1)  |--
		-------------------------------------------------
		--|   Z4= Z(-1,0) |  Z5= Z(0,0) | Z6= Z(1,0)  |--
		-------------------------------------------------
		--|   Z7= Z(-1,-1)|  Z8= Z(0,-1)|  Z9= Z(1,-1)|--
		-------------------------------------------------

		Z1 := _value[z][1][1];
		Z2 := _value[z][2][1];
		Z3 := _value[z][3][1];
		Z4 := _value[z][1][2];
		Z5 := _value[z][2][2];
		Z6 := _value[z][3][2];
		Z7 := _value[z][1][3];
		Z8 := _value[z][2][3];
		Z9 := _value[z][3][3];

		mean := (Z1 + Z2 + Z3 + Z4 + Z6 + Z7 + Z8 + Z9)/8;
		tpi := Z5-mean;

		return tpi;
	END;
	$BODY$;
	
	---------------------------------------------------------------------------------
	---------------------------------------------------------------------------------
	
	--st_tpi 
	
	CREATE OR REPLACE FUNCTION public.st_tpi(IN rast raster,IN nband integer,IN customextent raster,IN pixeltype text DEFAULT '32BF'::text,IN interpolate_nodata boolean DEFAULT  false)
    RETURNS raster
    LANGUAGE 'plpgsql'
    IMMUTABLE
    PARALLEL SAFE
    COST 100
    
AS $BODY$
	DECLARE
		_rast public.raster;
		_nband integer;
		_pixtype text;
		_pixwidth double precision;
		_pixheight double precision;
		_width integer;
		_height integer;
		_customextent public.raster;
		_extenttype text;
	BEGIN
		_customextent := customextent;
		IF _customextent IS NULL THEN
			_extenttype := 'FIRST';
		ELSE
			_extenttype := 'CUSTOM';
		END IF;

		IF interpolate_nodata IS TRUE THEN
			_rast := public.ST_MapAlgebra(
				ARRAY[ROW(rast, nband)]::rastbandarg[],
				'public.st_invdistweight4ma(double precision[][][], integer[][], text[])'::regprocedure,
				pixeltype,
				'FIRST', NULL,
				1, 1
			);
			_nband := 1;
			_pixtype := NULL;
		ELSE
			_rast := rast;
			_nband := nband;
			_pixtype := pixeltype;
		END IF;

		-- get properties
		_pixwidth := public.ST_PixelWidth(_rast);
		_pixheight := public.ST_PixelHeight(_rast);
		SELECT width, height INTO _width, _height FROM public.ST_Metadata(_rast);

		RETURN public.ST_MapAlgebra(
			ARRAY[ROW(_rast, _nband)]::rastbandarg[],
			' public._ST_tpi4ma(double precision[][][], integer[][], text[])'::regprocedure,
			_pixtype,
			_extenttype, _customextent,
			1, 1);
	END;
	$BODY$;
	
	
	
	---------------------------------------------------------------------------------
	---------------------------------------------------------------------------------
	--st_tpi
	
	CREATE OR REPLACE FUNCTION public.st_tpi(IN rast raster,IN nband integer DEFAULT 1,IN pixeltype text DEFAULT  '32BF'::text,IN interpolate_nodata boolean DEFAULT  false)
    RETURNS raster
    LANGUAGE 'sql'
    IMMUTABLE
    PARALLEL SAFE
    COST 100
    
AS $BODY$ SELECT public.ST_tpi($1, $2, NULL::public.raster, $3, $4) $BODY$;


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--EKSPORT DANYCH

--tiff

SELECT ST_AsTiff(ST_Union(rast))
FROM kisielewicz.porto_ndvi;


--gdal
SELECT ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
FROM kisielewicz.porto_ndvi;

SELECT ST_GDALDrivers();

--zapisywanie na dysku - large object
CREATE TABLE tmp_out AS
SELECT lo_from_bytea(0,
ST_AsGDALRaster(ST_Union(rast), 'GTiff', ARRAY['COMPRESS=DEFLATE', 'PREDICTOR=2', 'PZLEVEL=9'])
) AS loid
FROM kisielewicz.porto_ndvi;
----------------------------------------------
SELECT lo_export(loid, 'D:\AGH\SEMESTR_5\bdp\zad6-7\myraster.tiff') --> Save the file in a place where the user postgres have access. In windows a flash drive usualy works fine.
FROM tmp_out;
----------------------------------------------
SELECT lo_unlink(loid)
FROM tmp_out; --> Delete the large object.


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--GEOSERVER

CREATE TABLE public.mosaic (
    name character varying(254) COLLATE pg_catalog."default" NOT NULL,
    tiletable character varying(254) COLLATE pg_catalog."default" NOT NULL,
    minx double precision,
    miny double precision,
    maxx double precision,
    maxy double precision,
    resx double precision,
    resy double precision,
    CONSTRAINT mosaic_pkey PRIMARY KEY (name, tiletable)
);

--assigning name
insert into mosaic (name,tiletable) values ('mosaicpgraster','rasters.dem');

