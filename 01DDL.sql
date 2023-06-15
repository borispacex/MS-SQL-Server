-- Crear la base de datos
CREATE DATABASE DbBank;
-- Usar la base de datos
USE DbBank;

/********************* Crear y modificar tabla (CREATE, ALTER) ************************/
-- Creamos la tabla Cliente
CREATE TABLE Client(
	ID int primary key identity(1, 1),
	Name varchar(200) not null,
	PhoneNumber varchar(40) not null,
	Email varchar(50),
	Balance decimal(10, 2)
);
-- Modificamos la tabla Cliente, eliminamos la columna Balance
ALTER TABLE Client
DROP column Balance;
-- Modificamos la tabla Cliente, agregamos la columna report registration
ALTER TABLE Client
ADD RegDate datetime default GETDATE();
-- Modificamos la tabla Cliente, modificamos la columna para que sea no nulo
ALTER TABLE Client
ALTER column RegDate datetime not null;


/********************* Insertar, Editar, Eliminar registros (INSERT, UPDATE, DELETE) ************************/
-- Agregamos un registro en cliente
INSERT INTO Client(Name, PhoneNumber, Email)
VALUES ('Pedro', '84123123', 'pedro@test.com');
INSERT INTO Client(Name, PhoneNumber)
VALUES ('Boris', '000123');
-- Ver registros de cliente
SELECT * FROM Client;
-- Modificar un registro
UPDATE Client SET Email = 'Pedro@gmail.com' 
WHERE ID = 1;
-- Eliminar un registro
DELETE FROM Client
WHERE Name = 'Boris';

/********************* Crear tablas relacionadas (FK REFERENCES) ************************/
CREATE TABLE AccountType(
	ID int primary key identity(1, 1),
	Name varchar(100) not null,
	RegDate datetime not null default GETDATE()
);
CREATE TABLE TransactionType(
	ID int primary key identity(1, 1),
	Name varchar(100) not null,
	RegDate datetime not null default GETDATE()
);
CREATE TABLE Account(
	ID int primary key identity(1, 1),
	AccountType int not null FOREIGN KEY REFERENCES AccountType(ID),
	ClientID int not null FOREIGN KEY REFERENCES Client(ID),
	Balance decimal(10, 2) not null,
	RegDate datetime not null default GETDATE()
);
CREATE TABLE BankTransaction(
	ID int primary key identity(1, 1),
	AccountID int not null FOREIGN KEY REFERENCES Account(ID),
	TransactionType int not null FOREIGN KEY REFERENCES TransactionType(ID),
	Amount decimal(10, 2) not null,
	ExternalAccount int null,
	RegDate datetime not null default GETDATE()
);
-- agregamos registros
INSERT INTO AccountType(Name)
VALUES('Personal'), ('Nomina'), ('Ahorro');

INSERT INTO TransactionType(Name)
VALUES ('Deposito en Efectivo'),('Retiro en Efectivo'),('Deposito via Transferencia'),('Retiro via Transferencia');

INSERT INTO Account(AccountType, ClientID, Balance)
VALUES (1, 1, 500), (2, 1, 10000), (1, 2, 3000), (2, 1, 14000);

INSERT INTO BankTransaction(AccountID, TransactionType, Amount, ExternalAccount)
VALUES (1, 1, 100, NULL), (1, 3, 100, 123456), (3, 1, 100, NULL), (3, 3, 100, 454545);

/********************* Uso de JOINS (INNER, LEFT, RIGHT, FULL OUTER) ************************/
SELECT a.ID, acc.Name as AccountName, c.Name as ClientName, a.Balance, a.RegDate
FROM Account a
INNER JOIN Client c ON (a.ClientID = c.ID)
INNER JOIN AccountType acc ON (a.AccountType = acc.ID);

SELECT b.ID, c.Name as ClientName, t.Name as TypeOfTransaction, b.Amount, b.ExternalAccount
FROM BankTransaction b
INNER JOIN Account a ON b.AccountID = a.ID
INNER JOIN Client c ON a.ClientID = c.ID
INNER JOIN TransactionType t ON b.TransactionType = t.ID;

SELECT a.ID, c.Name as ClientName, a.Balance, a.RegDate
FROM Account a
LEFT JOIN Client c ON a.ClientID = c.ID;

SELECT a.ID, c.Name as ClientName, a.Balance, a.RegDate
FROM Account a
RIGHT JOIN Client c ON a.ClientID = c.ID;

SELECT a.ID, c.Name as ClientName, a.Balance, a.RegDate
FROM Account a
FULL OUTER JOIN Client c ON a.ClientID = c.ID;

