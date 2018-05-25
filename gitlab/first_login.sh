#!/bin/bash
## PART: reconfigure upon root login
##
## vi: syntax=sh expandtab ts=4
#

publicip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
cat <<EOC
---------------------------------------------------------------------------------------------

GitLab is not configured. If you would like customize it yourself,
press 'n' now.

EOC

read -p "Okay to Configure GitLab (Y|n): " yesno

if [[ ! "${yesno^}" =~ "N" ]]; then


    mkdir -p /var/log/gitlab/reconfigure
    cp /etc/gitlab/gitlab.rb.cloud /etc/gitlab/gitlab.rb

    read -p "External URL (defaults to http://${publicip}): " external_url
    echo "external_url \"${external_url:-http://${publicip}}\"" >> /etc/gitlab/gitlab.rb

    checked=0
    until [[ "$checked" =~ "1" ]];
    do
        echo -n "Enter the GitLab 'root'user password : "
        read password
        LEN=$(echo ${#password})

        if [ $LEN -lt 8 ]; then
            echo "$password is smaller than 8 characters"
            checked=0
        else
            if [ $(echo $password | tr -d "[:alnum:]" | wc -w ) -eq 0 ]; then
                echo "$password is a weak password"
                checked=0
            else
                echo "$password is OK"
                checked=1
            fi
        fi
    done

    # Remove the stuff that we don't need
    rm -rf /etc/gitlab/gitlab-secrets.json \
           /var/lib/www

    echo "Running 'gitlab-ctl reconfigure', this will take a minute..."
    systemctl start gitlab-runsvdir.service
    systemctl enable gitlab-runsvdir.service
    (gitlab-ctl reconfigure 2>&1) >  /var/log/gitlab_reconfigure.log

    echo "  wrote log to /var/log/gitlab_reconfigure.log"

    # Set a randomized password.
    echo "Setting the password..."
    (gitlab-rake \
         gitlab:setup \
            RAILS_ENV=production \
            GITLAB_ROOT_PASSWORD=${password} \
            force=yes 2>&1 ) > /var/log/gitlab_set_pass.log
    echo "  wrote log to /var/log/gitlab_set_pass.log"

    # Remove the landing page...
    echo "Removing the landing page..."
    ( apt-get -qqy purge lighttpd >> /dev/null
      apt-get -qqy autoremove --purge >> /dev/null )
    cat <<EOC
---------------------------------------------------------------------------------------------

You can access GitLab via:
    Web URL:  http://${publicip}
    User:     root
    Password: ${password}

Happy Coding!
---------------------------------------------------------------------------------------------

EOC

    cp /etc/skel/.bashrc /root

else

   cat <<EOC
---------------------------------------------------------------------------------------------

To remove this message, run:
   cp /etc/skel/.bashrc /root

Please note that lighttpd is running to serve up the public splash page.
You may remove it via:
   apt-get -qqy purge lighttpd
   rm -rf /var/wwww

If you would like to let this script do the work for you, edit/change
/etc/gitlab/gitlab.rb.digitalocean and then run:
   bash $(readlink -f ${0})

Happy Coding!
---------------------------------------------------------------------------------------------

EOC

fi


