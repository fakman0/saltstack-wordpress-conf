sed -i "s/define( 'AUTH_KEY',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'SECURE_AUTH_KEY',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'LOGGED_IN_KEY',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'NONCE_KEY',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'AUTH_SALT',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'SECURE_AUTH_SALT',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'LOGGED_IN_SALT',.*);/ /g" /var/www/wordpress2024/wp-config.php
sed -i "s/define( 'NONCE_SALT',.*);/ /g" /var/www/wordpress2024/wp-config.php

echo "" >> /var/www/wordpress2024/wp-config.php
echo "/** Authentication unique keys and salts.*/" >> /var/www/wordpress2024/wp-config.php
curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/wordpress2024/wp-config.php