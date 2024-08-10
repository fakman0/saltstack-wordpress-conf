## Preparation
You must have one Ubuntu 22.04 (ubuntu22) and one CentOS Stream 9 (centos9) minion:
> Make sure the minion names match exactly and are of version '3007.0' or higher.
```
root@SaltStack-master:/# salt "*" test.ping
centos9:
    True
ubuntu22:
    True
root@SaltStack-master:/# salt '*' grains.get saltversion
centos9:
    3007.0
ubuntu22:
    3007.0
```
## Installation
```
git clone https://github.com/fakman0/saltstack-wordpress-conf.git
cd saltstack-wordpress-conf
cp -r pillar /srv/
cp -r salt /srv/
```
> The mine function should be used to store data in the pillar data to ensure that minions have each other's IP addresses.
```
salt '*' saltutil.pillar_refresh
salt '*' pillar.get mine_functions
salt '*' mine.update
```
> Confirm the accuracy of the data.
```
root@SaltStack-master:/# salt '*' mine.get '*' internal_ip_addrs
centos9:
    ----------
    centos9:
        - 92.xx.xx.86
    ubuntu22:
        - 92.xx.xx.82
ubuntu22:
    ----------
    centos9:
        - 92.xx.xx.86
    ubuntu22:
        - 92.xx.xx.82
```

#### You are ready to start the configuration.
```
salt "*" state.sls wordpress
```
