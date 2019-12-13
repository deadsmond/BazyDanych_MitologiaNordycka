IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = N'Mitologia_nordycka')
BEGIN
	CREATE DATABASE Mitologia_nordycka
END

USE Mitologia_nordycka;
GO

------------ USU� TABELE ------------

DROP TABLE IF EXISTS Pokonany;
DROP TABLE IF EXISTS Posiada;
DROP TABLE IF EXISTS Zdolno��;
DROP TABLE IF EXISTS Opiekun;
DROP TABLE IF EXISTS Powi�zanie;
DROP TABLE IF EXISTS B�stwa;
DROP TABLE IF EXISTS Artefakty;

------------ USU� FUNKCJE ------------

DROP FUNCTION IF EXISTS rodzina;
DROP FUNCTION IF EXISTS znajd�_rodzica;
DROP PROCEDURE IF EXISTS widok_rodziny;
DROP PROCEDURE IF EXISTS usu�_widok_rodziny;
DROP PROCEDURE IF EXISTS zobacz_widoki;
DROP PROCEDURE IF EXISTS zobacz_obiekty;

------------ USU� TRIGGERY ------------

DROP TRIGGER IF EXISTS t_powi�zanie_insert;
DROP TRIGGER IF EXISTS t_powi�zanie_delete;
DROP TRIGGER IF EXISTS t_b�stwa_update;
DROP TRIGGER IF EXISTS t_b�stwa_delete;
DROP TRIGGER IF EXISTS t_artefakty_delete;

------------ UTW�RZ TABELE I POWI�ZANIA ------------

CREATE TABLE B�stwa
(
	imi�	VARCHAR(30) PRIMARY KEY,
	rodzaj	VARCHAR(30) CHECK (rodzaj IN ('Istota', 'Zwierz�', 'Cz�owiek','Olbrzym', 'Karze�', 'As', 'Wan')) DEFAULT 'Istota',
	p�e�	CHAR(1)		CHECK (p�e� IN ('M', 'K')) NOT NULL
);

CREATE TABLE Artefakty
(
	nazwa	VARCHAR(30) PRIMARY KEY,
	typ		VARCHAR(30) CHECK (typ IN ('Bro�', 'Ozdoba', 'Pojazd','Inne')) DEFAULT 'Inne',
	rodzaj	VARCHAR(30) CHECK (rodzaj NOT IN ('Bro�', 'Ozdoba', 'Pojazd','Inne')) DEFAULT 'Przedmiot',
	efekt	VARCHAR(30) NULL
);

CREATE TABLE Pokonany
(
	zwyci�zca	VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) DEFAULT 'Hela' ,
	pokonany	VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) NOT NULL
	PRIMARY KEY (zwyci�zca, pokonany)
);

CREATE TABLE Posiada
(
	b�stwo		VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) ON UPDATE CASCADE NOT NULL,
	artefakt	VARCHAR(30) FOREIGN KEY REFERENCES Artefakty(nazwa) ON UPDATE CASCADE PRIMARY KEY
);

CREATE TABLE Zdolno��
(
	b�stwo	VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) NOT NULL,
	cecha	VARCHAR(30) NOT NULL,
	PRIMARY KEY (b�stwo, cecha)
);

CREATE TABLE Opiekun
(
	b�stwo	VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) NOT NULL,
	dziedzina	VARCHAR(30) NOT NULL,
	PRIMARY KEY (b�stwo, dziedzina)
);

CREATE TABLE Powi�zanie
(
	probant	VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) NOT NULL,
	rodzaj	VARCHAR(30) CHECK (rodzaj IN ('rodzic', 'dziecko', 'm��','�ona', 'rodze�stwo')) NOT NULL,
	posta�	VARCHAR(30) FOREIGN KEY REFERENCES B�stwa(imi�) NOT NULL
	PRIMARY KEY (probant, rodzaj, posta�)
);

GO

---------- UTW�RZ TRIGGERY ----------

-----------  POWI�ZANIE  ------------

