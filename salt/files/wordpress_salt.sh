#!/bin/sh

# wordpress automatically pulls the salts and places them in the "wp-config.php" file.
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s /var/www/wordpress2024/wp-config.php

# It allows installation operations by WordPress servers.
echo "define( 'FS_METHOD', 'direct' );" >> /var/www/wordpress2024/wp-config.php

# The directory needs full permissions to add a new plugin
chmod -R 777 /var/www/wordpress2024/wp-content/plugins