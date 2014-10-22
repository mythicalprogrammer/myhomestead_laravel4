class Homestead
  def Homestead.configure(config, settings)
    # Configure The Box
    config.vm.box = "laravel/homestead"
    config.vm.hostname = "homestead"

    # Configure A Private Network IP
    config.vm.network :private_network, ip: settings["ip"] ||= "192.168.10.10"

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
      vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "1"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    # Configure Port Forwarding To The Box
    config.vm.network "forwarded_port", guest: 80, host: 8000
    config.vm.network "forwarded_port", guest: 3306, host: 33060
    config.vm.network "forwarded_port", guest: 5432, host: 54320

    # Configure The Public Key For SSH Access
    config.vm.provision "shell" do |s|
      s.inline = "echo $1 | tee -a /home/vagrant/.ssh/authorized_keys"
      s.args = [File.read(File.expand_path(settings["authorize"]))]
    end

    # Copy The SSH Private Keys To The Box
    settings["keys"].each do |key|
      config.vm.provision "shell" do |s|
        s.privileged = false
        s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
        s.args = [File.read(File.expand_path(key)), key.split('/').last]
      end
    end

    # Copy The Bash Aliases
    config.vm.provision "shell" do |s|
      s.inline = "cp /vagrant/aliases /home/vagrant/.bash_aliases"
    end

    # Register All Of The Configured Shared Folders
    settings["folders"].each do |folder|
      config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil
    end

    # Install All The Configured Nginx Sites
    settings["sites"].each do |site|
      config.vm.provision "shell" do |s|
          if (site.has_key?("hhvm") && site["hhvm"])
            s.inline = "bash /vagrant/scripts/serve-hhvm.sh $1 $2"
            s.args = [site["map"], site["to"]]
          else
            s.inline = "bash /vagrant/scripts/serve.sh $1 $2"
            s.args = [site["map"], site["to"]]
          end
      end
    end

    # Configure All Of The Server Environment Variables
    if settings.has_key?("variables")
      settings["variables"].each do |var|
        config.vm.provision "shell" do |s|
            s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php5/fpm/php-fpm.conf && service php5-fpm restart"
            s.args = [var["key"], var["value"]]
        end
      end
    end

    config.vm.provision :shell, inline: "wget https://github.com/priomsrb/vimswitch/raw/master/release/vimswitch && chmod +x vimswitch", privileged: false
    config.vm.provision :shell, inline: "./vimswitch mythicalprogrammer/vimrc", privileged: false

    project_name = settings["sites"][0]["name"]
    config.vm.provision :shell, inline: 'composer global require "laravel/installer=~1.1"', privileged: false
    config.vm.provision :shell, inline: "cd /home/vagrant/site; laravel new "+project_name, privileged: false

    folder_to = settings["folders"][0]["to"]+'/'+project_name
    config.vm.provision :shell, inline: "cd "+folder_to+"; wget https://raw.githubusercontent.com/mythicalprogrammer/npm_packagejson/master/package.json", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; sudo npm install -g grunt-cli"
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt-contrib-concat --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt-contrib-less --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt-contrib-uglify --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt-contrib-watch --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt-phpunit --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; npm install grunt-contrib-copy --save-dev", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; wget https://raw.githubusercontent.com/mythicalprogrammer/gruntfile_laravel4/master/Gruntfile.js", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+'; touch bower.json; echo "{\"name\": \"'+project_name+'\"}" > bower.json', privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; bower install bootstrap -S", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; bower install modernizr -S", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"/app; mkdir assets assets/javascript assets/stylesheets; touch assets/javascript/frontend.js assets/stylesheets/base.less assets/stylesheets/fonts.less assets/stylesheets/frontend.less;echo \"@import 'base.less';\" > assets/stylesheets/frontend.less", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"/app/assets/stylesheets; cp ../../../bower_components/bootstrap/less/variables.less .", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"/app; echo \"@import 'variables.less'; \n@import '../../../bower_components/bootstrap/less/bootstrap.less';\" > assets/stylesheets/frontend.less", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"/public; wget https://raw.githubusercontent.com/mythicalprogrammer/myhtml5bp/master/index.html", privileged: false
    config.vm.provision :shell, inline: "cd "+folder_to+"; grunt init", privileged: false
  end
end
