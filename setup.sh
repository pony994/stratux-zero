#!/bin/bash -e

workdir="$(dirname $(realpath ${BASH_SOURCE[0]}))"

# update the base image
function update_base {
sudo apt-get install rpi-update
sudo apt-get update
sudo apt-get dist-upgrade
sudo apt-get upgrade
}

# install dependencies
function install_dep {
sudo apt-get install -y vim
sudo apt-get install -y iw
sudo apt-get install -y lshw
sudo apt-get install -y wget
sudo apt-get install -y gpsd
sudo apt-get install -y tcpdump
sudo apt-get install -y libusb-1.0-0-dev
sudo apt-get install -y build-essential
sudo apt-get install -y cmake
# install go 1.17 version and update .bashrc 
wget https://go.dev/dl/go1.17.13.linux-armv6l.tar.gz
sudo tar -C /usr/local -xzf go1.17.13.linux-armv6l.tar.gz

#!/bin/bash
# Check for the existence of GOPATH
if ! grep -q "export GOPATH=\$HOME/go" "$HOME/.bashrc"; then
  echo "export GOPATH=\$HOME/go" >> "$HOME/.bashrc"
  echo "Added GOPATH to .bashrc"
fi

# Check for the existence of the Go binary path
if ! grep -q "export PATH=\$PATH:/usr/local/go/bin" "$HOME/.bashrc"; then
  echo "export PATH=\$PATH:/usr/local/go/bin" >> "$HOME/.bashrc"
  echo "Added Go binary path to .bashrc"
fi
sudo apt-get install -y mercurial
sudo apt-get install -y autoconf
sudo apt-get install -y fftw3
sudo apt-get install -y fftw3-dev
sudo apt-get install -y libtool
sudo apt-get install -y automake
sudo apt-get install -y pkg-config
sudo apt-get install -y libjpeg-dev i2c-tools python3-smbus python3-pip python-dev python3-pil python3-daemon screen
sudo apt-get install -y libsdl-dev
sudo apt-get install -y git
# dump1090-fa deps
sudo apt-get install -y build-essential debhelper librtlsdr-dev pkg-config libncurses5-dev libbladerf-dev
# sudo apt-get install -y dh-systemd
# optional deps
sudo apt-get install -y hostapd dnsmasq nginx
git config --global http.sslVerify false
}

