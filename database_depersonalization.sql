CREATE PROCEDURE [dbo].[Depersonalize]
	@profileXml XML
AS
BEGIN

	DECLARE @handle INT  
	EXEC sp_xml_preparedocument @handle OUTPUT, @profileXml;

	DECLARE @updateDataCursor AS CURSOR

	SET @updateDataCursor = CURSOR FOR
	SELECT	[table]		AS [Table],
			[column]	AS [Column],
			'randomize'	AS [Task],
			NULL		AS [Ext]
	  FROM  OPENXML(@handle, '/profile/randomize', 2)  
		WITH (
		[table] NVARCHAR(512),
		[column] NVARCHAR(512))
	UNION
	SELECT	[table]		AS [Table],
			[column]	AS [Column],
			'scramble'	AS [Task],
			NULL		AS [Ext]
	  FROM  OPENXML(@handle, '/profile/scramble', 2)  
		WITH (
		[table] NVARCHAR(512),
		[column] NVARCHAR(512))
	UNION
	SELECT	[table]						AS [Table],
			[column]					AS [Column],
			'mask'						AS [Task],
			ISNULL([inplaintext], 1)	AS [ext]
	  FROM  OPENXML(@handle, '/profile/mask', 2)  
		WITH (
		[table] NVARCHAR(512),
		[column] NVARCHAR(512),
		inplaintext	NVARCHAR(100))
	UNION
	SELECT	[table]		AS [Table],
			[column]	AS [Column],
			'null'		AS [Task],
			NULL		AS [Ext]
	  FROM  OPENXML(@handle, '/profile/null', 2)  
		WITH (
		[table] NVARCHAR(512),
		[column] NVARCHAR(512))
	UNION
	SELECT	[table]		AS [Table],
			[column]	AS [Column],
			'truncate'	AS [Task],
			[value]		AS [Ext]
	  FROM  OPENXML(@handle, '/profile/truncate', 2)  
		WITH (
		[table] NVARCHAR(512),
		[column] NVARCHAR(512),
		[value]	NVARCHAR(100))
	UNION
	SELECT	[table]		AS [Table],
			[column]	AS [Column],
			'replace'	AS [Task],
			[value]		AS [Ext]
	  FROM  OPENXML(@handle, '/profile/replace', 2)  
		WITH (
		[table] NVARCHAR(512),
		[column] NVARCHAR(512),
		[value]	NVARCHAR(100))

	DECLARE @table	AS NVARCHAR(512),
			@column	AS NVARCHAR(512),
			@task	AS NVARCHAR(100),
			@ext	AS NVARCHAR(100)

	OPEN @updateDataCursor
	FETCH NEXT FROM @updateDataCursor INTO @table, @column, @task, @ext

	DECLARE @sqlCommand AS NVARCHAR(1000)

	WHILE @@FETCH_STATUS = 0
	BEGIN

		IF (@task = 'randomize')
		BEGIN
			SET @sqlCommand = 'SELECT RowNum = row_number() OVER ( ORDER BY NEWID() ), ' +
							   @column + ' ' + 
							  'INTO #Random ' +
							   'FROM ' + @table + ' ' +
							   ';WITH Temp AS ' +
								'(' +
									'SELECT ' + @table + '.' + @column + ', ' +
											 'RowNum = row_number() OVER ( ORDER BY NEWID() ) ' +
									  'FROM ' + @table +
								') ' +
								'UPDATE Temp ' +
								'SET    Temp.' + @column + ' = Random.' + @column + ' ' +
								'FROM   Temp ' +
									'INNER JOIN #Random AS Random ON ' +
										'Random.RowNum = Temp.RowNum ' +
							 'DROP TABLE #Random'
		END
		ELSE IF (@task = 'scramble')
		BEGIN

			SET @sqlCommand = 'UPDATE ' + @table + ' ' +
								 'SET ' + @table + '.' + @column + ' = dbo.CharacterScramble(' + @table + '.' + @column + ') ' +
							   'WHERE ' + @table + '.' + @column + ' IS NOT NULL'
		END
		ELSE IF (@task = 'mask')
		BEGIN

			SET @sqlCommand = 'UPDATE ' + @table + ' ' +
								 'SET ' + @table + '.' + @column + ' = dbo.CharacterMask(' + @table + '.' + @column + ', ' + @ext + ', ''x'') ' +
							   'WHERE ' + @table + '.' + @column + ' IS NOT NULL'
		END
		ELSE IF (@task = 'null')
		BEGIN

			SET @sqlCommand = 'UPDATE ' + @table + ' ' +
								 'SET ' + @table + '.' + @column + ' = NULL ' +
							   'WHERE ' + @table + '.' + @column + ' IS NOT NULL'
		END
		ELSE IF (@task = 'truncate')
		BEGIN

			SET @sqlCommand = 'UPDATE ' + @table + ' ' +
								 'SET ' + @table + '.' + @column + ' = LEFT(' + @table + '.' + @column + ', ' + @ext + ') ' +
							   'WHERE ' + @table + '.' + @column + ' IS NOT NULL'
		END
		ELSE IF (@task = 'replace')
		BEGIN

			SET @sqlCommand = 'UPDATE ' + @table + ' ' +
								 'SET ' + @table + '.' + @column + ' = ' + @ext
		END

	
		EXECUTE sp_executesql  @sqlCommand
 
		FETCH NEXT FROM @updateDataCursor INTO @table, @column, @task, @ext
	END

	EXEC sp_xml_removedocument @handle 
	CLOSE @updateDataCursor
	DEALLOCATE @updateDataCursor