CREATE TRIGGER t_powi�zanie_insert
ON Powi�zanie
AFTER INSERT
AS

	DECLARE @temp TABLE(
    probant VARCHAR(30),
	rodzaj VARCHAR(30),
	posta� VARCHAR(30)
	);
	
	INSERT INTO @temp
	SELECT posta�, rodzaj, probant FROM inserted

	IF EXISTS (
		SELECT * FROM @temp
		INTERSECT
		SELECT * FROM Powi�zanie
		)
	BEGIN
	-- zmie� rodzaj powi�zania na przeciwny
		UPDATE @temp
		SET rodzaj = CASE rodzaj
					  WHEN 'rodzic' THEN 'dziecko'
					  WHEN 'dziecko' THEN 'rodzic'
					  WHEN 'm��' THEN '�ona'
					  WHEN '�ona' THEN 'm��'
					  WHEN 'rodze�stwo' THEN 'rodze�stwo'
		END

		INSERT INTO Powi�zanie
		SELECT * FROM @temp

	END
GO

CREATE TRIGGER t_powi�zanie_delete
ON Powi�zanie
AFTER DELETE
AS
	DECLARE @temp TABLE(
    probant VARCHAR(30),
	rodzaj VARCHAR(30),
	posta� VARCHAR(30)
	);
	
	INSERT INTO @temp
	SELECT posta�, rodzaj, probant FROM deleted

	-- zmie� rodzaj powi�zania na przeciwny
	UPDATE @temp
	SET rodzaj = CASE rodzaj
				  WHEN 'rodzic' THEN 'dziecko'
				  WHEN 'dziecko' THEN 'rodzic'
				  WHEN 'm��' THEN '�ona'
				  WHEN '�ona' THEN 'm��'
				  WHEN 'rodze�stwo' THEN 'rodze�stwo'
	END

	-- usu� cz�� wsp�ln� tabel 
	
	DECLARE @temp2 TABLE(
    probant VARCHAR(30),
	rodzaj VARCHAR(30),
	posta� VARCHAR(30)
	);

	INSERT INTO @temp2
	SELECT * FROM Powi�zanie
	EXCEPT 
	SELECT * FROM @temp

	TRUNCATE TABLE Powi�zanie

	INSERT INTO Powi�zanie
	SELECT * FROM @temp2

GO

-----------     B�STWA    ------------

CREATE TRIGGER t_b�stwa_update
ON B�stwa
INSTEAD OF UPDATE
AS
	-- nie mo�na dokonywa� wielu modyfikacji naraz
	IF (SELECT COUNT(*) FROM inserted) > 1
	BEGIN
		PRINT 'This database does not allow to update multiple values at once.'
	END
	ELSE
	BEGIN

		INSERT INTO B�stwa VALUES ((SELECT imi� FROM inserted), (SELECT rodzaj FROM inserted), (SELECT p�e� FROM inserted))

		UPDATE Powi�zanie
		SET probant = (SELECT imi� FROM inserted)
		WHERE probant IN (SELECT imi� FROM deleted) 
		UPDATE Powi�zanie
		SET posta� = (SELECT imi� FROM inserted)
		WHERE posta� IN (SELECT imi� FROM deleted)

		UPDATE Posiada
		SET b�stwo = (SELECT imi� FROM inserted)
		WHERE b�stwo IN (SELECT imi� FROM deleted) 

		UPDATE Pokonany
		SET zwyci�zca = (SELECT imi� FROM inserted)
		WHERE zwyci�zca IN (SELECT imi� FROM deleted) 
		UPDATE Pokonany
		SET pokonany = (SELECT imi� FROM inserted)
		WHERE pokonany IN (SELECT imi� FROM deleted) 

		UPDATE Opiekun
		SET b�stwo = (SELECT imi� FROM inserted)
		WHERE b�stwo IN (SELECT imi� FROM deleted) 

		UPDATE Zdolno��
		SET b�stwo = (SELECT imi� FROM inserted)
		WHERE b�stwo IN (SELECT imi� FROM deleted)

		DELETE FROM B�stwa WHERE imi� IN (SELECT imi� FROM deleted)

	END
GO

CREATE TRIGGER t_b�stwa_delete
ON B�stwa
INSTEAD OF DELETE
AS

	DELETE FROM Powi�zanie
	WHERE probant IN (SELECT imi� FROM deleted) 
	DELETE FROM Powi�zanie
	WHERE posta� IN (SELECT imi� FROM deleted) 

	DELETE FROM Posiada
	WHERE b�stwo IN (SELECT imi� FROM deleted) 

	DELETE FROM Pokonany
	WHERE zwyci�zca IN (SELECT imi� FROM deleted) 
	DELETE FROM Pokonany
	WHERE pokonany IN (SELECT imi� FROM deleted) 

	DELETE FROM Opiekun
	WHERE b�stwo IN (SELECT imi� FROM deleted) 

	DELETE FROM Zdolno��
	WHERE b�stwo IN (SELECT imi� FROM deleted) 

	DELETE FROM B�stwa
	WHERE imi� IN (SELECT imi� FROM deleted) 
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

