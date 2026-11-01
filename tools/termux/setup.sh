#!/data/data/com.termux/files/usr/bin/bash
# تجهيز الجوال (مرة وحدة، وكل ما تبي تحدّث اللعبة). والجوال على نفس واي فاي اللابتوب:
#   curl -s http://192.168.0.100:8092/setup.sh | bash
set -e
SRC=${SRC:-http://192.168.0.100:8092}
echo "تنزيل البرامج (node و cloudflared)..."
pkg update -y >/dev/null 2>&1 || true
pkg install -y nodejs-lts cloudflared >/dev/null
echo "تنزيل اللعبة من اللابتوب..."
mkdir -p ~/batta
curl -sf "$SRC/batta-phone.tar.gz" -o ~/batta-phone.tar.gz
rm -rf ~/batta/src ~/batta/public ~/batta/node_modules
tar -xzf ~/batta-phone.tar.gz -C ~/batta
rm ~/batta-phone.tar.gz
chmod +x ~/batta/batta.sh
echo
echo "جاهز. للتشغيل:  ~/batta/batta.sh"
