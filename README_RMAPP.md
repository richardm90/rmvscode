# rmapp



## Prerequisites

The following `RMTOOLS` tools are required and will need to be compiled before
you can build the backend application.

* `common`
* `rmcrtobj`

Ensure your user has access to use the `QSYS/QCLSTMF` program, which is required
by the `rmrunclp` tool used to build the application.

`GRTOBJAUT OBJ(QSYS/QCLSTMF) OBJTYPE(*PGM) USER(*PUBLIC) AUT(*USE)`

Ensure your user has access to use the `QSYS/ADDPFTRG` program, which is 
to create triggers during the database installation.

`GRTOBJAUT OBJ(QSYS/ADDPFTRG) OBJTYPE(*CMD) USER(*PUBLIC) AUT(*USE)`

Connect as a standard user e.g. `RICHARD`.

```shell
mkdir /prj
cd /prj
git clone git@bitbucket.org:richardm90/rmapp.git
```


Connect as a user with `*ALLOBJ` authority e.g. `HAL`.

```shell
# NGINX package
yum install nginx

# Set up the NGINX configuration
cp -r /prj/rmapp/webclient/nginx/* /QOpenSys/etc/nginx/

# Service Commander package
yum install service-commander

# Set up the Service Commander configurations
cp /prj/rmapp/webclient/sc/* /QOpenSys/etc/sc/services/

# Global Node.js packages
npm install -g nodemon
```



## Installation

Connect as a standard user e.g. `RICHARD`.

```shell
cd /prj/rmapp
install.sh
```

The `install.sh` performs the following steps.

1. Builds the database library `RMAPPDB`
1. Builds the application library `RMAPP`
1. Seeds `CUSTOMER_DETAILS`
1. Sets up the Web App
1. Sets up the Dummy Web API Apps
1. Installs `acme.sh`
1. Sets the `acme.sh` alias in the `.profile` file



### RMWEBAPP Subsystem

Now create the `RMWEBAPP` subsystem and associated objects.

Connect as a user with *ALLOBJ authority e.g. HAL.

```shell
/prj/rmapp/setup_rmwebapp.sh

# If needed you can delete the subsystem and associated 
# objects with the following command
/prj/rmapp/trash_rmwebapp.sh
```

**Note** the `start_rmwebapp.sh` is executed when the subsystem starts.

### Useful References

