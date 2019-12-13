IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'Mitologia_nordycka')
BEGIN
	CREATE DATABASE Mitologia_nordycka
END

USE Mitologia_nordycka;
GO

------------ USUÑ TABELE ------------

DROP TABLE IF EXISTS Pokonany;
DROP TABLE IF EXISTS Posiada;
DROP TABLE IF EXISTS Zdolnoœæ;
DROP TABLE IF EXISTS Opiekun;
DROP TABLE IF EXISTS Powi¹zanie;
DROP TABLE IF EXISTS Bóstwa;
DROP TABLE IF EXISTS Artefakty;

------------ USUÑ FUNKCJE ------------

DROP FUNCTION IF EXISTS rodzina;
DROP FUNCTION IF EXISTS znajdŸ_rodzica;
DROP PROCEDURE IF EXISTS widok_rodziny;
DROP PROCEDURE IF EXISTS usuñ_widok_rodziny;
DROP PROCEDURE IF EXISTS zobacz_widoki;
DROP PROCEDURE IF EXISTS zobacz_obiekty;

------------ USUÑ TRIGGERY ------------

DROP TRIGGER IF EXISTS t_powi¹zanie_insert;
DROP TRIGGER IF EXISTS t_powi¹zanie_delete;
DROP TRIGGER IF EXISTS t_bóstwa_update;
DROP TRIGGER IF EXISTS t_bóstwa_delete;
DROP TRIGGER IF EXISTS t_artefakty_delete;

------------ UTWÓRZ TABELE I POWI¥ZANIA ------------

CREATE TABLE Bóstwa
(
	imiê	VARCHAR(30) PRIMARY KEY,
	rodzaj	VARCHAR(30) CHECK (rodzaj IN ('Istota', 'Zwierzê', 'Cz³owiek','Olbrzym', 'Karze³', 'As', 'Wan')) DEFAULT 'Istota',
	p³eæ	CHAR(1)		CHECK (p³eæ IN ('M', 'K')) NOT NULL
);

CREATE TABLE Artefakty
(
	nazwa	VARCHAR(30) PRIMARY KEY,
	typ		VARCHAR(30) CHECK (typ IN ('Broñ', 'Ozdoba', 'Pojazd','Inne')) DEFAULT 'Inne',
	rodzaj	VARCHAR(30) CHECK (rodzaj NOT IN ('Broñ', 'Ozdoba', 'Pojazd','Inne')) DEFAULT 'Przedmiot',
	efekt	VARCHAR(30) NULL
);

CREATE TABLE Pokonany
(
	zwyciêzca	VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) DEFAULT 'Hela' ,
	pokonany	VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) NOT NULL
	PRIMARY KEY (zwyciêzca, pokonany)
);

CREATE TABLE Posiada
(
	bóstwo		VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) ON UPDATE CASCADE NOT NULL,
	artefakt	VARCHAR(30) FOREIGN KEY REFERENCES Artefakty(nazwa) ON UPDATE CASCADE PRIMARY KEY
);

CREATE TABLE Zdolnoœæ
(
	bóstwo	VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) NOT NULL,
	cecha	VARCHAR(30) NOT NULL,
	PRIMARY KEY (bóstwo, cecha)
);

CREATE TABLE Opiekun
(
	bóstwo	VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) NOT NULL,
	dziedzina	VARCHAR(30) NOT NULL,
	PRIMARY KEY (bóstwo, dziedzina)
);

CREATE TABLE Powi¹zanie
(
	probant	VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) NOT NULL,
	rodzaj	VARCHAR(30) CHECK (rodzaj IN ('rodzic', 'dziecko', 'm¹¿','¿ona', 'rodzeñstwo')) NOT NULL,
	postaæ	VARCHAR(30) FOREIGN KEY REFERENCES Bóstwa(imiê) NOT NULL
	PRIMARY KEY (probant, rodzaj, postaæ)
);

GO

---------- UTWÓRZ TRIGGERY ----------

-----------  POWI¥ZANIE  ------------

