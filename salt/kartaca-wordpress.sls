{% set data = pillar.get('kartaca-pillar', {}) %}
{% set ubuntu22ip = salt['mine.get']('ubuntu22', 'internal_ip_addrs') %}
{% set centos9ip = salt['mine.get']('centos9', 'internal_ip_addrs') %}

{#########################################}
{#########################################}
{### ubuntu22 and centos9 common tasks ###}
{#########################################}
{#########################################}

{# Creates the "kartaca_group" group with group id 2024. #}
kartaca_group:
  group.present:
    - gid: 2024

{# Creates a user named Kartaca with user and group ID 2024, home directory /home/krt, default shell /bin/bash, password kartaca2024 and defines sudo authority. #}
create_user:
  user.present:
    - name: kartaca
    - uid: 2024
    - gid: 2024
    - password: {{ data['kartaca_password'] }}
    - hash_password: true
    - shell: /bin/bash
    - home: /home/krt
    - createhome: True
    - groups:
     {% if grains['id'] == 'centos9' %}
        - wheel
     {% elif grains['id'] == 'ubuntu22' %}
        - sudo
     {% endif %}

{# Defines the permission to use the package manager without a password. #}
/etc/sudoers.d/kartaca_roles:
  file.managed:
    - name: /etc/sudoers.d/kartaca_roles
  {% if grains['id'] == 'centos9' %}
    - contents: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/yum"
  {% elif grains['id'] == 'ubuntu22' %}
    - contents: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/apt"
  {% endif %}

{# Sets the time zone "Europe/Istanbul". #}
set_timezone:
  cmd.run:
    - name: timedatectl set-timezone Europe/Istanbul
    - user: root
    - timeout: 60

{# Activates ip forwarding permanently. #}
enable_ip_forwarding:
  sysctl.present:
    - name: net.ipv4.ip_forward
    - value: 1
    - config: /etc/sysctl.conf

{# Installs the necessary packages. #}
install_tools:
  pkg.installed:
    - names:
    {% if grains['id'] == 'centos9' %}
      - epel-release
      - htop
      - traceroute
      - iputils
      - bind-utils
      - sysstat
      - mtr
      - wget
    {% elif grains['id'] == 'ubuntu22' %}
      - htop
      - tcptraceroute
      - iputils-ping
      - dnsutils
      - sysstat
      - mtr
{% endif %}

{# Installs terraform version 1.6.4 #}
hashicorp_repo:
  cmd.run:
    {% if grains['id'] == 'centos9' %}
    - name: "wget -O- https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo | sudo tee /etc/yum.repos.d/hashicorp.repo &&
    yum install terraform-1.6.4 -y"
    - unless: 'which terraform'
    {% elif grains['id'] == 'ubuntu22' %}
    - name: "rm -rf /usr/share/keyrings/hashicorp-archive-keyring.gpg &&
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg &&
    gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint &&
    echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list &&
    sudo apt update &&
    apt install terraform=1.6.4-1 -y"
    - unless: 'which terraform'
{% endif %}

{# Assigns the address "kartaca.local" to all addresses at the IP address "192.168.168.128/28" in the host file. #}
update_hosts_file:
  file.append:
    - name: /etc/hosts
    - text: |
        {% for i in range(1, 16) %}
        192.168.168.{{ (i-1) | int + 129 }} kartaca.local
        {% endfor %}
    - unless: salt '*' file.grep text="192.168.168.129 kartaca.local"

{#########################################}
{#########################################}
{###           centos9 tasks           ###}
{#########################################}
{#########################################}
{% if grains['id'] == 'centos9' %}

{# Installs the necessary packages. #}
install_php_nginx:
  pkg.installed:
    - pkgs:
      - yum-utils
      - ed
      - zip
      - nginx
      - php
      - php-fpm
      - php-mysqlnd
      - php-mbstring
      - php-intl
      - php-xml

{# Activates nginx service. #}
nginx:
  service.running:
    - enable: True

{# Activates php-fpm service. #}
php-fpm:
  service.running:
    - enable: True

{# Copies the "wordpress_salt.sh" file to the minion server. #}
/tmp/wordpress_salt.sh:
  file.managed:
    - source: salt://files/wordpress_salt.sh

{# Downloads the wordpress file and extracts it to the www directory, changing the directory name to wordpress 2024. #}
{# Enters remote mysql database information into the "wp-config.php" file. #}
download_wordpress:
  cmd.run:
    - name: "wget -P /tmp https://wordpress.org/latest.zip && 
    unzip /tmp/latest.zip -d /var/www &&
    mv /var/www/wordpress /var/www/wordpress2024 &&
    mv /var/www/wordpress2024/wp-config-sample.php /var/www/wordpress2024/wp-config.php &&
    bash /tmp/wordpress_salt.sh &&
    sed -i \"s/define( 'DB_NAME',.*);/define( 'DB_NAME', '{{ data['database_name'] }}' );/g\" /var/www/wordpress2024/wp-config.php &&
    sed -i \"s/define( 'DB_USER',.*);/define( 'DB_USER', '{{ data['dbuser_username'] }}' );/g\" /var/www/wordpress2024/wp-config.php &&
    sed -i \"s/define( 'DB_PASSWORD',.*);/define( 'DB_PASSWORD', '{{ data['dbuser_password'] }}' );/g\" /var/www/wordpress2024/wp-config.php &&
    sed -i \"s/define( 'DB_HOST',.*);/define( 'DB_HOST', '{{ ubuntu22ip['ubuntu22'][0] }}' );/g\" /var/www/wordpress2024/wp-config.php"
    - unless: "test -e /var/www/wordpress2024"

{# Copies the "nginx.conf" file to the minion. #}
/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx.conf
    - user: root
    - group: root
    - mode: 644

{# Creates a "self-signed SSL certificate". #}
create_ssl:
  cmd.run:
    - name: "mkdir /etc/nginx/ssl &&
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj '/C=TR/ST=Istanbul/L=Istanbul/O=Kartaca/OU=IT Department/CN=www.example.com'"
    - unless: test -e /etc/nginx/ssl

{# Copies the "wordpress2024.conf" file to the minion. #}
/etc/nginx/conf.d/wordpress2024.conf:
  file.managed:
    - source: salt://files/wordpress2024.conf
    - user: root
    - group: root
    - mode: 644

{# Observes the changes in the "nginx.conf" file and reloads the file if it detects a change. #}
nginx_reload:
  cmd.run:
    - name: systemctl reload nginx
    - watch:
      - file: /etc/nginx/nginx.conf

{# "logrotate" copies the configuration file to the minion. #}
/etc/logrotate.d/nginx:
  file.managed:
    - source: salt://files/logrotate_nginx.conf
    - user: root
    - group: root
    - mode: '0644'

{# Creates a cron task that will stop and restart the Nginx service on the first of each month. #}
{# "logrotate" adds the task to the cron task to run. #}
nginx_cron:
  cmd.run:
    - name: "echo \"0 0 1 * * systemctl restart nginx\" >> /tmp/nginxcron &&
    echo \"0 * * * * /usr/sbin/logrotate -f /etc/logrotate.d/nginx\" >> /tmp/nginxcron &&
    crontab /tmp/nginxcron &&
    rm -rf /tmp/nginxcron"

{# Allows editing of the "SELinux" configuration to allow connections. #}
selinuxconf_for_mysql:
  cmd.run:
    - name: "setsebool -P httpd_can_network_connect_db 1 &&
    setsebool -P httpd_can_network_connect 1"

{#########################################}
{#########################################}
{###          ubuntu22 tasks           ###}
{#########################################}
{#########################################}
{% elif grains['id'] == 'ubuntu22' %}

{# Installs the necessary packages. #}
install_mysql:
  pkg.installed:
    - pkgs:
      - mysql-server
      - default-libmysqlclient-dev
      - build-essential
      - pkg-config

{# Installs the necessary package for the salt mysql module. #}
mysql_dependence:
  cmd.run:
    - name: "salt-pip install PyMYSQL"

{# Activates mysql service. #}
mysql:
  service.running:
    - enable: True

{# Creates database. #}
{{ data['database_name'] }}:
  mysql_database.present

{# Creates database user for remote connections. #}
{{ data['dbuser_username'] }}:
  mysql_user.present:
    - host: {{ centos9ip['centos9'][0] }}
    - password: "{{ data['dbuser_password'] }}"
    - connection_charset: utf8

{# Creates database user for local connections. #}
{{ data['dblocal_username'] }}:
  mysql_user.present:
    - host: localhost
    - password: "{{ data['dblocal_password'] }}"
    - connection_charset: utf8


{# Defines the necessary permissions to the remote_user on the database. #}
grantdb:
  mysql_grants.present:
    - grant: all privileges
    - database: {{ data['database_name'] }}.*
    - user: "{{ data['dbuser_username'] }}"
    - host: {{ centos9ip['centos9'][0] }}

{# Defines the necessary permissions to the local_user on the database. #}
grant_local_db:
  mysql_grants.present:
    - grant: SELECT, LOCK TABLES
    - database: {{ data['database_name'] }}.*
    - user: "{{ data['dblocal_username'] }}"
    - host: localhost


{# Makes mysql open to remote connections. #}
open_mysql_remote_conn:
  cmd.run:
    - name: "sed -i \"s/^bind-address.*/#bind-address = 127.0.0.1/g\" /etc/mysql/mysql.conf.d/mysqld.cnf &&
    systemctl restart mysql"

{# Creates the directory where the Mysql database will be backed up. #}
create_backup_dir:
  file.directory:
    - name: /backup
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - unless: "test -e /backup"

{# It creates a cron task that takes a mysql backup every night at 2am. #}
create_cron:
  cmd.run:
    - name: echo "0 2 * * * mysqldump --no-tablespaces -u {{ data['dblocal_username'] }} -p"{{ data['dblocal_password'] }}" {{ data['database_name'] }} > /backup/kartaca_wordpressdb.sql" | crontab -

{% endif %}