#!/bin/env bash

set -e
ubuntu_version=$(lsb_release -a 2>/dev/null | grep -v "No LSB modules are available." | grep "Description:" | awk -F "Description:\t" '{print $2}')

install_mockgee() {
  # Friendly welcome
  echo "🧱 Welcome to the mockgee Setup Script"
  echo ""
  echo "🛸 Fasten your seatbelts! We're setting up your mockgee environment on your $ubuntu_version server."
  echo ""

  # Remove any old Docker installations, without stopping the script if they're not found
  echo "🧹 Time to sweep away any old Docker installations."
  sudo apt-get remove docker docker-engine docker.io containerd runc >/dev/null 2>&1 || true

  # Update package list
  echo "🔄 Updating your package list."
  sudo apt-get update >/dev/null 2>&1

  # Install dependencies
  echo "📦 Installing the necessary dependencies."
  sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release >/dev/null 2>&1

  # Set up Docker's official GPG key & stable repository
  echo "🔑 Adding Docker's official GPG key and setting up the stable repository."
  sudo mkdir -m 0755 -p /etc/apt/keyrings >/dev/null 2>&1
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg >/dev/null 2>&1
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null 2>&1

  # Update package list again
  echo "🔄 Updating your package list again."
  sudo apt-get update >/dev/null 2>&1

  # Install Docker
  echo "🐳 Installing Docker."
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1

  # Test Docker installation
  echo "🚀 Testing your Docker installation."
  if docker --version >/dev/null 2>&1; then
    echo "🎉 Docker is installed!"
  else
    echo "❌ Docker is not installed. Please install Docker before proceeding."
    exit 1
  fi

  # Adding your user to the Docker group
  echo "🐳 Adding your user to the Docker group to avoid using sudo with docker commands."
  sudo groupadd docker >/dev/null 2>&1 || true
  sudo usermod -aG docker $USER >/dev/null 2>&1

  echo "🎉 Hooray! Docker is all set and ready to go. You're now ready to run your mockgee instance!"

  mkdir -p mockgee && cd mockgee
  echo "📁 Created mockgee Quickstart directory at ./mockgee."

  # Ask the user for their email address
  echo "💡 Please enter your email address for the SSL certificate:"
  read email_address

  # Installing Traefik
  echo "🚗 Configuring Traefik..."

  cat <<EOT >traefik.yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: default
providers:
  docker:
    watch: true
    exposedByDefault: false
certificatesResolvers:
  default:
    acme:
      email: $email_address
      storage: acme.json
      caServer: "https://acme-v01.api.letsencrypt.org/directory"
      tlsChallenge: {}
EOT

  echo "💡 Created traefik.yaml file with your provided email address."

  touch acme.json
  chmod 600 acme.json
  echo "💡 Created acme.json file with correct permissions."

  # Ask the user for their domain name
  echo "🔗 Please enter your domain name for the SSL certificate (🚨 do NOT enter the protocol (http/https/etc)):"
  read domain_name


  echo "📥 Downloading docker-compose.yml from mockgee GitHub repository..."
  curl -o docker-compose.yml https://raw.githubusercontent.com/mockgeelabs/mockgee-install/main/docker-compose.yml

  awk -v domain_name="$domain_name" '
/mockgee:/,/^ *$/ {
    if ($0 ~ /depends_on:/) {
        inserting_labels=1
    }
    if (inserting_labels && ($0 ~ /ports:/)) {
        print "    labels:"
        print "      - \"traefik.enable=true\"  # Enable Traefik for this service"
        print "      - \"traefik.http.routers.mockgee.rule=Host(\`" domain_name "\`)\"  # Use your actual domain or IP"
        print "      - \"traefik.http.routers.mockgee.entrypoints=websecure\"  # Use the websecure entrypoint (port 443 with TLS)"
        print "      - \"traefik.http.services.mockgee.loadbalancer.server.port=8080\"  # Forward traffic to mockgee on port 8080"
        inserting_labels=0
    }
    print
    next
}
/^volumes:/ {
    print "  traefik:"
    print "    image: \"traefik:v2.7\""
    print "    restart: always"
    print "    container_name: \"traefik\""
    print "    depends_on:"
    print "      - mockgee"
    print "    ports:"
    print "      - \"80:80\""
    print "      - \"443:443\""
    print "    volumes:"
    print "      - ./traefik.yaml:/traefik.yaml"
    print "      - ./acme.json:/acme.json"
    print "      - /var/run/docker.sock:/var/run/docker.sock:ro"
    print ""
}
1
' docker-compose.yml >tmp.yml && mv tmp.yml docker-compose.yml

  newgrp docker <<END

docker compose up -d

echo "🔗 To edit more variables and deeper config, go to the mockgee/docker-compose.yml, edit the file, and restart the container!"

echo "🚨 Make sure you have set up the DNS records as well as inbound rules for the domain name and IP address of this instance."
echo ""
echo "🎉 All done! Check the status of mockgee & Traefik with 'cd mockgee && sudo docker compose ps.'"

END

}

uninstall_mockgee() {
  echo "🗑️ Preparing to Uninstalling mockgee..."
  read -p "Are you sure you want to uninstall mockgee? This will delete all the data associated with it! (yes/no): " uninstall_confirmation
  if [[ $uninstall_confirmation == "yes" ]]; then
    cd mockgee
    sudo docker compose down
    cd ..
    sudo rm -rf mockgee
    echo "🛑 mockgee uninstalled successfully!"
  else
    echo "❌ Uninstalling mockgee has been cancelled."
  fi
}

stop_mockgee() {
  echo "🛑 Stopping mockgee..."
  cd mockgee
  sudo docker compose down
  echo "🎉 mockgee instance stopped successfully!"
}

update_mockgee() {
  echo "🔄 Updating mockgee..."
  cd mockgee
  sudo docker compose pull
  sudo docker compose down
  sudo docker compose up -d
  echo "🎉 mockgee updated successfully!"
  echo "🎉 Check the status of mockgee & Traefik with 'cd mockgee && sudo docker compose logs.'"
}

restart_mockgee() {
  echo "🔄 Restarting mockgee..."
  cd mockgee
  sudo docker compose restart
  echo "🎉 mockgee restarted successfully!"
}

get_logs() {
  echo "📃 Getting mockgee logs..."
  cd mockgee
  sudo docker compose logs
}

case "$1" in
install)
  install_mockgee
  ;;
update)
  update_mockgee
  ;;
stop)
  stop_mockgee
  ;;
restart)
  restart_mockgee
  ;;
logs)
  get_logs
  ;;
uninstall)
  uninstall_mockgee
  ;;
*)
  echo "🚀 Executing default step of installing mockgee"
  install_mockgee
  ;;
esac