CREATE TRIGGER t_powi¹zanie_insert
ON Powi¹zanie
AFTER INSERT
AS

	DECLARE @temp TABLE(
    probant VARCHAR(30),
	rodzaj VARCHAR(30),
	postaæ VARCHAR(30)
	);
	
	INSERT INTO @temp
	SELECT postaæ, rodzaj, probant FROM inserted

	IF EXISTS (
		SELECT * FROM @temp
		INTERSECT
		SELECT * FROM Powi¹zanie
		)
	BEGIN
	-- zmieñ rodzaj powi¹zania na przeciwny
		UPDATE @temp
		SET rodzaj = CASE rodzaj
					  WHEN 'rodzic' THEN 'dziecko'
					  WHEN 'dziecko' THEN 'rodzic'
					  WHEN 'm¹¿' THEN '¿ona'
					  WHEN '¿ona' THEN 'm¹¿'
					  WHEN 'rodzeñstwo' THEN 'rodzeñstwo'
		END

		INSERT INTO Powi¹zanie
		SELECT * FROM @temp

	END
GO

CREATE TRIGGER t_powi¹zanie_delete
ON Powi¹zanie
AFTER DELETE
AS
	DECLARE @temp TABLE(
    probant VARCHAR(30),
	rodzaj VARCHAR(30),
	postaæ VARCHAR(30)
	);
	
	INSERT INTO @temp
	SELECT postaæ, rodzaj, probant FROM deleted

	-- zmieñ rodzaj powi¹zania na przeciwny
	UPDATE @temp
	SET rodzaj = CASE rodzaj
				  WHEN 'rodzic' THEN 'dziecko'
				  WHEN 'dziecko' THEN 'rodzic'
				  WHEN 'm¹¿' THEN '¿ona'
				  WHEN '¿ona' THEN 'm¹¿'
				  WHEN 'rodzeñstwo' THEN 'rodzeñstwo'
	END

	-- usuñ czêœæ wspóln¹ tabel 
	
	DECLARE @temp2 TABLE(
    probant VARCHAR(30),
	rodzaj VARCHAR(30),
	postaæ VARCHAR(30)
	);

	INSERT INTO @temp2
	SELECT * FROM Powi¹zanie
	EXCEPT 
	SELECT * FROM @temp

	TRUNCATE TABLE Powi¹zanie

	INSERT INTO Powi¹zanie
	SELECT * FROM @temp2

GO

-----------     BÓSTWA    ------------

CREATE TRIGGER t_bóstwa_update
ON Bóstwa
INSTEAD OF UPDATE
AS
	-- nie mo¿na dokonywaæ wielu modyfikacji naraz
	IF (SELECT COUNT(*) FROM inserted) > 1
	BEGIN
		PRINT 'This database does not allow to update multiple values at once.'
	END
	ELSE
	BEGIN

		INSERT INTO Bóstwa VALUES ((SELECT imiê FROM inserted), (SELECT rodzaj FROM inserted), (SELECT p³eæ FROM inserted))

		UPDATE Powi¹zanie
		SET probant = (SELECT imiê FROM inserted)
		WHERE probant IN (SELECT imiê FROM deleted) 
		UPDATE Powi¹zanie
		SET postaæ = (SELECT imiê FROM inserted)
		WHERE postaæ IN (SELECT imiê FROM deleted)

		UPDATE Posiada
		SET bóstwo = (SELECT imiê FROM inserted)
		WHERE bóstwo IN (SELECT imiê FROM deleted) 

		UPDATE Pokonany
		SET zwyciêzca = (SELECT imiê FROM inserted)
		WHERE zwyciêzca IN (SELECT imiê FROM deleted) 
		UPDATE Pokonany
		SET pokonany = (SELECT imiê FROM inserted)
		WHERE pokonany IN (SELECT imiê FROM deleted) 

		UPDATE Opiekun
		SET bóstwo = (SELECT imiê FROM inserted)
		WHERE bóstwo IN (SELECT imiê FROM deleted) 

		UPDATE Zdolnoœæ
		SET bóstwo = (SELECT imiê FROM inserted)
		WHERE bóstwo IN (SELECT imiê FROM deleted)

		DELETE FROM Bóstwa WHERE imiê IN (SELECT imiê FROM deleted)

	END
GO