* [A NodeJS Website on IBM i](https://powerwire.eu/a-nodejs-website-on-ibm-i)
* [A NodeJS Website on IBM i – The Secure Version](https://powerwire.eu/a-nodejs-website-on-ibm-i-the-secure-version)



## Create Certificate

It is preferable to create a certificate from an recognised CA, rather than use a self signed certificate. This can be achieved using the `acme.sh` Bash script.

**Note** the main `install.sh` script installs `install.sh` and sets the `acme.sh` alias in `.profile`.

### Use DNS Mode

* `rmsoftwareservices.co.uk` does has a DNS API (managed by CloudFlare)

Connect as a standard user e.g. `RICHARD`.

```shell
# Export CloudFlare API token
export CF_Token="<cloudflare_api_token>"

# Issue a certificate
# - note the alias sets the certs home to $HOME/.acme.sh/certs
acme.sh --issue --dns dns_cf --domain rmwebsrv.rmsoftwareservices.co.uk --accountemail  "richard@rmsoftwareservices.co.uk" --server letsencrypt

# List certificates
acme.sh --list
```

#### Renew Certificate

```shell
# Renew a certificate for a specific domain
# - with optional '--force' param
acme.sh --renew --domain rmwebsrv.rmsoftwareservices.co.uk [--force]

# Renew all certificates
acme.sh --renew-all [--force]
```



### Use DNS Alias Mode

* `richardmoulton.uk` does NOT have a DNS API (managed by CloudFlare)
* `richardmoulton.co.uk` does have a DNS API so will act as the alias for `richardmoulton.uk` (managed by GoDaddy)
* Add a CNAME record to `richardmoulton.uk` as per `acme.sh` instructions
* For my test I created a CNAME record with a name of `_acme-challenge.ibmcecc` and content of `_acme-challenge.richardmoulton.co.uk`
* The domain DNS is managed by CloudFlare so I had to disable Proxy option
* Note that the certificate can be for multiple domains or subdomains, simply include multiple domains params on the `acme.sh` command e.g. `--domain ibmcecc.richardmoulton.uk --domain rmwebsrv.rmsoftwareservices.co.uk`

Connect as a standard user e.g. `RICHARD`.

```shell
# Export GoDaddy API credentials
export GD_Key="<godaddy_key>"
export GD_Secret="<godaddy_secret>"

# Issue a certificate
# - note the alias sets the certs home to $HOME/.acme.sh/certs
acme.sh --issue --dns dns_gd --domain ibmcecc.richardmoulton.uk --challenge-alias richardmoulton.co.uk --accountemail  "hello@richardmoulton.co.uk" --server letsencrypt

# List certificates
acme.sh --list
```



## RMWEBAPP Permissions

Connect as a user with *ALLOBJ authority e.g. HAL.

```shell
# RMWEBAPP needs permissions to the NGINX log files
system "CHGAUT OBJ('/QOpenSys/var/log/nginx/') USER(RMWEBAPP) DTAAUT(*RWX) OBJAUT(*ALL) SUBTREE(*ALL) SYMLNK(*NO)"

# RMWEBAPP needs permissions to the NGINX configuration directory
system "CHGAUT OBJ('/QOpenSys/etc/nginx/') USER(RMWEBAPP) DTAAUT(*RWX) OBJAUT(*ALL) SUBTREE(*ALL)"

# RMWEBAPP needs read access to the certificate key
system "CHGAUT OBJ('/prj/acme.sh/certs/rmwebsrv.rmsoftwareservices.co.uk_ecc/rmwebsrv.rmsoftwareservices.co.uk.key') USER(RMWEBAPP) DTAAUT(*R) OBJAUT(*NONE)"
```



### NGINX

The default `NGINX` server configuration, included within the `rmapp` repo, 
uses the Mozilla Modern configuration, which means the `dhparam.pem` file is 
not required. 

If this is changed to use the Mozilla Intermediate configuration then you may
need to install the `dhparam.pem` file. Refer to the `README_NGINX.md` document
for details on how to create this file.



## Service Commander

### Dummy Node Apps

**Note** the main `install.sh` script sets up the dummy Node.js apps.

These are useful for testing the proxy server settings and also managing multiple applications within service commander.

These dummy apps provide the following endpoints.

* https://rmwebsrv.rmsoftwareservices.co.uk/api/webapi1
* https://rmwebsrv.rmsoftwareservices.co.uk/api/webapi2

### Start the Application

```shell
# On the IBM i server as user HAL
sc start group:rmwebapp

# ... or on the IBM i ... STRSBS SBSD(RMWEBAPP)

# Check the status
sc check group:rmwebapp

# Stop all services
sc stop group:rmwebapp
```



## Running the Web App

**Note:** update the IP address and specify the user password in the following command.

```shell
cd ~/git/rmapp/webclient
export CONNECTION_STRING="Driver={IBM i Access ODBC Driver};System=129.40.94.233;UID=richard;PWD=<password>;DBQ=,RMAPPDB,RMAPP,RMTOOLS,QGPL,QTEMP;NAM=1;CMT=0;"
nodemon -L
```

Now, point your browser at the appropriate URL.

https://rmwebsrv.rmsoftwareservices.co.uk/customers


## Running the 5250 UI

```shell
CHGLIBL LIBL(RMAPPDB RMAPP RMTOOLS QGPL QTEMP)
CALL PGM(WRKCUS)
```
