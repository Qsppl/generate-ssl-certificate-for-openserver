: Author Tomokoo
@echo off

net session >nul 2>&1
if NOT %errorLevel% == 0 (
    echo Failure: Administrative permissions required.
    pause >nul
    exit
)

set projectRootPath=%0\..\..

setlocal enableDelayedExpansion
set projectRootName=
for %%F in ("%projectRootPath%") do set projectRootName=%%~nxF

: define domainName as current project root name
set OSPath=C:\OSPanel
set domainName=%projectRootName%
set ApacheVersion=Apache_2.4-PHP_7.2-7.4

set OSConfigPath=%OSPath%\userdata\config
set OSCertPath=%OSConfigPath%\cert_files
set OSApachePath=%OSPath%\modules\http\%ApacheVersion%
set projectCertPath=%0\..

: create .txt config file
set tempConfigFile=generate-temp-config.txt
(
	echo nsComment = "Open Server Panel Generated Certificate"
	echo basicConstraints = CA:false
	echo subjectKeyIdentifier = hash
	echo authorityKeyIdentifier = keyid,issuer
	echo keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	echo.
	echo subjectAltName = @alt_names
	echo [alt_names]
	echo DNS.1 = %domainName%
	echo DNS.2 = www.%domainName%
) > %tempConfigFile%

mkdir %projectCertPath%

set OPENSSL_CONF=%OSApachePath%\conf\openssl.cnf
"%OSApachePath%\bin\openssl" req -x509 -sha256 -newkey rsa:2048 -nodes -days 5475 -keyout %projectCertPath%\%domainName%-rootCA.key -out %projectCertPath%\%domainName%-rootCA.crt -subj /CN=OSPanel-%domainName%/
"%OSApachePath%\bin\openssl" req -newkey rsa:2048 -nodes -days 5475 -keyout %projectCertPath%/%domainName%-server.key -out %projectCertPath%\%domainName%-server.csr -subj /CN=%domainName%/
"%OSApachePath%\bin\openssl" x509 -req -sha256 -days 5475 -in %projectCertPath%\%domainName%-server.csr -extfile %tempConfigFile% -CA %projectCertPath%\%domainName%-rootCA.crt -CAkey %projectCertPath%\%domainName%-rootCA.key -CAcreateserial -out %projectCertPath%\%domainName%-server.crt
"%OSApachePath%\bin\openssl" dhparam -out %projectCertPath%\%domainName%-dhparam.pem 2048

del %projectCertPath%\%domainName%-server.csr
del %projectCertPath%\%domainName%-dhparam.pem
del %projectCertPath%\%domainName%-rootCA.srl
del %tempConfigFile%

set tempConfigFile=%projectRootPath%\%ApacheVersion%_vhost.conf
(
    echo ^<VirtualHost *:%%httpport%%^>
    echo     DocumentRoot    "%%hostdir%%"
    echo     ServerName      "%%host%%"
    echo     ServerAlias     "%%host%%" %%aliases%%
    echo     ScriptAlias     /cgi-bin/ "%%hostdir%%/cgi-bin/"
    echo ^</VirtualHost^>
    echo.
    echo ^<IfModule ssl_module^>
    echo     ^<VirtualHost *:%%httpsport%%^>
    echo         DocumentRoot    "%%hostdir%%"
    echo         ServerName      "%%host%%"
    echo         ServerAlias     "%%host%%" %%aliases%%
    echo         ScriptAlias     /cgi-bin/ "%%hostdir%%/cgi-bin/"
    echo.
    echo         SSLEngine       on
    echo         #Protocols      http/1.1
    echo         #Header         always set Strict-Transport-Security "max-age=94608000"
    echo         #SSLCACertificateFile    ""
    echo         #SSLCertificateChainFile ""
    echo         SSLCertificateFile       "%%hostdir%%/ssl-certificate/%%host%%-server.crt"
    echo         SSLCertificateKeyFile    "%%hostdir%%/ssl-certificate/%%host%%-server.key"
    echo.
    echo         SetEnvIf User-Agent ".*MSIE [6-9].*" ssl-unclean-shutdown
    echo.
    echo         ^<FilesMatch "\.(cgi|shtml|phtml|php)$"^>
    echo             SSLOptions   +StdEnvVars
    echo         ^</FilesMatch^>
    echo.
    echo         ^<Directory "%%hostdir%%/cgi-bin/"^>
    echo             SSLOptions   +StdEnvVars
    echo         ^</Directory^>
    echo     ^</VirtualHost^>
    echo ^</IfModule^>
) > %tempConfigFile%

REM Root
"%projectCertPath%\certmgr.exe" -add -c "%projectCertPath%\%domainName%-rootCA.crt" -s -r currentUser root
echo.Certificate installed

pause