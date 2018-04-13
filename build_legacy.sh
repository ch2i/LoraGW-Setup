#! /bin/bash

INSTALL_DIR="/opt/loragw"

mkdir -p $INSTALL_DIR/dev
mkdir -p $INSTALL_DIR/dev/legacy
cd $INSTALL_DIR/dev/legacy

# Build legacy loragw library
if [ ! -d lora_gateway ]; then
    git clone https://github.com/TheThingsNetwork/lora_gateway.git || { echo 'Cloning lora_gateway failed.' ; exit 1; }
    pushd lora_gateway
else
    pushd lora_gateway
    git reset --hard
    git pull
fi
sed -i -e 's/PLATFORM= .*$/PLATFORM= imst_rpi/g' ./libloragw/library.cfg
sed -i -e 's/CFG_SPI= .*$/CFG_SPI= native/g' ./libloragw/library.cfg
make

popd
# Build legacy packet forwarder
if [ ! -d packet_forwarder ]; then
    git clone https://github.com/ch2i/packet_forwarder
    pushd packet_forwarder
else
    pushd packet_forwarder
    git pull
    git reset --hard
fi
make
popd


# Copy things needed at runtime to where they'll be expected
cp $INSTALL_DIR/dev/legacy/packet_forwarder/poly_pkt_fwd/poly_pkt_fwd $INSTALL_DIR/poly_pkt_fwd

if [ ! -f $INSTALL_DIR/poly_pkt_fwd ]; then
    echo "Oup's, something went wrong, forwarder not found"
    echo "please check for any build error"
else
    echo "Build & Installation Completed."
    echo "forwarder is located at $INSTALL_DIR/poly_pkt_fwd"
    echo ""
    echo "you can now run the setup script with sudo ./setup.sh"
fi