/********************* Procedimientos Almacenados ************************/
-- procedimiento de
CREATE PROCEDURE SelectAccount
AS
	SELECT a.ID, acc.Name as AccountName, c.Name as ClientName, a.Balance, a.RegDate
	FROM Account a
	JOIN AccountType acc ON a.AccountType = acc.ID
	JOIN Client c ON a.ClientID = c.ID;
GO
-- ejecutar
EXEC SelectAccount;
-- actualizamos el procedimiento para con parametros
ALTER PROCEDURE SelectAccount
	@ClientID INT = NULL
AS
	IF @ClientID IS NULL
		BEGIN
			SELECT a.ID, acc.Name as AccountName, c.Name as ClientName, a.Balance, a.RegDate
			FROM Account a
			JOIN AccountType acc ON a.AccountType = acc.ID
			JOIN Client c ON a.ClientID = c.ID;
		END
	ELSE
		BEGIN
			SELECT a.ID, acc.Name as AccountName, c.Name as ClientName, a.Balance, a.RegDate
			FROM Account a
			JOIN AccountType acc ON a.AccountType = acc.ID
			JOIN Client c ON a.ClientID = c.ID
			WHERE a.ClientID = @ClientID;
		END
GO;
-- ejecutar
EXEC SelectAccount @ClientID = 1;
-- Procedimiento para insertar
CREATE PROCEDURE InsertClient
	@Name varchar(200),
	@PhoneNumber varchar(40),
	@Email varchar(50) = null
AS
	INSERT INTO Client (Name, PhoneNumber, Email)
	VALUES (@Name, @PhoneNumber, @Email);
GO
-- Ejectuar
EXEC InsertClient @Name = 'Jose', @PhoneNumber = '0000000';
SELECT * FROM Client;

/********************* Triggers (AFTER INSERT; INSTEAD OF DELETE) ************************/
-- Trigger para 
CREATE TRIGGER ClientAfterInsert
ON Client
AFTER INSERT
AS
	DECLARE @NewClientID int;

	SET @NewClientID = (SELECT ID FROM inserted);

	INSERT INTO Account(AccountType, ClientID, Balance)
	VALUES (1, @NewClientID, 0)
GO
-- ejecutar
EXEC InsertClient @Name = 'Alex', @PhoneNumber = '00000001';
SELECT * FROM Account a
INNER JOIN Client c ON a.ClientID = c.ID
WHERE c.Name = 'Alex';

-- Actualizamos tabla Account para ClientID null
ALTER TABLE Account
ALTER column ClientID int null;
-- Trigger para eliminar
CREATE TRIGGER ClientInsteadOfDelete
ON Client
INSTEAD OF DELETE
AS
	DECLARE @DeletedID INT;

	SET @DeletedID = (SELECT ID FROM deleted);
	
	UPDATE Account SET ClientID = NULL
	WHERE ClientID = @DeletedID;

	DELETE FROM Client WHERE ID = @DeletedID;

GO
-- ejecutamos
SELECT * FROM Client;
DELETE FROM Client WHERE ID  = 5;
EXEC SelectAccount;

/********************* Transacciones (COMMIT, ROLLBACK) ************************/
-- Primero vamos a crear un procedimiento
ALTER PROCEDURE InsertBankTransaction
	@AccountID int,
	@TransactionType int,
	@Amount decimal(10,2),
	@ExternalAccount int = null
AS
	DECLARE @CurrentBalance decimal(10,2), @NewBalance decimal(10,2)
	BEGIN TRANSACTION;
	
	SET @CurrentBalance = (SELECT Balance FROM Account WHERE ID = @AccountID);

	-- obtener nuevo saldo
	IF @TransactionType = 2 OR @TransactionType = 4
		-- retiros
		SET @NewBalance = @CurrentBalance - @Amount;
	ELSE
		-- depositos
		SET @NewBalance = @CurrentBalance + @Amount;
	-- Actualizar el saldo de la cuenta
	UPDATE Account SET Balance = @NewBalance WHERE ID = @AccountID;
	-- Insertar el registro de la operacion
	INSERT INTO BankTransaction (AccountID, TransactionType, Amount, ExternalAccount)
	VALUES (@AccountID, @TransactionType, @Amount, @ExternalAccount);

	IF @NewBalance >= 0
		COMMIT TRANSACTION;
	ELSE
		ROLLBACK TRANSACTION;
GO
-- ahora ejecutamos
EXEC SelectAccount;
SELECT * FROM TransactionType;

EXEC InsertBankTransaction @AccountID = 1, @TransactionType = 2, @Amount = 1000;
EXEC SelectAccount;