---------- UTW�RZ PROCEDURY ----------

-- znajd� rodzin� danego bohatera

CREATE FUNCTION rodzina ( @imi�  VARCHAR(30) )
    RETURNS TABLE
AS
    RETURN SELECT rodzaj, posta� FROM Powi�zanie WHERE @imi� = probant;
GO

-- znajd� rodzica o danej p�ci

CREATE FUNCTION znajd�_rodzica ( @imi�  VARCHAR(30), @p�e� CHAR(1) )
    RETURNS TABLE
AS
    RETURN (
		SELECT probant 
		FROM Powi�zanie P
		RIGHT OUTER JOIN B�stwa B ON B.imi� = P.probant
		WHERE @imi� = posta� AND @p�e� = B.p�e� AND P.rodzaj = 'rodzic');
GO

-- usu� widok rodziny bohatera

CREATE PROCEDURE usu�_widok_rodziny ( @imi�  VARCHAR(30) )
AS
    EXEC ( 'DROP VIEW IF EXISTS widok_rodziny_' + @imi� + ';');
GO

-- utw�rz widok rodziny bohatera

CREATE PROCEDURE widok_rodziny ( @imi�  VARCHAR(30) )
AS
	EXEC usu�_widok_rodziny @imi�
    EXEC ( 'CREATE VIEW widok_rodziny_' + @imi� + '(rodzaj, posta�)'+
		  ' AS( SELECT rodzaj, posta� FROM Powi�zanie WHERE probant = ''' + @imi� +''' );');
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

INSERT INTO B�stwa VALUES
('Angrboda'	, 'Olbrzym'		, 'M' ),
('Ask'		, 'Cz�owiek'	, 'M' ),
('Audhumla'	, 'Zwierz�'		, 'K' ),
('Aurboda'	, 'Olbrzym'		, 'K' ),
('Balder'	, 'As'			, 'M' ),
('Baugi'	, 'Olbrzym'		, 'M' ),
('Beli'		, 'Olbrzym'		, 'M' ),
('Bergelmir', 'Olbrzym'		, 'M' ),
('Bestla'	, 'Olbrzym'		, 'K' ),
('Bolthorn'	, 'Olbrzym'		, 'M' ),
('Bor'		, 'As'			, 'M' ),
('Bragi'	, 'As'			, 'M' ),
('Brokk'	, 'Karze�'		, 'M' ),
('Buri'		, 'As'			, 'M' ),
('Dragi'	, 'As'			, 'M' ),
('Egil'		, 'Cz�owiek'	, 'M' ),
('Egir'		, 'Olbrzym'		, 'M' ),
('Eitri'	, 'Karze�'		, 'M' ),
('Elli'		, 'Istota'		, 'K' ),
('Embla'	, 'Cz�owiek'	, 'K' ),
('Farbauti'	, 'Olbrzym'		, 'M' ),
('Fenrir'	, 'Zwierz�'		, 'M' ),
('Fjalar'	, 'Cz�owiek'	, 'M' ),
('Fjolnir'	, 'Cz�owiek'	, 'M' ),
('Frejr'	, 'Wan'			, 'M' ),
('Freja'	, 'Wan'			, 'K' ),
('Frigg'	, 'As'			, 'K' ),
('Fulla'	, 'As'			, 'K' ),
('Galar'	, 'Karze�'		, 'M' ),
('Garm'		, 'Zwierz�'		, 'M' ),
('Gerd'		, 'Olbrzym'		, 'K' ),
('Gilling'	, 'Olbrzym'		, 'M' ),
('Gunnlod'	, 'Olbrzym'		, 'K' ),
('Gymir'	, 'Olbrzym'		, 'M' ),
('Heidrun'	, 'Zwierz�'		, 'M' ),
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
('Iwaldi'	, 'Karze�'		, 'M' ),
('Jord'		, 'Olbrzym'		, 'K' ),
('Jormungundr', 'Zwierz�'	, 'M' ),
('Kwasir'	, 'As'			, 'M' ),
('Laufey'	, 'Cz�owiek'	, 'K' ),
('Lit'		, 'Karze�'		, 'M' ),
('Loki'		, 'As'			, 'M' ),
('Magni'	, 'As'			, 'M' ),
('Mimir'	, 'Olbrzym'		, 'M' ),
('Modgud'	, 'Istota'		, 'M' ),
('Modi'		, 'As'			, 'M' ),
('Narfi'	, 'As'			, 'M' ),
('Nidhogg'	, 'Zwierz�'		, 'M' ),
('Njord'	, 'Wan'			, 'M' ),
('Odyn'		, 'As'			, 'M' ),
('Urd'		, 'Istota'		, 'K' ),
('Werdandi'	, 'Istota'		, 'K' ),
('Skuld'	, 'Istota'		, 'K' ),
('Ran'		, 'As'			, 'K' ),
('Ratatosk'	, 'Zwierz�'		, 'M' ),
('Roskwa'	, 'Cz�owiek'	, 'K' ),
('Sif'		, 'As'			, 'K' ),
('Sigyn'	, 'As'			, 'K' ),
('Skadi'	, 'Olbrzym'		, 'K' ),
('Skirnir'	, 'Karze�'		, 'M' ),
('Skrymir'	, 'Olbrzym'		, 'M' ),
('Surtr'	, 'Olbrzym'		, 'M' ),
('Suttung'	, 'Olbrzym'		, 'M' ),
('Thialfi'	, 'Cz�owiek'	, 'M' ),
('Thiazi'	, 'Olbrzym'		, 'M' ),
('Thokk'	, 'Cz�owiek'	, 'K' ),
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
('Mjolnir',		'Bro�'		, 'M�ot'		, 'Si�a' ),
('Bodn',		'Inne'		, 'Kad�'		, 'Poezja' ),
('Son',			'Inne'	    , 'Kad�'		, 'Poezja' ),
('Odrerir',		'Inne'	    , 'Kad�'		, 'Poezja' ),
('Draupnir',	'Ozdoba'	, 'Bransoleta'	, 'Bogactwo' ),
('Gjallerhorn',	'Inne'	    , 'R�g'			, 'Wezwanie' ),
('Gleipnir',	'Inne'	    , '�a�cuch'		, 'Niewola' ),
('Gungnir',		'Bro�'	    , 'W��cznia'	, 'Zwyci�stwo' ),
('Hlidskjalf',	'Inne'	    , 'Tron'		, 'Wiedza' ),
('Huginn',		'Inne'	    , 'Kruk'		, 'Wiedza' ),
('Megingjord',	'Bro�'	    , 'Pas'			, 'Si�a' ),
('Muninn',		'Inne'	    , 'Kruk'		, 'Wiedza' ),
('Naglfar',		'Pojazd'	, 'Statek'		, '�mier�' ),
('Sleipnir',	'Pojazd'	, 'Ko�'			, 'Szybko��' ),
('Sladilfari',	'Pojazd'	, 'Ko�'			, 'Szybko��' );

INSERT INTO Artefakty(nazwa, typ, rodzaj) VALUES
('Brisinig',	'Ozdoba'	, 'Naszyjnik' ),
('Gullenbursti','Pojazd'	, 'Z�oty dzik' ),
('Rati',		'Bro�'	    , 'Wiert�o'	 ),
('Tanngrisnir',	'Pojazd'	, 'Kozio�'),
('Skidbladnir',	'Pojazd'	, 'Statek' ),
('Tanngnjostr',	'Pojazd'	, 'Kozio�');

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

INSERT INTO Zdolno�� VALUES
('Thor'			, 'Si�a'),
('Loki'			, 'Spryt'),
('Loki'			, 'Zmienianie kszta�t�w'),
('Balder'		, 'Pi�kno'),
('Hermod'		, 'Zr�czno��'),
('Hungi'		, 'Szybko��'),
('Hyrrokkin'	, 'Si�a'),
('Idunn'		, 'Wieczna m�odo��'),
('Lit'			, 'Pech'),
('Loki'			, 'Chodzenie w powietrzu'),
('Magni'		, 'Si�a'),
('Modi'			, 'Odwaga'),
('Odyn'			, 'M�dro��'),
('Odyn'			, 'Spryt'),
('Thrud'		, 'Si�a');

INSERT INTO Opiekun VALUES
('Thor'		, 'Grzmoty'),
('Thor'		, 'Pioruny'),
('Thor'		, 'Burze'),
('Loki'		, 'Z�odzieje'),
('Bragi'	, 'Poezja'),
('Egir'		, 'Morze'),
('Elli'		, 'Staro��'),
('Heimdall'	, 'Bogowie'),
('Hel'		, '�mier�'),
('Hoenir'	, 'M�dro��'),
('Jord'		, 'Ziemia'),
('Kwasir'	, 'M�dro��'),
('Ran'		, 'Zmarli na morzu'),
('Ran'		, 'Fale morskie'),
('Skuld'	, 'Przysz�o��'),
('Tyr'		, 'Wojna'),
('Ullr'		, 'Polowanie'),
('War'		, 'Ma��e�stwo'),
('Werdandi'	, 'Tera�niejszo��'),
('Odyn'		, 'Wi�niowie'),
('Odyn'		, 'Szubienice'),
('Dragi'	, 'Poezja'),
('Odyn'		, 'Podr�nicy');

INSERT INTO Powi�zanie VALUES
('Aurboda'	, 'rodzic'	, 'Gerd'),
('Balder'	, 'dziecko'	, 'Odyn'),
('Ymir'		, 'rodzic'	, 'Bergelmir'),
('Bestla'	, 'rodzic'	, 'Odyn'),
('Bestla'	, 'rodze�stwo'	, 'Mimir'),
('Bestla'	, 'rodzic'	, 'Wili'),
('Bestla'	, 'rodzic'	, 'We'),
('Bestla'	, '�ona'	, 'Bor'),
('Bolthorn'	, 'rodzic'	, 'Bestla'),
('Bolthorn'	, 'rodzic'	, 'Mimir'),
('Bor'		, 'dziecko'	, 'Buri'),
('Bor'		, 'rodzic'	, 'Odyn'),
('Bor'		, 'rodzic'	, 'Wili'),
('Bor'		, 'rodzic'	, 'We'),
('Baugi'	, 'rodze�stwo', 'Suttung'),
('Buri'		, 'rodzic'	, 'Bor'),
('Egil'		, 'rodzic'	, 'Thialfi'),
('Egil'		, 'rodzic'	, 'Roskwa'),
('Egir'		, 'm��'		, 'Ran'),
('Eitri'	, 'rodze�stwo', 'Brokk'),
('Farbauti'	, 'rodzic'	, 'Loki'),
('Fenrir'	, 'dziecko'	, 'Loki'),
('Loki'		, 'rodzic'	, 'Fenrir'),
('Angrboda'	, 'rodzic'	, 'Fenrir'),
('Fjalar'	, 'rodze�stwo', 'Galar'),
('Fjolnir'	, 'dziecko'	, 'Frejr'),
('Fjolnir'	, 'dziecko'	, 'Gerd'),
('Frejr'	, 'rodze�stwo', 'Freja'),
('Frigg'	, '�ona'	, 'Odyn'),
('Frigg'	, 'rodzic'	, 'Balder'),
('Gilling'	, 'rodzic'	, 'Suttung'),
('Gilling'	, 'rodzic'	, 'Baugi'),
('Gunnlod'	, 'dziecko'	, 'Suttung'),
('Gymir'	, 'rodzic'	, 'Gerd'),
('Hel'		, 'dziecko'	, 'Loki'),
('Hel'		, 'dziecko'	, 'Angrboda'),
('Odyn'		, 'rodzic'	, 'Hermod'),
('Hod'		, 'rodze�stwo', 'Balder'),
('Jord'		, 'rodzic'	, 'Thor'),
('Jormungundr'	, 'dziecko', 'Loki'),
('Loki'		, 'rodze�stwo', 'Thor'),
('Loki'		, 'dziecko'	, 'Farbauti'),
('Loki'		, 'dziecko'	, 'Laufey'),
('Magni'	, 'dziecko'	, 'Thor'),
('Modi'		, 'dziecko'	, 'Thor'),
('Narfi'	, 'dziecko'	, 'Loki'),
('Narfi'	, 'dziecko'	, 'Sigyn'),
('Narfi'	, 'rodze�stwo', 'Wali'),
('Njord'	, 'rodzic'	, 'Freja'),
('Njord'	, 'rodzic'	, 'Frejr'),
('Ran'		, '�ona'	, 'Egir'),
('Roskwa'	, 'rodze�stwo', 'Thialfi'),
('Sif'		, '�ona'	, 'Thor'),
('Sigyn'	, '�ona'	, 'Loki'),
('Skadi'	, 'dziecko'	, 'Thiazi'),
('Skadi'	, '�ona'	, 'Njord'),
('Suttung'	, 'dziecko'	, 'Gilling'),
('Thiazi'	, 'rodzic'	, 'Skadi'),
('Odyn'		, 'rodzic'	, 'Thor'),
('Thor'		, 'dziecko'	, 'Odyn'),
('Thrud'	, 'dziecko'	, 'Thor'),
('Tyr'		, 'dziecko', 'Odyn'),
('Odyn'		, 'rodzic'	, 'Tyr'),
('We'		, 'rodze�stwo', 'Odyn'),
('We'		, 'dziecko'	, 'Bor'),
('We'		, 'dziecko'	, 'Bestla'),
('Widar'	, 'dziecko'	, 'Odyn'),
('Wili'		, 'rodze�stwo', 'Odyn'),
('Wili'		, 'dziecko'	, 'Bor'),
('Wili'		, 'dziecko'	, 'Bestla'),
('Audhumla'	, 'rodzic'	, 'Ymir'),
('Audhumla'	, 'rodzic'	, 'Buri'),
('Ymir'		, 'dziecko'	, 'Audhumla');

GO

------------ POKA� WYNIKI ------------

SELECT * FROM B�stwa;
SELECT * FROM Artefakty;
SELECT * FROM Pokonany;
SELECT * FROM Posiada;
SELECT * FROM Zdolno��;
SELECT * FROM Opiekun;
SELECT * FROM Powi�zanie ORDER BY probant;

GO
-------------- TESTY ----------------

-- znajd� ojca (m�skiego rodzica) Odyna - funkcja
SELECT * FROM znajd�_rodzica('Odyn', 'M')
-- znajd� matk� (�e�skiego rodzica) Odyna - funkcja
SELECT * FROM znajd�_rodzica('Odyn', 'K')
-- zobacz rodzin� Odyna - funkcja tablicowa
SELECT * FROM rodzina('Odyn')
-- utw�rz widok rodziny Odyna - procedura
EXEC widok_rodziny 'Odyn'
-- zobacz wszystkie obiekty
EXEC zobacz_obiekty
-- zobacz widok rodziny Odyna
SELECT * FROM widok_rodziny_Odyn
-- zobacz wszystkie widoki - procedura
EXEC zobacz_widoki 
   --usu� je - procedura
EXEC  usu�_widok_rodziny 'Odyn'
-- zobacz wszystkie widoki - procedura
EXEC zobacz_widoki
-- zobacz wszystkie obiekty
EXEC zobacz_obiekty

GO
-------------- INSERT -------------------

INSERT INTO B�stwa VALUES ('Harold', 'Karze�', 'M')
INSERT INTO Zdolno�� VALUES ('Harold', 'epicko��')

GO
-------------- UPDATE -------------------

UPDATE B�stwa
SET imi� = 'Tho�',
rodzaj = 'Karze�'
WHERE imi� = 'Thor'

UPDATE Artefakty
SET nazwa = 'Gromom�otek',
typ = 'Pojazd'
WHERE nazwa = 'Mjolnir'

GO

SELECT * FROM B�stwa WHERE imi� = 'Tho�' OR imi� = 'Thor'
SELECT * FROM Artefakty WHERE nazwa = 'Gromom�otek' OR nazwa = 'Mjolnir'

GO

-------------- DELETE -------------------

-- usuni�cie b�stwa
SELECT * FROM B�stwa
DELETE FROM B�stwa WHERE imi� = 'Thor'
SELECT * FROM B�stwa
-- usuni�cie artefaktu
SELECT * FROM Artefakty
SELECT * FROM Posiada
DELETE FROM Artefakty WHERE typ = 'Bro�'
SELECT * FROM Artefakty
SELECT * FROM Posiada
-- usuni�cie walki
SELECT * FROM Pokonany
DELETE FROM Pokonany WHERE pokonany = 'Odyn'
SELECT * FROM Pokonany
-- usuni�cie opiekuna
SELECT * FROM Opiekun
DELETE FROM Opiekun WHERE b�stwo = 'Odyn'
SELECT * FROM Opiekun
-- usuni�cie powi�za�
SELECT * FROM rodzina('Odyn')
DELETE FROM Powi�zanie WHERE probant = 'Odyn'
SELECT * FROM rodzina('Odyn')
GO