CREATE TRIGGER t_bóstwa_delete
ON Bóstwa
INSTEAD OF DELETE
AS

	DELETE FROM Powi¹zanie
	WHERE probant IN (SELECT imiê FROM deleted) 
	DELETE FROM Powi¹zanie
	WHERE postaæ IN (SELECT imiê FROM deleted) 

	DELETE FROM Posiada
	WHERE bóstwo IN (SELECT imiê FROM deleted) 

	DELETE FROM Pokonany
	WHERE zwyciêzca IN (SELECT imiê FROM deleted) 
	DELETE FROM Pokonany
	WHERE pokonany IN (SELECT imiê FROM deleted) 

	DELETE FROM Opiekun
	WHERE bóstwo IN (SELECT imiê FROM deleted) 

	DELETE FROM Zdolnoœæ
	WHERE bóstwo IN (SELECT imiê FROM deleted) 

	DELETE FROM Bóstwa
	WHERE imiê IN (SELECT imiê FROM deleted) 
GO

-----------    ARTEFAKTY   ------------

CREATE TRIGGER t_artefakty_delete
ON Artefakty
INSTEAD OF DELETE
AS

	DELETE FROM Posiada
	WHERE artefakt IN (SELECT nazwa FROM deleted)

	DELETE FROM Artefakty
	WHERE nazwa IN (SELECT nazwa FROM deleted)

GO

---------- UTWÓRZ PROCEDURY ----------

-- znajd¿ rodzinê danego bohatera

CREATE FUNCTION rodzina ( @imiê  VARCHAR(30) )
    RETURNS TABLE
AS
    RETURN SELECT rodzaj, postaæ FROM Powi¹zanie WHERE @imiê = probant;
GO

-- znajd¿ rodzica o danej p³ci

CREATE FUNCTION znajdŸ_rodzica ( @imiê  VARCHAR(30), @p³eæ CHAR(1) )
    RETURNS TABLE
AS
    RETURN (
		SELECT probant 
		FROM Powi¹zanie P
		RIGHT OUTER JOIN Bóstwa B ON B.imiê = P.probant
		WHERE @imiê = postaæ AND @p³eæ = B.p³eæ AND P.rodzaj = 'rodzic');
GO

-- usuñ widok rodziny bohatera

CREATE PROCEDURE usuñ_widok_rodziny ( @imiê  VARCHAR(30) )
AS
    EXEC ( 'DROP VIEW IF EXISTS widok_rodziny_' + @imiê + ';');
GO

-- utwórz widok rodziny bohatera

