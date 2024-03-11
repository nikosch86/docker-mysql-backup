About
=====

The docker-mysql-backup image is meant to be run alongside a deployment that features a mysql/mariadb container that needs to be backed up.

The backup is performed using  [mydumper](http://centminmod.com/mydumper.html), a fast MySQL backup utility.

Usage
=====

Add a service to your docker-compose file like so:
```
version: '2'

volumes:
  db-data:

services:
  mysql:
    image: mysql
    volumes:
      - db-data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD
      - MYSQL_DATABASE
      - MYSQL_USER
      - MYSQL_PASSWORD
    restart: unless-stopped
    ports:
      - 3406:3306
  backup:
    image: nikosch86/docker-mysql-backup:develop
    volumes:
        - ./data/backup:/backup
    environment:
      - MYSQL_ROOT_PASSWORD
```

as you can see it is best practice to store your mysql secrets in a .env file, so both containers have access to it  
the minimal viable configuration just needs the root password, it will backup all databases and look for a container named `mysql` on port `3306`  
be aware, the backup container will create the folder `/backup` and use `UID` and `GID` 1000 to own it.  
That means any folder mounted to the `/backup` location will be affected by that.  

additional configuration can be done by using these environment variables:  

* `MYSQL_CONTAINER`
* `MYSQL_PORT`
* `MYSQL_DATABASE`
* `BACKUP_UID`
* `BACKUP_GID`
* `UMASK`
* `BASE_DIR`
* `MODE`
* `RESTORE_DIR`
* `OPTIONS`

`BASE_DIR` is the directory the backups will be written to inside the container.  

setting `OPTIONS` will override the options set for `mydumper` / `myloader`  

The container will stop automatically as soon as the backup is done.
To start backing up you need to start the container.  

`docker-compose up -d backup`

__restore__

To restore a backup, the environment variable `MODE` needs to be set to `RESTORE`  
`RESTORE_DIR` needs to be set to the directory of your backup  
Starting the container will use `myload` to restore the specified backup into the  
specified container and database  
