# Left 4 Dead 2 Play To Earn
Base template for running a server with play to earn support

## Functionality
- When the round ends the winning side and losing sides will earn rewards
- When survivor earns a progress marker will earn rewards
- Setup wallet as command ``!wallet 0x123...``

## Configuring
To configure you will need to manually change some values inside the file before compiling

## Using Database
- Download [Left 4 Dead 2](https://steamcommunity.com/sharedfiles/filedetails/?id=276173458) server files
- Install [sourcemod](https://www.sourcemod.net/downloads.php) and [metamod](https://www.sourcemm.net/downloads.php/?branch=stable)
- Install a database like mysql or mariadb
- Create a user for the database: GRANT ALL PRIVILEGES ON pte_wallets.* TO 'pte_admin'@'localhost' IDENTIFIED BY 'supersecretpassword' WITH GRANT OPTION; FLUSH PRIVILEGES;
- Create a table named ``left4dead2``:
```sql
CREATE TABLE left4dead2 (
    uniqueid VARCHAR(255) NOT NULL PRIMARY KEY,
    walletaddress VARCHAR(255) DEFAULT null,
    value DECIMAL(50, 0) NOT NULL DEFAULT 0
);
```
- Download play_to_earn_*.smx and put inside Left4Dead2/left4dead2/addons/scripting/plugins
- Run the server normally

## Compile
- Install [play_to_earn_database.inc](https://github.com/Play-To-Earn-Currency/source_plugin) dependecy in Left4Dead2/left4dead2/addons/scripting/include
- Copy the play_to_earn.sp inside Left4Dead2/left4dead2/addons/sourcemod/scripting
- Inside the Left4Dead2/left4dead2/addons/sourcemod/scripting should be a file to compile, compile it giving the play_to_earn.sp as parameter