CREATE PROCEDURE widok_rodziny ( @imiê  VARCHAR(30) )
AS
	EXEC usuñ_widok_rodziny @imiê
    EXEC ( 'CREATE VIEW widok_rodziny_' + @imiê + '(rodzaj, postaæ)'+
		  ' AS( SELECT rodzaj, postaæ FROM Powi¹zanie WHERE probant = ''' + @imiê +''' );');
GO

-- wypisz wszystkie utworzone widoki
CREATE PROCEDURE zobacz_widoki
AS SELECT name FROM sys.views;  
GO

-- wypisz wszystkie obiekty
CREATE PROCEDURE zobacz_obiekty
AS
	DECLARE @Obiekty TABLE(
    name VARCHAR(30),
	type VARCHAR(30)
	);

	INSERT INTO @Obiekty 
	SELECT name, 'TABLE' FROM sysobjects WHERE xtype = 'U'
	UNION
	SELECT name, 'TRIGGER' FROM sysobjects WHERE xtype = 'TR'
	UNION
	SELECT name, 'FUNCTION' FROM sysobjects WHERE xtype = 'IF'
	UNION
	SELECT name, 'PROCEDURE' FROM sysobjects WHERE xtype = 'P'
	UNION
	SELECT name, 'VIEW' FROM sys.views
	
	SELECT * FROM @Obiekty;
GO

------------ WSTAW DANE ------------

INSERT INTO Bóstwa VALUES
('Angrboda'	, 'Olbrzym'		, 'M' ),
('Ask'		, 'Cz³owiek'	, 'M' ),
('Audhumla'	, 'Zwierzê'		, 'K' ),
('Aurboda'	, 'Olbrzym'		, 'K' ),
('Balder'	, 'As'			, 'M' ),
('Baugi'	, 'Olbrzym'		, 'M' ),
('Beli'		, 'Olbrzym'		, 'M' ),
('Bergelmir', 'Olbrzym'		, 'M' ),
('Bestla'	, 'Olbrzym'		, 'K' ),
('Bolthorn'	, 'Olbrzym'		, 'M' ),
('Bor'		, 'As'			, 'M' ),
('Bragi'	, 'As'			, 'M' ),
('Brokk'	, 'Karze³'		, 'M' ),
('Buri'		, 'As'			, 'M' ),
('Dragi'	, 'As'			, 'M' ),
('Egil'		, 'Cz³owiek'	, 'M' ),
('Egir'		, 'Olbrzym'		, 'M' ),
('Eitri'	, 'Karze³'		, 'M' ),
('Elli'		, 'Istota'		, 'K' ),
('Embla'	, 'Cz³owiek'	, 'K' ),
('Farbauti'	, 'Olbrzym'		, 'M' ),
('Fenrir'	, 'Zwierzê'		, 'M' ),
('Fjalar'	, 'Cz³owiek'	, 'M' ),
('Fjolnir'	, 'Cz³owiek'	, 'M' ),
('Frejr'	, 'Wan'			, 'M' ),
('Freja'	, 'Wan'			, 'K' ),
('Frigg'	, 'As'			, 'K' ),
('Fulla'	, 'As'			, 'K' ),
('Galar'	, 'Karze³'		, 'M' ),
('Garm'		, 'Zwierzê'		, 'M' ),
('Gerd'		, 'Olbrzym'		, 'K' ),
('Gilling'	, 'Olbrzym'		, 'M' ),
('Gunnlod'	, 'Olbrzym'		, 'K' ),
('Gymir'	, 'Olbrzym'		, 'M' ),
('Heidrun'	, 'Zwierzê'		, 'M' ),
('Heimdall'	, 'As'			, 'M' ),
('Hel'		, 'Istota'		, 'K' ),
('Hermod'	, 'As'			, 'M' ),
('Hod'		, 'As'			, 'M' ),
('Hoenir'	, 'Istota'		, 'M' ),
('Hrym'		, 'Olbrzym'		, 'M' ),
('Hungi'	, 'Istota'		, 'M' ),
('Hymir'	, 'Olbrzym'		, 'M' ),
('Hyrrokkin', 'Olbrzym'		, 'K' ),
('Idunn'	, 'As'			, 'K' ),
('Iwaldi'	, 'Karze³'		, 'M' ),
('Jord'		, 'Olbrzym'		, 'K' ),
('Jormungundr', 'Zwierzê'	, 'M' ),
('Kwasir'	, 'As'			, 'M' ),
('Laufey'	, 'Cz³owiek'	, 'K' ),
('Lit'		, 'Karze³'		, 'M' ),
('Loki'		, 'As'			, 'M' ),
('Magni'	, 'As'			, 'M' ),
('Mimir'	, 'Olbrzym'		, 'M' ),
('Modgud'	, 'Istota'		, 'M' ),
('Modi'		, 'As'			, 'M' ),
('Narfi'	, 'As'			, 'M' ),
('Nidhogg'	, 'Zwierzê'		, 'M' ),
('Njord'	, 'Wan'			, 'M' ),
('Odyn'		, 'As'			, 'M' ),
('Urd'		, 'Istota'		, 'K' ),
('Werdandi'	, 'Istota'		, 'K' ),
('Skuld'	, 'Istota'		, 'K' ),
('Ran'		, 'As'			, 'K' ),
('Ratatosk'	, 'Zwierzê'		, 'M' ),
('Roskwa'	, 'Cz³owiek'	, 'K' ),
('Sif'		, 'As'			, 'K' ),
('Sigyn'	, 'As'			, 'K' ),
('Skadi'	, 'Olbrzym'		, 'K' ),
('Skirnir'	, 'Karze³'		, 'M' ),
('Skrymir'	, 'Olbrzym'		, 'M' ),
('Surtr'	, 'Olbrzym'		, 'M' ),
('Suttung'	, 'Olbrzym'		, 'M' ),
('Thialfi'	, 'Cz³owiek'	, 'M' ),
('Thiazi'	, 'Olbrzym'		, 'M' ),
('Thokk'	, 'Cz³owiek'	, 'K' ),
('Thor'		, 'As'			, 'M' ),
('Thrud'	, 'As'			, 'K' ),
('Thrym'	, 'Istota'		, 'M' ),
('Tyr'		, 'As'			, 'M' ),
('Ullr'		, 'As'			, 'M' ),
('Wali'		, 'As'			, 'M' ),
('War'		, 'As'			, 'K' ),
('We'		, 'As'			, 'M' ),
('Widar'	, 'As'			, 'M' ),
('Wili'		, 'As'			, 'M' ),
('Ymir'		, 'Olbrzym'		, 'M' );

INSERT INTO Artefakty VALUES
('Mjolnir',		'Broñ'		, 'M³ot'		, 'Si³a' ),
('Bodn',		'Inne'		, 'KadŸ'		, 'Poezja' ),
('Son',			'Inne'	    , 'KadŸ'		, 'Poezja' ),
('Odrerir',		'Inne'	    , 'KadŸ'		, 'Poezja' ),
('Draupnir',	'Ozdoba'	, 'Bransoleta'	, 'Bogactwo' ),
('Gjallerhorn',	'Inne'	    , 'Róg'			, 'Wezwanie' ),
('Gleipnir',	'Inne'	    , '£añcuch'		, 'Niewola' ),
('Gungnir',		'Broñ'	    , 'W³ócznia'	, 'Zwyciêstwo' ),
('Hlidskjalf',	'Inne'	    , 'Tron'		, 'Wiedza' ),
('Huginn',		'Inne'	    , 'Kruk'		, 'Wiedza' ),
('Megingjord',	'Broñ'	    , 'Pas'			, 'Si³a' ),
('Muninn',		'Inne'	    , 'Kruk'		, 'Wiedza' ),
('Naglfar',		'Pojazd'	, 'Statek'		, 'Œmieræ' ),
('Sleipnir',	'Pojazd'	, 'Koñ'			, 'Szybkoœæ' ),
('Sladilfari',	'Pojazd'	, 'Koñ'			, 'Szybkoœæ' );

INSERT INTO Artefakty(nazwa, typ, rodzaj) VALUES
('Brisinig',	'Ozdoba'	, 'Naszyjnik' ),
('Gullenbursti','Pojazd'	, 'Z³oty dzik' ),
('Rati',		'Broñ'	    , 'Wiert³o'	 ),
('Tanngrisnir',	'Pojazd'	, 'Kozio³'),
('Skidbladnir',	'Pojazd'	, 'Statek' ),
('Tanngnjostr',	'Pojazd'	, 'Kozio³');

INSERT INTO Pokonany VALUES
('Fenrir'	, 'Odyn' ),
('Surtr'	, 'Frejr' ),
('Tyr'		, 'Garm' ),
('Garm'		, 'Tyr' ),
('Thor'		, 'Jormungundr' ),
('Jormungundr' , 'Thor' ),
('Widar'	, 'Fenrir' ),
('Loki'		, 'Heimdall' ),
('Thor'		, 'Thrym' ),
('Heimdall' , 'Loki' );

INSERT INTO Posiada VALUES
('Freja'	, 'Brisinig' ),
('Odyn'		, 'Draupnir' ),
('Heimdall'	, 'Gjallerhorn' ),
('Fenrir'	, 'Gleipnir' ),
('Frejr'	, 'Gullenbursti' ),
('Odyn'		, 'Gungnir' ),
('Odyn'		, 'Hlidskjalf' ),
('Odyn'		, 'Huginn' ),
('Thor'		, 'Megingjord' ),
('Thor'		, 'Mjolnir' ),
('Odyn'		, 'Muninn' ),
('Hel'		, 'Naglfar' ),
('Frejr'	, 'Skidbladnir' ),
('Thor'		, 'Tanngrisnir' ),
('Thor'		, 'Tanngnjostr' );

INSERT INTO Zdolnoœæ VALUES
('Thor'			, 'Si³a'),
('Loki'			, 'Spryt'),
('Loki'			, 'Zmienianie kszta³tów'),
('Balder'		, 'Piêkno'),
('Hermod'		, 'Zrêcznoœæ'),
('Hungi'		, 'Szybkoœæ'),
('Hyrrokkin'	, 'Si³a'),
('Idunn'		, 'Wieczna m³odoœæ'),
('Lit'			, 'Pech'),
('Loki'			, 'Chodzenie w powietrzu'),
('Magni'		, 'Si³a'),
('Modi'			, 'Odwaga'),
('Odyn'			, 'M¹droœæ'),
('Odyn'			, 'Spryt'),
('Thrud'		, 'Si³a');

INSERT INTO Opiekun VALUES
('Thor'		, 'Grzmoty'),
('Thor'		, 'Pioruny'),
('Thor'		, 'Burze'),
('Loki'		, 'Z³odzieje'),
('Bragi'	, 'Poezja'),
('Egir'		, 'Morze'),
('Elli'		, 'Staroœæ'),
('Heimdall'	, 'Bogowie'),
('Hel'		, 'Œmieræ'),
('Hoenir'	, 'M¹droœæ'),
('Jord'		, 'Ziemia'),
('Kwasir'	, 'M¹droœæ'),
('Ran'		, 'Zmarli na morzu'),
('Ran'		, 'Fale morskie'),
('Skuld'	, 'Przysz³oœæ'),
('Tyr'		, 'Wojna'),
('Ullr'		, 'Polowanie'),
('War'		, 'Ma³¿eñstwo'),
('Werdandi'	, 'Tera¿niejszoœæ'),
('Odyn'		, 'WiêŸniowie'),
('Odyn'		, 'Szubienice'),
('Dragi'	, 'Poezja'),
('Odyn'		, 'Podró¿nicy');

INSERT INTO Powi¹zanie VALUES
('Aurboda'	, 'rodzic'	, 'Gerd'),
('Balder'	, 'dziecko'	, 'Odyn'),
('Ymir'		, 'rodzic'	, 'Bergelmir'),
('Bestla'	, 'rodzic'	, 'Odyn'),
('Bestla'	, 'rodzeñstwo'	, 'Mimir'),
('Bestla'	, 'rodzic'	, 'Wili'),
('Bestla'	, 'rodzic'	, 'We'),
('Bestla'	, '¿ona'	, 'Bor'),
('Bolthorn'	, 'rodzic'	, 'Bestla'),
('Bolthorn'	, 'rodzic'	, 'Mimir'),
('Bor'		, 'dziecko'	, 'Buri'),
('Bor'		, 'rodzic'	, 'Odyn'),
('Bor'		, 'rodzic'	, 'Wili'),
('Bor'		, 'rodzic'	, 'We'),
('Baugi'	, 'rodzeñstwo', 'Suttung'),
('Buri'		, 'rodzic'	, 'Bor'),
('Egil'		, 'rodzic'	, 'Thialfi'),
('Egil'		, 'rodzic'	, 'Roskwa'),
('Egir'		, 'm¹¿'		, 'Ran'),
('Eitri'	, 'rodzeñstwo', 'Brokk'),
('Farbauti'	, 'rodzic'	, 'Loki'),
('Fenrir'	, 'dziecko'	, 'Loki'),
('Loki'		, 'rodzic'	, 'Fenrir'),
('Angrboda'	, 'rodzic'	, 'Fenrir'),
('Fjalar'	, 'rodzeñstwo', 'Galar'),
('Fjolnir'	, 'dziecko'	, 'Frejr'),
('Fjolnir'	, 'dziecko'	, 'Gerd'),
('Frejr'	, 'rodzeñstwo', 'Freja'),
('Frigg'	, '¿ona'	, 'Odyn'),
('Frigg'	, 'rodzic'	, 'Balder'),
('Gilling'	, 'rodzic'	, 'Suttung'),
('Gilling'	, 'rodzic'	, 'Baugi'),
('Gunnlod'	, 'dziecko'	, 'Suttung'),
('Gymir'	, 'rodzic'	, 'Gerd'),
('Hel'		, 'dziecko'	, 'Loki'),
('Hel'		, 'dziecko'	, 'Angrboda'),
('Odyn'		, 'rodzic'	, 'Hermod'),
('Hod'		, 'rodzeñstwo', 'Balder'),
('Jord'		, 'rodzic'	, 'Thor'),
('Jormungundr'	, 'dziecko', 'Loki'),
('Loki'		, 'rodzeñstwo', 'Thor'),
('Loki'		, 'dziecko'	, 'Farbauti'),
('Loki'		, 'dziecko'	, 'Laufey'),
('Magni'	, 'dziecko'	, 'Thor'),
('Modi'		, 'dziecko'	, 'Thor'),
('Narfi'	, 'dziecko'	, 'Loki'),
('Narfi'	, 'dziecko'	, 'Sigyn'),
('Narfi'	, 'rodzeñstwo', 'Wali'),
('Njord'	, 'rodzic'	, 'Freja'),
('Njord'	, 'rodzic'	, 'Frejr'),
('Ran'		, '¿ona'	, 'Egir'),
('Roskwa'	, 'rodzeñstwo', 'Thialfi'),
('Sif'		, '¿ona'	, 'Thor'),
('Sigyn'	, '¿ona'	, 'Loki'),
('Skadi'	, 'dziecko'	, 'Thiazi'),
('Skadi'	, '¿ona'	, 'Njord'),
('Suttung'	, 'dziecko'	, 'Gilling'),
('Thiazi'	, 'rodzic'	, 'Skadi'),
('Odyn'		, 'rodzic'	, 'Thor'),
('Thor'		, 'dziecko'	, 'Odyn'),
('Thrud'	, 'dziecko'	, 'Thor'),
('Tyr'		, 'dziecko', 'Odyn'),
('Odyn'		, 'rodzic'	, 'Tyr'),
('We'		, 'rodzeñstwo', 'Odyn'),
('We'		, 'dziecko'	, 'Bor'),
('We'		, 'dziecko'	, 'Bestla'),
('Widar'	, 'dziecko'	, 'Odyn'),
('Wili'		, 'rodzeñstwo', 'Odyn'),
('Wili'		, 'dziecko'	, 'Bor'),
('Wili'		, 'dziecko'	, 'Bestla'),
('Audhumla'	, 'rodzic'	, 'Ymir'),
('Audhumla'	, 'rodzic'	, 'Buri'),
('Ymir'		, 'dziecko'	, 'Audhumla');

GO

------------ POKA¯ WYNIKI ------------

SELECT * FROM Bóstwa;
SELECT * FROM Artefakty;
SELECT * FROM Pokonany;
SELECT * FROM Posiada;
SELECT * FROM Zdolnoœæ;
SELECT * FROM Opiekun;
SELECT * FROM Powi¹zanie ORDER BY probant;

GO
-------------- TESTY ----------------

-- znajdŸ ojca (mêskiego rodzica) Odyna - funkcja
SELECT * FROM znajdŸ_rodzica('Odyn', 'M')
-- znajdŸ matkê (¿eñskiego rodzica) Odyna - funkcja
SELECT * FROM znajdŸ_rodzica('Odyn', 'K')
-- zobacz rodzinê Odyna - funkcja tablicowa
SELECT * FROM rodzina('Odyn')
-- utwórz widok rodziny Odyna - procedura
EXEC widok_rodziny 'Odyn'
-- zobacz wszystkie obiekty
EXEC zobacz_obiekty
-- zobacz widok rodziny Odyna
SELECT * FROM widok_rodziny_Odyn
-- zobacz wszystkie widoki - procedura
EXEC zobacz_widoki 
   --usuñ je - procedura
EXEC  usuñ_widok_rodziny 'Odyn'
-- zobacz wszystkie widoki - procedura
EXEC zobacz_widoki
-- zobacz wszystkie obiekty
EXEC zobacz_obiekty

GO
-------------- INSERT -------------------

INSERT INTO Bóstwa VALUES ('Harold', 'Karze³', 'M')
INSERT INTO Zdolnoœæ VALUES ('Harold', 'epickoœæ')

GO
-------------- UPDATE -------------------

UPDATE Bóstwa
SET imiê = 'Tho³',
rodzaj = 'Karze³'
WHERE imiê = 'Thor'

UPDATE Artefakty
SET nazwa = 'Gromom³otek',
typ = 'Pojazd'
WHERE nazwa = 'Mjolnir'

GO

SELECT * FROM Bóstwa WHERE imiê = 'Tho³' OR imiê = 'Thor'
SELECT * FROM Artefakty WHERE nazwa = 'Gromom³otek' OR nazwa = 'Mjolnir'

GO

-------------- DELETE -------------------

-- usuniêcie bóstwa
SELECT * FROM Bóstwa
DELETE FROM Bóstwa WHERE imiê = 'Thor'
SELECT * FROM Bóstwa
-- usuniêcie artefaktu
SELECT * FROM Artefakty
SELECT * FROM Posiada
DELETE FROM Artefakty WHERE typ = 'Broñ'
SELECT * FROM Artefakty
SELECT * FROM Posiada
-- usuniêcie walki
SELECT * FROM Pokonany
DELETE FROM Pokonany WHERE pokonany = 'Odyn'
SELECT * FROM Pokonany
-- usuniêcie opiekuna
SELECT * FROM Opiekun
DELETE FROM Opiekun WHERE bóstwo = 'Odyn'
SELECT * FROM Opiekun
-- usuniêcie powi¹zañ
SELECT * FROM rodzina('Odyn')
DELETE FROM Powi¹zanie WHERE probant = 'Odyn'
SELECT * FROM rodzina('Odyn')
GO