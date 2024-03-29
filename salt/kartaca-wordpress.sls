{% set data = pillar.get('kartaca-pillar', {}) %}

{% set ubuntu22ip = salt['mine.get']('ubuntu22', 'network.ip_addrs') %}
{% set centos9ip = salt['mine.get']('centos9', 'network.ip_addrs') %}

kartaca_group:
  group.present:
    - gid: 2024

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

/etc/sudoers.d/kartaca_roles:
  file.managed:
    - name: /etc/sudoers.d/kartaca_roles
  {% if grains['id'] == 'centos9' %}
    - contents: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/yum"
  {% elif grains['id'] == 'ubuntu22' %}
    - contents: "kartaca ALL=(ALL) NOPASSWD: /usr/bin/apt"
  {% endif %}

set_timezone:
  cmd.run:
    - name: timedatectl set-timezone Europe/Istanbul
    - user: root
    - timeout: 60

enable_ip_forwarding:
  sysctl.present:
    - name: net.ipv4.ip_forward
    - value: 1
    - config: /etc/sysctl.conf

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

hashicorp_repo:
  cmd.run:
    {% if grains['id'] == 'centos9' %}
    - name: "wget -O- https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo | sudo tee /etc/yum.repos.d/hashicorp.repo &&
    yum install terraform-1.6.4 -y"
    {% elif grains['id'] == 'ubuntu22' %}
    - name: "rm -rf /usr/share/keyrings/hashicorp-archive-keyring.gpg &&
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg &&
    gpg --no-default-keyring --keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg --fingerprint &&
    echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list &&
    sudo apt update &&
    apt install terraform=1.6.4-1 -y"
{% endif %}

update_hosts_file:
  file.append:
    - name: /etc/hosts
    - text: |
        {% for i in range(1, 16) %}
        192.168.168.{{ (i-1) | int + 129 }} kartaca.local
        {% endfor %}
    - unless: salt '*' file.grep text="192.168.168.129 kartaca.local"

{% if grains['id'] == 'centos9' %}
install_php_nginx:
  pkg.installed:
    - pkgs:
      - yum-utils
      - zip
      - nginx
      - php
      - php-fpm
      - php-mysqlnd
      - php-mbstring
      - php-intl
      - php-xml

nginx:
  service.running:
    - enable: True

php-fpm:
  service.running:
    - enable: True

/tmp/wordpress_salt.sh:
  file.managed:
    - source: salt://files/wordpress_salt.sh

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

/etc/nginx/nginx.conf:
  file.managed:
    - source: salt://nginx.conf
    - user: root
    - group: root
    - mode: 644

/etc/nginx/conf.d/wordpress2024.conf:
  file.managed:
    - source: salt://files/wordpress2024.conf
    - user: root
    - group: root
    - mode: 644

nginx_reload:
  cmd.run:
    - name: systemctl reload nginx
    - watch:
      - file: /etc/nginx/nginx.conf

/etc/logrotate.d/nginx:
  file.managed:
    - source: salt://files/logrotate_nginx.conf
    - user: root
    - group: root
    - mode: '0644'

nginx_cron:
  cmd.run:
    - name: "echo \"0 0 1 * * systemctl restart nginx\" >> /tmp/nginxcron &&
    echo \"0 * * * * /usr/sbin/logrotate -f /etc/logrotate.d/nginx\" >> /tmp/nginxcron &&
    crontab /tmp/nginxcron &&
    rm -rf /tmp/nginxcron"

selinuxconf_for_mysql:
  cmd.run:
    - name: "setsebool -P httpd_can_network_connect_db 1"

{% elif grains['id'] == 'ubuntu22' %}

install_mysql:
  pkg.installed:
    - pkgs:
      - mysql-server
      - python3-pip
      - python3-dev
      - default-libmysqlclient-dev
      - build-essential
      - pkg-config

mysql_dependence:
  cmd.run:
    - name: "salt-pip install PyMYSQL"

mysql:
  service.running:
    - enable: True

{{ data['database_name'] }}:
  mysql_database.present

{{ data['dbuser_username'] }}:
  mysql_user.present:
    - host: {{ centos9ip['centos9'][0] }}
    - password: "{{ data['dbuser_password'] }}"
    - connection_charset: utf8

grantdb:
  mysql_grants.present:
    - grant: CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT, REFERENCES, INDEX
    - database: {{ data['database_name'] }}.*
    - user: "{{ data['dbuser_username'] }}"
    - host: {{ centos9ip['centos9'][0] }}

create_backup_dir:
  file.directory:
    - name: /backup
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

create_cron:
  cmd.run:
    - name: echo "0 2 * * * mysqldump --no-tablespaces -u {{ data['dbuser_username'] }} -p"{{ data['dbuser_password'] }}" {{ data['database_name'] }} > /backup/kartaca_wordpressdb.sql" | crontab -

{% endif %}