END
GO

CREATE VIEW dbo.vwRandom
AS
SELECT RAND() as RandomValue;
GO

CREATE FUNCTION CharacterScramble
(
    @OrigVal varchar(max)
)
RETURNS varchar(max)
WITH ENCRYPTION
AS
BEGIN
 
-- Variables used
DECLARE @NewVal varchar(max);
DECLARE @OrigLen int;
DECLARE @CurrLen int;
DECLARE @LoopCt int;
DECLARE @Rand int;
 
-- Set variable default values
SET @NewVal = '';
SET @OrigLen = DATALENGTH(@OrigVal);
SET @CurrLen = @OrigLen;
SET @LoopCt = 1;
 
-- Loop through the characters passed
WHILE @LoopCt <= @OrigLen
    BEGIN
        -- Current length of possible characters
        SET @CurrLen = DATALENGTH(@OrigVal);
 
        -- Random position of character to use
        SELECT
            @Rand = Convert(int,(((1) - @CurrLen) * 
                               RandomValue + @CurrLen))
        FROM
            dbo.vwRandom;
 
        -- Assembles the value to be returned
        SET @NewVal = @NewVal +
                             SUBSTRING(@OrigVal,@Rand,1);
 
        -- Removes the character from available options
        SET @OrigVal =
                 Replace(@OrigVal,SUBSTRING(@OrigVal,@Rand,1),'');
 
        -- Advance the loop="color:black">
        SET @LoopCt = @LoopCt + 1;
    END
    -- Returns new value
    Return LOWER(@NewVal);
END
GO

CREATE FUNCTION CharacterMask
(
    @OrigVal varchar(max),
    @InPlain int,
    @MaskChar char(1)
)
RETURNS varchar(max)
WITH ENCRYPTION
AS
BEGIN
 
	IF (@InPlain > LEN(@OrigVal))
	BEGIN
		SET @InPlain = LEN(@OrigVal)
	END

    -- Variables used
    DECLARE @PlainVal varchar(max);
    DECLARE @MaskVal varchar(max);
    DECLARE @MaskLen int;
 
    -- Captures the portion of @OrigVal that remains in plain text
    SET @PlainVal = RIGHT(@OrigVal,@InPlain);
    -- Defines the length of the repeating value for the mask
    SET @MaskLen = (DATALENGTH(@OrigVal) - @InPlain);
    -- Captures the mask value
    SET @MaskVal = REPLICATE(@MaskChar, @MaskLen);
    -- Returns the masked value
    Return @MaskVal + @PlainVal;
 
END
GO


