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

  echo "📥 Downloading docker-compose.yml from mockgee GitHub repository..."
  curl -o docker-compose.yml https://raw.githubusercontent.com/mockgeelabs/mockgee-install/main/docker-compose.yml

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
