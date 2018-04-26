DECLARE @profileXml AS XML

SET @profileXml = '
	<profile>
		<randomize>
			<table>Person</table>
			<column>FirstName</column>
		</randomize>
		<randomize>
			<table>Person</table>
			<column>LastName</column>
		</randomize>
		<scramble>
			<table>Person</table>
			<column>MiddleName</column>
		</scramble>
		<mask>
			<table>Person</table>
			<column>PhoneNumber</column>
			<inplaintext>1</inplaintext>
		</mask>
		<null>
			<table>Person</table>
			<column>Birthdate</column>
		</null>
		<truncate>
			<table>Person</table>
			<column>MobilePhoneNumber</column>
			<value>4</value>
		</truncate>
		<replace>
			<table>Person</table>
			<column>EmailAddress</column>
			<value>CONVERT(NVARCHAR(36), newid()) + ''@arlanet.nl''</value>
		</replace>
		<replace>
			<table>Person</table>
			<column>HomeEmailAddress</column>
			<value>''void@arlanet.com''</value>
		</replace>		
	</profile>'

EXEC [Depersonalize] @profileXml