# download and compile github packages
function prepare_stratux {
sudo mkdir /opt/stratux
sudo chown pi.pi /opt/stratux

cd /opt/stratux
git clone --depth=1 --branch v1.6r1-eu029 https://github.com/cyoung/stratux.git stratux_src
cd stratux_src
git clone --depth=1 --branch stratux https://github.com/Determinant/dump1090-fa-stratux.git dump1090
git submodule update --init --recursive goflying
patch < "$workdir/stratux_Makefile.patch" Makefile
patch < "$workdir/stratux_network_go.patch" main/network.go
patch < "$workdir/dump1090.patch" dump1090/Makefile
patch < "$workdir/fancontrol.patch" main/fancontrol.go


# build librtlsdr
cd /opt/stratux
git clone https://github.com/jpoirier/librtlsdr
cd librtlsdr
mkdir build
cd build
cmake ../
make
sudo make install
sudo ldconfig

# build kalibrate-rtl
cd /opt/stratux
git clone https://github.com/steve-m/kalibrate-rtl
cd kalibrate-rtl
./bootstrap
./configure
make
sudo make install

# build wiringpi
sudo apt-get purge -y wiringpi
cd /opt/stratux
git clone https://github.com/WiringPi/WiringPi
cd WiringPi
./build debian
ls debian-template/*deb
}

function build_stratux {
export GOPATH=$HOME/go
export GOROOT=$(go env | grep GOROOT | sed 's/[^=]*="\(.*\)"$/\1/g')
export GO111MODULE="off"
export CGO_CFLAGS_ALLOW=-L/opt/stratux/stratux_src
export PATH=$PATH:/usr/local/go/bin

cd /opt/stratux/stratux_src
make
sudo rm -f /usr/bin/dump1090
sudo -E make install
}

# copy various configs to their proper locations
function deploy_config {
sudo cp -f /opt/stratux/stratux_src/image/motd /etc/motd
#sudo cp -f /opt/stratux/stratux_src/image/dhcpd-not_smart.conf /etc/dhcp/dhcpd.conf
sudo cp -f /opt/stratux/stratux_src/image/hostapd.conf /etc/hostapd/hostapd.conf
sudo cp -f /opt/stratux/stratux_src/image/hostapd-edimax.conf /etc/hostapd/hostapd-edimax.conf
sudo cp -f /opt/stratux/stratux_src/image/hostapd_manager.sh /usr/sbin/hostapd_manager.sh
sudo chmod 755 /usr/sbin/hostapd_manager.sh
sudo cp -f /opt/stratux/stratux_src/image/hostapd-edimax /usr/sbin/hostapd-edimax
sudo rm -f mnt/etc/rc*.d/hostapd mnt/etc/network/if-pre-up.d/hostapd mnt/etc/network/if-post-down.d/hostapd mnt/etc/init.d/hostapd mnt/etc/default/hostapd
sudo cp -f /opt/stratux/stratux_src/image/stratux-wifi.sh /usr/sbin/stratux-wifi.sh
sudo chmod 755 /usr/sbin/stratux-wifi.sh
sudo cp -f /opt/stratux/stratux_src/image/sdr-tool.sh /usr/sbin/sdr-tool.sh
sudo chmod 755 /usr/sbin/sdr-tool.sh
#sudo cp -f /opt/stratux/stratux_src/image/.rules /etc/udev/rules.d/
sudo rm -rf /usr/bin/fancontrol.py
sudo cp -f /opt/stratux/stratux_src/image/stxAliases.txt /root/.stxAliases
sudo cp -f /opt/stratux/stratux_src/image/logrotate_d_stratux /etc/logrotate.d/stratux

cp -f /opt/stratux/stratux_src/image/stxAliases.txt /home/pi/.stxAliases
cat > /home/pi/.bash_profile <<EOF
# source the user's bashrc if it exists
if [ -f "${HOME}/.bashrc" ] ; then
	  source "${HOME}/.bashrc"
fi
source "$HOME/.stxAliases"
EOF

sudo cp -f /opt/stratux/stratux_src/image/rtl-sdr-blacklist.conf /etc/modprobe.d
sudo cp -f /opt/stratux/stratux_src/test/screen/screen.py /usr/bin/stratux-screen.py
sudo mkdir -p /etc/stratux-screen/
sudo cp -f /opt/stratux/stratux_src/test/screen/stratux-logo-64x64.bmp /etc/stratux-screen/stratux-logo-64x64.bmp
sudo cp -f /opt/stratux/stratux_src/test/screen/CnC_Red_Alert.ttf /etc/stratux-screen/CnC_Red_Alert.ttf
sudo cp -f /opt/stratux/stratux_src/__lib__systemd__system__stratux.service /lib/systemd/system/stratux.service
sudo cp -f /opt/stratux/stratux_src/__root__stratux-pre-start.sh /home/pi/stratux-pre-start.sh
sudo ln -sf /home/pi/stratux-pre-start.sh /root/stratux-pre-start.sh
sudo cp -f /opt/stratux/stratux_src/image/rc.local /etc/rc.local

sudo cp -f "$workdir/hostapd.conf" /etc/hostapd/hostapd.conf
sudo cp -f "$workdir/dnsmasq.conf" /etc/dnsmasq.conf
sudo cp -f "$workdir/nginx_default" /etc/nginx/sites-available/default
sudo rm -f /etc/network/if-up.d/wpasupplicant
sudo rm -f /etc/network/if-pre-up.d/wpasupplicant
sudo rm -f /etc/network/if-down.d/wpasupplicant
sudo rm -f /etc/network/if-post-down.d/wpasupplicant
mkdir -p /opt/stratux/stratux_src/dump1090/public_html/data/
sudo touch /var/lib/dhcp/dhcpd.leases
sudo touch /etc/hostapd/hostapd.user
}

update_base
install_dep
prepare_stratux
build_stratux
deploy_config

sudo "$workdir/disable-fa-web.sh"
sudo "$workdir/reboot-as-ap.sh"
