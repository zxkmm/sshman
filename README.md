# sshman
a CLI tool to use / CRUD your remote ssh entrances, designed for both UNIX/Linux and some pseudo terminal.
# warning
## this is not for
- Non-bash enviroment
- this tool is not for manage your local ssh config.
- this tool is not for managing loads of profiles (let's say more than 1000).
- XOR encryption is not safe.
- can't verify if decrypt password is correct, because it would make XOR even more dangerous.
- md5 is not safe.
## be careful
- this tool won't kept your ssh profiles (signature/IP/password) very much safe, just like other tools that save your profiles.
- i'm absolute not responsible for any damage/loss/leak caused by using this tool.